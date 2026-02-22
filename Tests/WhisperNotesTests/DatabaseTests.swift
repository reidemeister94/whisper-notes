import XCTest
@testable import WhisperNotesLib

final class DatabaseTests: XCTestCase {
    var db: Database!
    var dbPath: String!

    override func setUp() {
        super.setUp()
        dbPath = NSTemporaryDirectory() + "test-\(UUID().uuidString).db"
        db = Database(path: dbPath)
    }

    override func tearDown() {
        db = nil
        try? FileManager.default.removeItem(atPath: dbPath)
        super.tearDown()
    }

    // MARK: - Empty database

    func testEmptyDatabaseReturnsEmptyArrays() {
        XCTAssertTrue(db.fetchFolders().isEmpty)
        XCTAssertTrue(db.fetchTags().isEmpty)
        XCTAssertTrue(db.fetchTranscriptions().isEmpty)
    }

    // MARK: - Folder CRUD

    func testInsertAndFetchFolder() {
        let folder = Folder(id: UUID(), name: "Test Folder", sortOrder: 0, createdAt: Date())
        db.insertFolder(folder)
        let fetched = db.fetchFolders()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].id, folder.id)
        XCTAssertEqual(fetched[0].name, "Test Folder")
        XCTAssertEqual(fetched[0].sortOrder, 0)
    }

    func testFetchFoldersSortedByOrder() {
        let f1 = Folder(id: UUID(), name: "B Folder", sortOrder: 1, createdAt: Date())
        let f2 = Folder(id: UUID(), name: "A Folder", sortOrder: 0, createdAt: Date())
        db.insertFolder(f1)
        db.insertFolder(f2)
        let fetched = db.fetchFolders()
        XCTAssertEqual(fetched[0].name, "A Folder")
        XCTAssertEqual(fetched[1].name, "B Folder")
    }

    func testUpdateFolder() {
        var folder = Folder(id: UUID(), name: "Original", sortOrder: 0, createdAt: Date())
        db.insertFolder(folder)
        folder.name = "Updated"
        db.updateFolder(folder)
        let fetched = db.fetchFolders()
        XCTAssertEqual(fetched[0].name, "Updated")
    }

    func testDeleteFolder() {
        let folder = Folder(id: UUID(), name: "ToDelete", sortOrder: 0, createdAt: Date())
        db.insertFolder(folder)
        db.deleteFolder(folder.id)
        XCTAssertTrue(db.fetchFolders().isEmpty)
    }

    func testDeleteFolderSetsFolderIdToNull() {
        let folder = Folder(id: UUID(), name: "F", sortOrder: 0, createdAt: Date())
        db.insertFolder(folder)
        let t = makeTranscription(folderId: folder.id)
        db.insertTranscription(t)
        db.deleteFolder(folder.id)
        let fetched = db.fetchTranscriptions()
        XCTAssertNil(fetched[0].folderId)
    }

    func testFolderTranscriptionCount() {
        let folder = Folder(id: UUID(), name: "F", sortOrder: 0, createdAt: Date())
        db.insertFolder(folder)
        for i in 0..<3 {
            db.insertTranscription(makeTranscription(title: "T\(i)", folderId: folder.id))
        }
        let fetched = db.fetchFolders()
        XCTAssertEqual(fetched[0].transcriptionCount, 3)
    }

    // MARK: - Tag CRUD

    func testInsertAndFetchTag() {
        let tag = Tag(id: UUID(), name: "Important", color: "#FF453A")
        db.insertTag(tag)
        let fetched = db.fetchTags()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].name, "Important")
        XCTAssertEqual(fetched[0].color, "#FF453A")
    }

    func testTagUniqueName() {
        let tag1 = Tag(id: UUID(), name: "Dup", color: "#FF453A")
        let tag2 = Tag(id: UUID(), name: "Dup", color: "#0A84FF")
        db.insertTag(tag1)
        db.insertTag(tag2) // INSERT OR IGNORE
        let fetched = db.fetchTags()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].color, "#FF453A")
    }

    func testUpdateTag() {
        var tag = Tag(id: UUID(), name: "Old", color: "#FF453A")
        db.insertTag(tag)
        tag.name = "New"
        tag.color = "#0A84FF"
        db.updateTag(tag)
        let fetched = db.fetchTags()
        XCTAssertEqual(fetched[0].name, "New")
        XCTAssertEqual(fetched[0].color, "#0A84FF")
    }

    func testDeleteTag() {
        let tag = Tag(id: UUID(), name: "ToDelete", color: "#FF453A")
        db.insertTag(tag)
        db.deleteTag(tag.id)
        XCTAssertTrue(db.fetchTags().isEmpty)
    }

    func testDeleteTagCascadesFromTranscriptions() {
        let tag = Tag(id: UUID(), name: "T", color: "#FF453A")
        db.insertTag(tag)
        let t = makeTranscription(tags: [tag])
        db.insertTranscription(t)
        db.deleteTag(tag.id)
        let fetched = db.fetchTranscriptions()
        XCTAssertTrue(fetched[0].tags.isEmpty)
    }

    // MARK: - Transcription CRUD

    func testInsertAndFetchTranscription() {
        let t = makeTranscription(
            title: "Test", content: "Hello world",
            isFavorite: true, duration: 42.5, audioFilename: "test.wav"
        )
        db.insertTranscription(t)
        let fetched = db.fetchTranscriptions()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].title, "Test")
        XCTAssertEqual(fetched[0].content, "Hello world")
        XCTAssertTrue(fetched[0].isFavorite)
        XCTAssertEqual(fetched[0].duration, 42.5, accuracy: 0.1)
        XCTAssertEqual(fetched[0].audioFilename, "test.wav")
    }

    func testTranscriptionOrderedByCreatedAtDesc() {
        let old = makeTranscription(title: "Old", createdAt: Date(timeIntervalSinceNow: -3600))
        let new = makeTranscription(title: "New", createdAt: Date())
        db.insertTranscription(old)
        db.insertTranscription(new)
        let fetched = db.fetchTranscriptions()
        XCTAssertEqual(fetched[0].title, "New")
        XCTAssertEqual(fetched[1].title, "Old")
    }

    func testUpdateTranscription() {
        var t = makeTranscription(title: "Original", content: "A")
        db.insertTranscription(t)
        t.title = "Updated"
        t.content = "B"
        t.isFavorite = true
        db.updateTranscription(t)
        let fetched = db.fetchTranscriptions()
        XCTAssertEqual(fetched[0].title, "Updated")
        XCTAssertEqual(fetched[0].content, "B")
        XCTAssertTrue(fetched[0].isFavorite)
    }

    func testDeleteTranscription() {
        let t = makeTranscription()
        db.insertTranscription(t)
        db.deleteTranscription(t.id)
        XCTAssertTrue(db.fetchTranscriptions().isEmpty)
    }

    func testTranscriptionWithTags() {
        let tag1 = Tag(id: UUID(), name: "Tag1", color: "#FF453A")
        let tag2 = Tag(id: UUID(), name: "Tag2", color: "#0A84FF")
        db.insertTag(tag1)
        db.insertTag(tag2)
        let t = makeTranscription(tags: [tag1, tag2])
        db.insertTranscription(t)
        let fetched = db.fetchTranscriptions()
        XCTAssertEqual(fetched[0].tags.count, 2)
        let names = Set(fetched[0].tags.map(\.name))
        XCTAssertTrue(names.contains("Tag1"))
        XCTAssertTrue(names.contains("Tag2"))
    }

    func testSyncTagsReplacesExistingTags() {
        let tag1 = Tag(id: UUID(), name: "T1", color: "#FF453A")
        let tag2 = Tag(id: UUID(), name: "T2", color: "#0A84FF")
        db.insertTag(tag1)
        db.insertTag(tag2)
        var t = makeTranscription(tags: [tag1])
        db.insertTranscription(t)
        t.tags = [tag2]
        db.updateTranscription(t)
        let fetched = db.fetchTranscriptions()
        XCTAssertEqual(fetched[0].tags.count, 1)
        XCTAssertEqual(fetched[0].tags[0].name, "T2")
    }

    func testTranscriptionWithFolder() {
        let folder = Folder(id: UUID(), name: "F", sortOrder: 0, createdAt: Date())
        db.insertFolder(folder)
        let t = makeTranscription(folderId: folder.id)
        db.insertTranscription(t)
        let fetched = db.fetchTranscriptions()
        XCTAssertEqual(fetched[0].folderId, folder.id)
    }

    // MARK: - Helpers

    private func makeTranscription(
        title: String = "Test",
        content: String = "",
        folderId: UUID? = nil,
        isFavorite: Bool = false,
        duration: TimeInterval = 0,
        audioFilename: String? = nil,
        createdAt: Date = Date(),
        tags: [Tag] = []
    ) -> Transcription {
        Transcription(
            id: UUID(), title: title, content: content, folderId: folderId,
            isFavorite: isFavorite, duration: duration, audioFilename: audioFilename,
            createdAt: createdAt, updatedAt: createdAt, tags: tags
        )
    }
}
