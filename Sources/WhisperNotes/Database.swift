import Foundation
import SQLite3

public final class Database {
    private var db: OpaquePointer?
    let path: String

    init() {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError(
                "Application Support directory unavailable. "
                    + "FileManager.urls(for:in:) returned empty for .applicationSupportDirectory."
            )
        }
        let dir = support.appendingPathComponent("WhisperNotes", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        path = dir.appendingPathComponent("whisper-notes.db").path
        openAndConfigure()
    }

    init(path: String) {
        self.path = path
        openAndConfigure()
    }

    /// Returns true if the Application Support directory is accessible and writable.
    public static func preflightCheck() -> Bool {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return false
        }
        let dir = support.appendingPathComponent("WhisperNotes", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            return false
        }
        return FileManager.default.isWritableFile(atPath: dir.path)
    }

    private func openAndConfigure() {
        let rc = sqlite3_open(path, &db)
        guard rc == SQLITE_OK else {
            let errorMsg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            fatalError(
                "Cannot open database at \(path). "
                    + "SQLite error \(rc): \(errorMsg)"
            )
        }
        sqlite3_exec(db, "PRAGMA journal_mode=WAL", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA foreign_keys=ON", nil, nil, nil)
        createTables()
    }

    deinit { sqlite3_close(db) }

    // MARK: - Schema

    private func createTables() {
        let sql = """
        CREATE TABLE IF NOT EXISTS folders (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            sort_order INTEGER DEFAULT 0,
            created_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS tags (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            color TEXT NOT NULL DEFAULT '#0A84FF'
        );
        CREATE TABLE IF NOT EXISTS transcriptions (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            content TEXT NOT NULL DEFAULT '',
            folder_id TEXT REFERENCES folders(id) ON DELETE SET NULL,
            is_favorite INTEGER DEFAULT 0,
            duration REAL DEFAULT 0,
            audio_filename TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS transcription_tags (
            transcription_id TEXT REFERENCES transcriptions(id) ON DELETE CASCADE,
            tag_id TEXT REFERENCES tags(id) ON DELETE CASCADE,
            PRIMARY KEY (transcription_id, tag_id)
        );
        CREATE INDEX IF NOT EXISTS idx_transcriptions_folder ON transcriptions(folder_id);
        CREATE INDEX IF NOT EXISTS idx_transcriptions_favorite ON transcriptions(is_favorite);
        CREATE INDEX IF NOT EXISTS idx_transcriptions_created ON transcriptions(created_at);
        """
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    // MARK: - Helpers

    private func prepare(_ sql: String) -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let err = String(cString: sqlite3_errmsg(db))
            print("SQL prepare error: \(err)\nSQL: \(sql)")
            return nil
        }
        return stmt
    }

    private func bind(_ stmt: OpaquePointer?, index: Int32, value: String?) {
        if let v = value {
            sqlite3_bind_text(stmt, index, (v as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private func bindDouble(_ stmt: OpaquePointer?, index: Int32, value: Double) {
        sqlite3_bind_double(stmt, index, value)
    }

    private func bindInt(_ stmt: OpaquePointer?, index: Int32, value: Int) {
        sqlite3_bind_int(stmt, index, Int32(value))
    }

    private func column(_ stmt: OpaquePointer?, index: Int32) -> String? {
        guard let cStr = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: cStr)
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func dateStr(_ date: Date) -> String {
        Self.iso.string(from: date)
    }

    private func parseDate(_ s: String?) -> Date {
        s.flatMap { Self.iso.date(from: $0) } ?? Date()
    }

    // MARK: - Folders

    func fetchFolders() -> [Folder] {
        let sql = """
        SELECT f.id, f.name, f.sort_order, f.created_at,
               (SELECT COUNT(*) FROM transcriptions WHERE folder_id = f.id)
        FROM folders f ORDER BY f.sort_order, f.name
        """
        guard let stmt = prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }
        var result: [Folder] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            result.append(Folder(
                id: UUID(uuidString: column(stmt, index: 0) ?? "") ?? UUID(),
                name: column(stmt, index: 1) ?? "",
                sortOrder: Int(sqlite3_column_int(stmt, 2)),
                createdAt: parseDate(column(stmt, index: 3)),
                transcriptionCount: Int(sqlite3_column_int(stmt, 4))
            ))
        }
        return result
    }

    func insertFolder(_ folder: Folder) {
        let sql = "INSERT INTO folders (id, name, sort_order, created_at) VALUES (?, ?, ?, ?)"
        guard let stmt = prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, index: 1, value: folder.id.uuidString)
        bind(stmt, index: 2, value: folder.name)
        bindInt(stmt, index: 3, value: folder.sortOrder)
        bind(stmt, index: 4, value: dateStr(folder.createdAt))
        sqlite3_step(stmt)
    }

    func updateFolder(_ folder: Folder) {
        let sql = "UPDATE folders SET name = ?, sort_order = ? WHERE id = ?"
        guard let stmt = prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, index: 1, value: folder.name)
        bindInt(stmt, index: 2, value: folder.sortOrder)
        bind(stmt, index: 3, value: folder.id.uuidString)
        sqlite3_step(stmt)
    }

    func deleteFolder(_ id: UUID) {
        let sql = "DELETE FROM folders WHERE id = ?"
        guard let stmt = prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, index: 1, value: id.uuidString)
        sqlite3_step(stmt)
    }

    // MARK: - Tags

    func fetchTags() -> [Tag] {
        let sql = "SELECT id, name, color FROM tags ORDER BY name"
        guard let stmt = prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }
        var result: [Tag] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            result.append(Tag(
                id: UUID(uuidString: column(stmt, index: 0) ?? "") ?? UUID(),
                name: column(stmt, index: 1) ?? "",
                color: column(stmt, index: 2) ?? "#0A84FF"
            ))
        }
        return result
    }

    func insertTag(_ tag: Tag) {
        let sql = "INSERT OR IGNORE INTO tags (id, name, color) VALUES (?, ?, ?)"
        guard let stmt = prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, index: 1, value: tag.id.uuidString)
        bind(stmt, index: 2, value: tag.name)
        bind(stmt, index: 3, value: tag.color)
        sqlite3_step(stmt)
    }

    func updateTag(_ tag: Tag) {
        let sql = "UPDATE tags SET name = ?, color = ? WHERE id = ?"
        guard let stmt = prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, index: 1, value: tag.name)
        bind(stmt, index: 2, value: tag.color)
        bind(stmt, index: 3, value: tag.id.uuidString)
        sqlite3_step(stmt)
    }

    func deleteTag(_ id: UUID) {
        let sql = "DELETE FROM tags WHERE id = ?"
        guard let stmt = prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, index: 1, value: id.uuidString)
        sqlite3_step(stmt)
    }

    // MARK: - Transcriptions

    /// Batch-fetch all transcription→tag mappings in a single query (fixes N+1)
    private func fetchAllTranscriptionTags() -> [UUID: [Tag]] {
        let sql = """
        SELECT tt.transcription_id, t.id, t.name, t.color FROM tags t
        JOIN transcription_tags tt ON t.id = tt.tag_id
        ORDER BY t.name
        """
        guard let stmt = prepare(sql) else { return [:] }
        defer { sqlite3_finalize(stmt) }
        var result: [UUID: [Tag]] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let tid = UUID(uuidString: column(stmt, index: 0) ?? "") ?? UUID()
            let tag = Tag(
                id: UUID(uuidString: column(stmt, index: 1) ?? "") ?? UUID(),
                name: column(stmt, index: 2) ?? "",
                color: column(stmt, index: 3) ?? "#0A84FF"
            )
            result[tid, default: []].append(tag)
        }
        return result
    }

    func fetchTranscriptions() -> [Transcription] {
        let tagMap = fetchAllTranscriptionTags()

        let sql = """
        SELECT id, title, content, folder_id, is_favorite, duration, audio_filename, created_at, updated_at
        FROM transcriptions ORDER BY created_at DESC
        """
        guard let stmt = prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }
        var result: [Transcription] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let tid = UUID(uuidString: column(stmt, index: 0) ?? "") ?? UUID()
            result.append(Transcription(
                id: tid,
                title: column(stmt, index: 1) ?? "",
                content: column(stmt, index: 2) ?? "",
                folderId: column(stmt, index: 3).flatMap { UUID(uuidString: $0) },
                isFavorite: sqlite3_column_int(stmt, 4) != 0,
                duration: sqlite3_column_double(stmt, 5),
                audioFilename: column(stmt, index: 6),
                createdAt: parseDate(column(stmt, index: 7)),
                updatedAt: parseDate(column(stmt, index: 8)),
                tags: tagMap[tid] ?? []
            ))
        }
        return result
    }

    func insertTranscription(_ t: Transcription) {
        let sql = """
        INSERT INTO transcriptions (id, title, content, folder_id, is_favorite, duration, audio_filename, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        guard let stmt = prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, index: 1, value: t.id.uuidString)
        bind(stmt, index: 2, value: t.title)
        bind(stmt, index: 3, value: t.content)
        bind(stmt, index: 4, value: t.folderId?.uuidString)
        bindInt(stmt, index: 5, value: t.isFavorite ? 1 : 0)
        bindDouble(stmt, index: 6, value: t.duration)
        bind(stmt, index: 7, value: t.audioFilename)
        bind(stmt, index: 8, value: dateStr(t.createdAt))
        bind(stmt, index: 9, value: dateStr(t.updatedAt))
        sqlite3_step(stmt)
        syncTags(transcriptionId: t.id, tags: t.tags)
    }

    func updateTranscription(_ t: Transcription) {
        let sql = """
        UPDATE transcriptions SET title=?, content=?, folder_id=?, is_favorite=?, duration=?, audio_filename=?, updated_at=?
        WHERE id=?
        """
        guard let stmt = prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, index: 1, value: t.title)
        bind(stmt, index: 2, value: t.content)
        bind(stmt, index: 3, value: t.folderId?.uuidString)
        bindInt(stmt, index: 4, value: t.isFavorite ? 1 : 0)
        bindDouble(stmt, index: 5, value: t.duration)
        bind(stmt, index: 6, value: t.audioFilename)
        bind(stmt, index: 7, value: dateStr(t.updatedAt))
        bind(stmt, index: 8, value: t.id.uuidString)
        sqlite3_step(stmt)
        syncTags(transcriptionId: t.id, tags: t.tags)
    }

    func deleteTranscription(_ id: UUID) {
        let sql = "DELETE FROM transcriptions WHERE id = ?"
        guard let stmt = prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, index: 1, value: id.uuidString)
        sqlite3_step(stmt)
    }

    private func syncTags(transcriptionId: UUID, tags: [Tag]) {
        sqlite3_exec(db, "BEGIN", nil, nil, nil)

        let del = "DELETE FROM transcription_tags WHERE transcription_id = ?"
        if let stmt = prepare(del) {
            bind(stmt, index: 1, value: transcriptionId.uuidString)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
        for tag in tags {
            let ins = "INSERT OR IGNORE INTO transcription_tags (transcription_id, tag_id) VALUES (?, ?)"
            if let stmt = prepare(ins) {
                bind(stmt, index: 1, value: transcriptionId.uuidString)
                bind(stmt, index: 2, value: tag.id.uuidString)
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
        }

        sqlite3_exec(db, "COMMIT", nil, nil, nil)
    }
}
