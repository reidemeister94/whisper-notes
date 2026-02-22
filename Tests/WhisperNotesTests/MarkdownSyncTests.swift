import XCTest
@testable import WhisperNotesLib

final class MarkdownSyncTests: XCTestCase {
    var sync: MarkdownSync!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper-test-\(UUID().uuidString)")
        sync = MarkdownSync(baseURL: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Write

    func testWriteCreatesMarkdownFile() throws {
        let t = makeTranscription(title: "My Note", content: "Hello world")
        sync.write(t, folderName: nil)
        let fileURL = tempDir.appendingPathComponent("My Note.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(content.contains("# My Note"))
        XCTAssertTrue(content.contains("Hello world"))
        XCTAssertTrue(content.contains("id: \(t.id.uuidString)"))
    }

    func testWriteIntoFolder() {
        let t = makeTranscription(title: "FolderNote", content: "In folder")
        sync.write(t, folderName: "MyFolder")
        let fileURL = tempDir
            .appendingPathComponent("MyFolder")
            .appendingPathComponent("FolderNote.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testWriteWithTags() throws {
        let tag = Tag(id: UUID(), name: "Important", color: "#FF453A")
        let t = makeTranscription(title: "Tagged", content: "x", tags: [tag])
        sync.write(t, folderName: nil)
        let content = try String(contentsOf: tempDir.appendingPathComponent("Tagged.md"), encoding: .utf8)
        XCTAssertTrue(content.contains("tags: [\"Important\"]"))
    }

    func testWriteWithFavorite() throws {
        let t = makeTranscription(title: "Fav", content: "x", isFavorite: true)
        sync.write(t, folderName: nil)
        let content = try String(contentsOf: tempDir.appendingPathComponent("Fav.md"), encoding: .utf8)
        XCTAssertTrue(content.contains("favorite: true"))
    }

    func testWriteWithDuration() throws {
        let t = makeTranscription(title: "Dur", content: "x", duration: 120)
        sync.write(t, folderName: nil)
        let content = try String(contentsOf: tempDir.appendingPathComponent("Dur.md"), encoding: .utf8)
        XCTAssertTrue(content.contains("duration: 120"))
    }

    func testWriteRenamesOnTitleChange() {
        let old = makeTranscription(title: "OldTitle", content: "x")
        sync.write(old, folderName: nil)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("OldTitle.md").path
        ))

        let t = makeTranscription(title: "NewTitle", content: "x")
        sync.write(t, folderName: nil, previousTitle: "OldTitle")
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("OldTitle.md").path
        ))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("NewTitle.md").path
        ))
    }

    func testWriteMovesOnFolderChange() {
        let t = makeTranscription(title: "Note", content: "x")
        sync.write(t, folderName: "OldFolder")
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("OldFolder/Note.md").path
        ))

        sync.write(t, folderName: "NewFolder", previousFolderName: "OldFolder")
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("OldFolder/Note.md").path
        ))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("NewFolder/Note.md").path
        ))
    }

    // MARK: - Delete

    func testDeleteRemovesFile() {
        let t = makeTranscription(title: "ToDelete", content: "x")
        sync.write(t, folderName: nil)
        sync.delete(t, folderName: nil)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("ToDelete.md").path
        ))
    }

    // MARK: - Folder operations

    func testCreateFolderDir() {
        sync.createFolderDir("Work")
        let dir = tempDir.appendingPathComponent("Work")
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }

    func testRenameFolderDir() {
        sync.createFolderDir("Old")
        sync.renameFolderDir(from: "Old", to: "New")
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("Old").path
        ))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("New").path
        ))
    }

    func testDeleteFolderDirMovesFilesToBase() {
        sync.createFolderDir("ToDelete")
        let t = makeTranscription(title: "MovedNote", content: "x")
        sync.write(t, folderName: "ToDelete")
        sync.deleteFolderDir("ToDelete")
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("ToDelete").path
        ))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("MovedNote.md").path
        ))
    }

    // MARK: - Sanitize (tested through public methods)

    func testSanitizeStripsInvalidCharacters() {
        let t = makeTranscription(title: "Test/Note:With\\Slashes", content: "x")
        sync.write(t, folderName: nil)
        let fileURL = tempDir.appendingPathComponent("TestNoteWithSlashes.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testSanitizeEmptyTitleBecomesUntitled() {
        let t = makeTranscription(title: "", content: "x")
        sync.write(t, folderName: nil)
        let fileURL = tempDir.appendingPathComponent("untitled.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    // MARK: - Helpers

    private func makeTranscription(
        title: String = "Test",
        content: String = "",
        isFavorite: Bool = false,
        duration: TimeInterval = 0,
        tags: [Tag] = []
    ) -> Transcription {
        Transcription(
            id: UUID(), title: title, content: content, folderId: nil,
            isFavorite: isFavorite, duration: duration, audioFilename: nil,
            createdAt: Date(), updatedAt: Date(), tags: tags
        )
    }
}
