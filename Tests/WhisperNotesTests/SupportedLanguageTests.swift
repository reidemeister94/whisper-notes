import XCTest
@testable import WhisperNotesLib

final class SupportedLanguageTests: XCTestCase {
    func testAllContainsAutoDetect() {
        XCTAssertTrue(SupportedLanguage.all.contains { $0.code == "auto" })
    }

    func testAllContainsEnglish() {
        XCTAssertTrue(SupportedLanguage.all.contains { $0.code == "en" })
    }

    func testAllContainsItalian() {
        XCTAssertTrue(SupportedLanguage.all.contains { $0.code == "it" })
    }

    func testAutoDetectIsFirst() {
        XCTAssertEqual(SupportedLanguage.all.first?.code, "auto")
    }

    func testAllCodesAreUnique() {
        let codes = SupportedLanguage.all.map(\.code)
        XCTAssertEqual(codes.count, Set(codes).count, "Duplicate language codes found")
    }

    func testAllNamesAreUnique() {
        let names = SupportedLanguage.all.map(\.name)
        XCTAssertEqual(names.count, Set(names).count, "Duplicate language names found")
    }

    func testNamedFindsExistingLanguage() {
        let lang = SupportedLanguage.named("en")
        XCTAssertNotNil(lang)
        XCTAssertEqual(lang?.name, "English")
    }

    func testNamedReturnsNilForUnknown() {
        XCTAssertNil(SupportedLanguage.named("zzz"))
    }

    func testIdentifiable() {
        let lang = SupportedLanguage(code: "en", name: "English")
        XCTAssertEqual(lang.id, "en")
    }

    func testHashable() {
        let set: Set<SupportedLanguage> = [
            SupportedLanguage(code: "en", name: "English"),
            SupportedLanguage(code: "en", name: "English"),
            SupportedLanguage(code: "it", name: "Italian"),
        ]
        XCTAssertEqual(set.count, 2)
    }

    func testAllHasReasonableCount() {
        // 30 languages in the curated list
        XCTAssertEqual(SupportedLanguage.all.count, 30)
    }

    func testCohereLanguagesContainItalian() {
        let languages = SupportedLanguage.all(for: .cohere)
        XCTAssertTrue(languages.contains { $0.code == "it" })
    }

    func testCohereAutoIsItalianDefault() {
        let languages = SupportedLanguage.all(for: .cohere)
        XCTAssertEqual(languages.first?.code, "auto")
        XCTAssertEqual(languages.first?.name, "Italian default")
    }

    func testEqualityUsesCodeOnly() {
        let a = SupportedLanguage(code: "en", name: "English")
        let b = SupportedLanguage(code: "en", name: "Different Name")
        XCTAssertEqual(a, b, "Equality should be based on code only")
    }
}
