import Foundation

struct Transcription: Identifiable, Hashable {
    let id: UUID
    var title: String
    var content: String
    var folderId: UUID?
    var isFavorite: Bool
    var duration: TimeInterval
    var audioFilename: String?
    var createdAt: Date
    var updatedAt: Date
    var tags: [Tag]

    /// Include updatedAt so SwiftUI detects content changes and re-renders
    static func == (lhs: Transcription, rhs: Transcription) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.isFavorite == rhs.isFavorite
            && lhs.folderId == rhs.folderId
            && lhs.updatedAt == rhs.updatedAt
            && lhs.tags == rhs.tags
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Folder: Identifiable, Hashable {
    let id: UUID
    var name: String
    var sortOrder: Int
    var createdAt: Date
    var transcriptionCount = 0
}

struct Tag: Identifiable, Hashable {
    let id: UUID
    var name: String
    var color: String

    static let presetColors: [String] = [
        "#FF453A", "#FF9F0A", "#FFD60A", "#30D158",
        "#0A84FF", "#5E5CE6", "#BF5AF2", "#8E8E93",
    ]
}

enum SidebarSelection: Hashable {
    case all
    case favorites
    case recent
    case folder(UUID)
    case tag(UUID)
}

struct SupportedLanguage: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String {
        code
    }

    static func == (lhs: SupportedLanguage, rhs: SupportedLanguage) -> Bool {
        lhs.code == rhs.code
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(code)
    }

    static let all: [SupportedLanguage] = [
        SupportedLanguage(code: "auto", name: "Auto-detect"),
        SupportedLanguage(code: "en", name: "English"),
        SupportedLanguage(code: "it", name: "Italian"),
        SupportedLanguage(code: "es", name: "Spanish"),
        SupportedLanguage(code: "fr", name: "French"),
        SupportedLanguage(code: "de", name: "German"),
        SupportedLanguage(code: "pt", name: "Portuguese"),
        SupportedLanguage(code: "nl", name: "Dutch"),
        SupportedLanguage(code: "ru", name: "Russian"),
        SupportedLanguage(code: "zh", name: "Chinese"),
        SupportedLanguage(code: "ja", name: "Japanese"),
        SupportedLanguage(code: "ko", name: "Korean"),
        SupportedLanguage(code: "ar", name: "Arabic"),
        SupportedLanguage(code: "hi", name: "Hindi"),
        SupportedLanguage(code: "tr", name: "Turkish"),
        SupportedLanguage(code: "pl", name: "Polish"),
        SupportedLanguage(code: "sv", name: "Swedish"),
        SupportedLanguage(code: "da", name: "Danish"),
        SupportedLanguage(code: "fi", name: "Finnish"),
        SupportedLanguage(code: "no", name: "Norwegian"),
        SupportedLanguage(code: "uk", name: "Ukrainian"),
        SupportedLanguage(code: "el", name: "Greek"),
        SupportedLanguage(code: "cs", name: "Czech"),
        SupportedLanguage(code: "ro", name: "Romanian"),
        SupportedLanguage(code: "hu", name: "Hungarian"),
        SupportedLanguage(code: "ca", name: "Catalan"),
        SupportedLanguage(code: "he", name: "Hebrew"),
        SupportedLanguage(code: "id", name: "Indonesian"),
        SupportedLanguage(code: "vi", name: "Vietnamese"),
        SupportedLanguage(code: "th", name: "Thai"),
    ]

    static func named(_ code: String) -> SupportedLanguage? {
        all.first { $0.code == code }
    }
}
