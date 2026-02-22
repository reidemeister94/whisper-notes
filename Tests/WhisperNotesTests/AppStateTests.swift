import XCTest
@testable import WhisperNotesLib

@MainActor
final class AppStateTests: XCTestCase {
    var dbPath: String!
    var tempDir: URL!
    var appState: AppState!

    override func setUp() {
        super.setUp()
        dbPath = NSTemporaryDirectory() + "test-\(UUID().uuidString).db"
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper-test-\(UUID().uuidString)")
        let db = Database(path: dbPath)
        let mdSync = MarkdownSync(baseURL: tempDir)
        appState = AppState(db: db, mdSync: mdSync)
    }

    override func tearDown() {
        appState = nil
        try? FileManager.default.removeItem(atPath: dbPath)
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Initial state

    func testInitialStateIsEmpty() {
        XCTAssertTrue(appState.transcriptions.isEmpty)
        XCTAssertTrue(appState.folders.isEmpty)
        XCTAssertTrue(appState.tags.isEmpty)
        XCTAssertFalse(appState.showRecording)
        XCTAssertFalse(appState.isTranscribing)
        XCTAssertEqual(appState.sidebarSelection, .all)
        XCTAssertNil(appState.selectedTranscription)
    }

    // MARK: - Transcription CRUD

    func testCreateTranscription() {
        appState.createTranscription(title: "Test", content: "Hello", folderId: nil, duration: 42, audioFilename: "a.wav")
        XCTAssertEqual(appState.transcriptions.count, 1)
        XCTAssertEqual(appState.transcriptions[0].title, "Test")
        XCTAssertEqual(appState.transcriptions[0].content, "Hello")
        XCTAssertEqual(appState.transcriptions[0].duration, 42, accuracy: 0.1)
        XCTAssertEqual(appState.selectedTranscription?.title, "Test")
    }

    func testUpdateTranscription() {
        appState.createTranscription(title: "Old", content: "", folderId: nil, duration: 0, audioFilename: nil)
        var t = appState.transcriptions[0]
        t.title = "New"
        t.content = "Updated content"
        appState.updateTranscription(t)
        XCTAssertEqual(appState.transcriptions[0].title, "New")
        XCTAssertEqual(appState.transcriptions[0].content, "Updated content")
    }

    func testDeleteTranscription() {
        appState.createTranscription(title: "A", content: "", folderId: nil, duration: 0, audioFilename: nil)
        let t = appState.transcriptions[0]
        appState.selectedTranscription = t
        appState.deleteTranscription(t)
        XCTAssertTrue(appState.transcriptions.isEmpty)
        XCTAssertNil(appState.selectedTranscription)
    }

    func testToggleFavorite() {
        appState.createTranscription(title: "A", content: "", folderId: nil, duration: 0, audioFilename: nil)
        let t = appState.transcriptions[0]
        XCTAssertFalse(t.isFavorite)
        appState.toggleFavorite(t)
        XCTAssertTrue(appState.transcriptions[0].isFavorite)
        appState.toggleFavorite(appState.transcriptions[0])
        XCTAssertFalse(appState.transcriptions[0].isFavorite)
    }

    // MARK: - Filtered transcriptions

    func testFilteredTranscriptionsAll() {
        appState.createTranscription(title: "A", content: "", folderId: nil, duration: 0, audioFilename: nil)
        appState.createTranscription(title: "B", content: "", folderId: nil, duration: 0, audioFilename: nil)
        appState.sidebarSelection = .all
        XCTAssertEqual(appState.filteredTranscriptions.count, 2)
    }

    func testFilteredTranscriptionsFavorites() {
        appState.createTranscription(title: "A", content: "", folderId: nil, duration: 0, audioFilename: nil)
        appState.createTranscription(title: "B", content: "", folderId: nil, duration: 0, audioFilename: nil)
        appState.toggleFavorite(appState.transcriptions[0])
        appState.sidebarSelection = .favorites
        XCTAssertEqual(appState.filteredTranscriptions.count, 1)
    }

    func testFilteredTranscriptionsRecent() {
        appState.createTranscription(title: "Recent", content: "", folderId: nil, duration: 0, audioFilename: nil)
        appState.sidebarSelection = .recent
        XCTAssertEqual(appState.filteredTranscriptions.count, 1)
    }

    func testFilteredTranscriptionsByFolder() throws {
        appState.createFolder(name: "Work")
        let folderId = try XCTUnwrap(appState.folders.first?.id)
        appState.createTranscription(title: "InFolder", content: "", folderId: folderId, duration: 0, audioFilename: nil)
        appState.createTranscription(title: "NoFolder", content: "", folderId: nil, duration: 0, audioFilename: nil)
        appState.sidebarSelection = .folder(folderId)
        XCTAssertEqual(appState.filteredTranscriptions.count, 1)
        XCTAssertEqual(appState.filteredTranscriptions[0].title, "InFolder")
    }

    func testFilteredTranscriptionsUncategorized() throws {
        appState.createFolder(name: "Work")
        let folderId = try XCTUnwrap(appState.folders.first?.id)
        appState.createTranscription(title: "InFolder", content: "", folderId: folderId, duration: 0, audioFilename: nil)
        appState.createTranscription(title: "NoFolder", content: "", folderId: nil, duration: 0, audioFilename: nil)
        appState.sidebarSelection = .folder(SidebarSelection.uncategorizedFolderID)
        XCTAssertEqual(appState.filteredTranscriptions.count, 1)
        XCTAssertEqual(appState.filteredTranscriptions[0].title, "NoFolder")
    }

    func testFilteredTranscriptionsByTag() throws {
        appState.createTag(name: "Important", color: "#FF453A")
        let tag = try XCTUnwrap(appState.tags.first)
        appState.createTranscription(title: "A", content: "", folderId: nil, duration: 0, audioFilename: nil)
        appState.createTranscription(title: "B", content: "", folderId: nil, duration: 0, audioFilename: nil)
        appState.addTag(tag, to: appState.transcriptions[0])
        appState.sidebarSelection = .tag(tag.id)
        XCTAssertEqual(appState.filteredTranscriptions.count, 1)
    }

    func testFilteredTranscriptionsSearch() {
        appState.createTranscription(title: "Meeting Notes", content: "budget discussion", folderId: nil, duration: 0, audioFilename: nil)
        appState.createTranscription(title: "Shopping List", content: "milk", folderId: nil, duration: 0, audioFilename: nil)
        appState.searchText = "budget"
        XCTAssertEqual(appState.filteredTranscriptions.count, 1)
        XCTAssertEqual(appState.filteredTranscriptions[0].title, "Meeting Notes")
    }

    func testSearchIsCaseInsensitive() {
        appState.createTranscription(title: "HELLO World", content: "", folderId: nil, duration: 0, audioFilename: nil)
        appState.searchText = "hello"
        XCTAssertEqual(appState.filteredTranscriptions.count, 1)
    }

    func testSearchMatchesContent() {
        appState.createTranscription(title: "Note", content: "secret keyword here", folderId: nil, duration: 0, audioFilename: nil)
        appState.searchText = "keyword"
        XCTAssertEqual(appState.filteredTranscriptions.count, 1)
    }

    // MARK: - Folder CRUD

    func testCreateFolder() {
        appState.createFolder(name: "Work")
        XCTAssertEqual(appState.folders.count, 1)
        XCTAssertEqual(appState.folders[0].name, "Work")
    }

    func testCreateFolderReturnsFolder() {
        let folder = appState.createFolder(name: "Projects")
        XCTAssertEqual(folder.name, "Projects")
        XCTAssertEqual(appState.folders.first(where: { $0.id == folder.id })?.name, "Projects")
    }

    func testRenameFolder() {
        appState.createFolder(name: "Old")
        let folder = appState.folders[0]
        appState.renameFolder(folder, to: "New")
        XCTAssertEqual(appState.folders[0].name, "New")
    }

    func testDeleteFolder() {
        appState.createFolder(name: "ToDelete")
        let folder = appState.folders[0]
        appState.sidebarSelection = .folder(folder.id)
        appState.deleteFolder(folder)
        XCTAssertTrue(appState.folders.isEmpty)
        XCTAssertEqual(appState.sidebarSelection, .all)
    }

    // MARK: - Tag CRUD

    func testCreateTag() {
        appState.createTag(name: "Work", color: "#FF453A")
        XCTAssertEqual(appState.tags.count, 1)
        XCTAssertEqual(appState.tags[0].name, "Work")
    }

    func testDeleteTag() {
        appState.createTag(name: "ToDelete", color: "#FF453A")
        let tag = appState.tags[0]
        appState.sidebarSelection = .tag(tag.id)
        appState.deleteTag(tag)
        XCTAssertTrue(appState.tags.isEmpty)
        XCTAssertEqual(appState.sidebarSelection, .all)
    }

    func testAddTagToTranscription() throws {
        appState.createTag(name: "T", color: "#FF453A")
        appState.createTranscription(title: "A", content: "", folderId: nil, duration: 0, audioFilename: nil)
        let tag = appState.tags[0]
        let t = appState.transcriptions[0]
        appState.addTag(tag, to: t)
        let updated = try XCTUnwrap(appState.transcriptions.first { $0.id == t.id })
        XCTAssertEqual(updated.tags.count, 1)
        XCTAssertEqual(updated.tags[0].name, "T")
    }

    func testRemoveTagFromTranscription() throws {
        appState.createTag(name: "T", color: "#FF453A")
        appState.createTranscription(title: "A", content: "", folderId: nil, duration: 0, audioFilename: nil)
        let tag = appState.tags[0]
        appState.addTag(tag, to: appState.transcriptions[0])
        let updated = try XCTUnwrap(appState.transcriptions.first { $0.id == appState.transcriptions[0].id })
        appState.removeTag(tag, from: updated)
        let result = appState.transcriptions[0]
        XCTAssertTrue(result.tags.isEmpty)
    }

    func testAddDuplicateTagDoesNothing() throws {
        appState.createTag(name: "T", color: "#FF453A")
        appState.createTranscription(title: "A", content: "", folderId: nil, duration: 0, audioFilename: nil)
        let tag = appState.tags[0]
        appState.addTag(tag, to: appState.transcriptions[0])
        let updated = try XCTUnwrap(appState.transcriptions.first { $0.id == appState.transcriptions[0].id })
        appState.addTag(tag, to: updated)
        let result = appState.transcriptions[0]
        XCTAssertEqual(result.tags.count, 1)
    }

    // MARK: - Helpers

    func testFolderNameForId() {
        appState.createFolder(name: "Work")
        let folderId = appState.folders[0].id
        XCTAssertEqual(appState.folderName(for: folderId), "Work")
        XCTAssertNil(appState.folderName(for: nil))
        XCTAssertNil(appState.folderName(for: UUID()))
    }

    // MARK: - Language

    func testDefaultLanguageIsAuto() {
        XCTAssertEqual(appState.language, "auto")
    }

    func testLanguageCanBeChanged() {
        appState.language = "en"
        XCTAssertEqual(appState.language, "en")
    }

    func testHasCompletedSetupDefaultsToTrue() {
        // Test init sets hasCompletedSetup = true to skip setup in tests
        XCTAssertTrue(appState.hasCompletedSetup)
    }

    func testHasCompletedSetupCanBeOverridden() {
        let tmpDb = NSTemporaryDirectory() + "test-\(UUID().uuidString).db"
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(atPath: tmpDb)
            try? FileManager.default.removeItem(at: tmpDir)
        }
        let db = Database(path: tmpDb)
        let mdSync = MarkdownSync(baseURL: tmpDir)
        let state = AppState(db: db, mdSync: mdSync, hasCompletedSetup: false)
        XCTAssertFalse(state.hasCompletedSetup)
    }

    // MARK: - Markdown sync integration

    func testCreateTranscriptionWritesMarkdown() {
        appState.createTranscription(title: "MarkdownTest", content: "Hello", folderId: nil, duration: 0, audioFilename: nil)
        let fileURL = tempDir.appendingPathComponent("MarkdownTest.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testDeleteTranscriptionRemovesMarkdown() {
        appState.createTranscription(title: "ToDelete", content: "", folderId: nil, duration: 0, audioFilename: nil)
        let t = appState.transcriptions[0]
        appState.deleteTranscription(t)
        let fileURL = tempDir.appendingPathComponent("ToDelete.md")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }
}
