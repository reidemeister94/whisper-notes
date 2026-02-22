import XCTest
@testable import WhisperNotesLib

final class ModelsTests: XCTestCase {
    // MARK: - Transcription

    func testTranscriptionEquality() {
        let id = UUID()
        let now = Date()
        let t1 = Transcription(
            id: id, title: "A", content: "x", folderId: nil,
            isFavorite: false, duration: 0, audioFilename: nil,
            createdAt: now, updatedAt: now, tags: []
        )
        let t2 = Transcription(
            id: id, title: "A", content: "different", folderId: nil,
            isFavorite: false, duration: 0, audioFilename: nil,
            createdAt: now, updatedAt: now, tags: []
        )
        // Equality checks id, title, isFavorite, folderId, updatedAt, tags — NOT content
        XCTAssertEqual(t1, t2)
    }

    func testTranscriptionInequalityOnTitle() {
        let id = UUID()
        let now = Date()
        let t1 = Transcription(
            id: id, title: "A", content: "", folderId: nil,
            isFavorite: false, duration: 0, audioFilename: nil,
            createdAt: now, updatedAt: now, tags: []
        )
        let t2 = Transcription(
            id: id, title: "B", content: "", folderId: nil,
            isFavorite: false, duration: 0, audioFilename: nil,
            createdAt: now, updatedAt: now, tags: []
        )
        XCTAssertNotEqual(t1, t2)
    }

    func testTranscriptionHashUsesOnlyId() {
        let id = UUID()
        let now = Date()
        let t1 = Transcription(
            id: id, title: "A", content: "", folderId: nil,
            isFavorite: false, duration: 0, audioFilename: nil,
            createdAt: now, updatedAt: now, tags: []
        )
        let t2 = Transcription(
            id: id, title: "B", content: "different", folderId: nil,
            isFavorite: true, duration: 99, audioFilename: nil,
            createdAt: now, updatedAt: now, tags: []
        )
        XCTAssertEqual(t1.hashValue, t2.hashValue)
    }

    func testTranscriptionInequalityOnFavorite() {
        let id = UUID()
        let now = Date()
        let t1 = Transcription(
            id: id, title: "A", content: "", folderId: nil,
            isFavorite: false, duration: 0, audioFilename: nil,
            createdAt: now, updatedAt: now, tags: []
        )
        let t2 = Transcription(
            id: id, title: "A", content: "", folderId: nil,
            isFavorite: true, duration: 0, audioFilename: nil,
            createdAt: now, updatedAt: now, tags: []
        )
        XCTAssertNotEqual(t1, t2)
    }

    func testTranscriptionInequalityOnFolder() {
        let id = UUID()
        let now = Date()
        let t1 = Transcription(
            id: id, title: "A", content: "", folderId: nil,
            isFavorite: false, duration: 0, audioFilename: nil,
            createdAt: now, updatedAt: now, tags: []
        )
        let t2 = Transcription(
            id: id, title: "A", content: "", folderId: UUID(),
            isFavorite: false, duration: 0, audioFilename: nil,
            createdAt: now, updatedAt: now, tags: []
        )
        XCTAssertNotEqual(t1, t2)
    }

    // MARK: - Tag

    func testTagPresetColorsCount() {
        XCTAssertEqual(Tag.presetColors.count, 8)
    }

    func testTagPresetColorsAreValidHex() {
        for color in Tag.presetColors {
            XCTAssertTrue(color.hasPrefix("#"), "Color should start with #: \(color)")
            XCTAssertEqual(color.count, 7, "Color should be 7 chars: \(color)")
        }
    }

    // MARK: - SidebarSelection

    func testSidebarSelectionHashable() {
        let set: Set<SidebarSelection> = [.all, .favorites, .recent, .folder(UUID()), .tag(UUID())]
        XCTAssertEqual(set.count, 5)
    }

    func testSidebarSelectionEquality() {
        let id = UUID()
        XCTAssertEqual(SidebarSelection.folder(id), SidebarSelection.folder(id))
        XCTAssertNotEqual(SidebarSelection.folder(id), SidebarSelection.tag(id))
        XCTAssertEqual(SidebarSelection.all, SidebarSelection.all)
        XCTAssertNotEqual(SidebarSelection.all, SidebarSelection.favorites)
    }
}
