import Foundation

struct MarkdownSync {
    let baseURL: URL

    init(baseURL: URL? = nil) {
        self.baseURL = baseURL ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/Whisper Notes", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.baseURL, withIntermediateDirectories: true)
    }

    // MARK: - Write

    func write(
        _ transcription: Transcription,
        folderName: String?,
        previousTitle: String? = nil,
        previousFolderName: String? = nil
    ) {
        // Delete old file if title or folder changed
        let titleChanged = previousTitle != nil && previousTitle != transcription.title
        let folderChanged = previousFolderName != folderName
        if titleChanged || folderChanged {
            let oldDir = resolveDir(previousFolderName ?? folderName)
            let oldFilename = sanitize(previousTitle ?? transcription.title) + ".md"
            let oldURL = oldDir.appendingPathComponent(oldFilename)
            try? FileManager.default.removeItem(at: oldURL)
        }

        let dir = resolveDir(folderName)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let filename = sanitize(transcription.title) + ".md"
        let fileURL = dir.appendingPathComponent(filename)

        var lines = ["---"]
        lines.append("id: \(transcription.id.uuidString)")
        lines.append("date: \(Self.iso.string(from: transcription.createdAt))")
        if !transcription.tags.isEmpty {
            let quoted = transcription.tags.map { "\"\($0.name)\"" }
            lines.append("tags: [\(quoted.joined(separator: ", "))]")
        }
        if transcription.isFavorite { lines.append("favorite: true") }
        if transcription.duration > 0 {
            lines.append("duration: \(Int(transcription.duration))")
        }
        lines.append("---")
        lines.append("")
        lines.append("# \(transcription.title)")
        lines.append("")
        lines.append(transcription.content)
        lines.append("")

        let text = lines.joined(separator: "\n")
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("MarkdownSync: failed to write \(fileURL.lastPathComponent): \(error)")
        }
    }

    // MARK: - Delete

    func delete(_ transcription: Transcription, folderName: String?) {
        let dir = resolveDir(folderName)
        let filename = sanitize(transcription.title) + ".md"
        let fileURL = dir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Folder operations

    func createFolderDir(_ name: String) {
        let dir = baseURL.appendingPathComponent(sanitize(name), isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func renameFolderDir(from oldName: String, to newName: String) {
        let oldDir = baseURL.appendingPathComponent(sanitize(oldName), isDirectory: true)
        let newDir = baseURL.appendingPathComponent(sanitize(newName), isDirectory: true)
        try? FileManager.default.moveItem(at: oldDir, to: newDir)
    }

    func deleteFolderDir(_ name: String) {
        let dir = baseURL.appendingPathComponent(sanitize(name), isDirectory: true)
        if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "md" {
                let dest = baseURL.appendingPathComponent(file.lastPathComponent)
                try? FileManager.default.moveItem(at: file, to: dest)
            }
        }
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Helpers

    private func resolveDir(_ folderName: String?) -> URL {
        if let folderName, !folderName.isEmpty {
            return baseURL.appendingPathComponent(sanitize(folderName), isDirectory: true)
        }
        return baseURL
    }

    private func sanitize(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\")
        let cleaned = name.unicodeScalars.filter { !invalid.contains($0) }
            .map { Character($0) }
        let result = String(cleaned).trimmingCharacters(in: .whitespaces)
        return result.isEmpty ? "untitled" : String(result.prefix(200))
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
