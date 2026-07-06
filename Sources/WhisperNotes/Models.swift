import Foundation
import SwiftUI

public struct Transcription: Identifiable, Hashable {
    public let id: UUID
    public var title: String
    public var content: String
    public var folderId: UUID?
    public var isFavorite: Bool
    public var duration: TimeInterval
    public var audioFilename: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var tags: [Tag]

    public init(
        id: UUID, title: String, content: String, folderId: UUID?,
        isFavorite: Bool, duration: TimeInterval, audioFilename: String?,
        createdAt: Date, updatedAt: Date, tags: [Tag]
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.folderId = folderId
        self.isFavorite = isFavorite
        self.duration = duration
        self.audioFilename = audioFilename
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
    }

    /// Include updatedAt so SwiftUI detects content changes and re-renders
    public static func == (lhs: Transcription, rhs: Transcription) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.isFavorite == rhs.isFavorite
            && lhs.folderId == rhs.folderId
            && lhs.updatedAt == rhs.updatedAt
            && lhs.tags == rhs.tags
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct Folder: Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var sortOrder: Int
    public var createdAt: Date
    public var transcriptionCount = 0

    public init(id: UUID, name: String, sortOrder: Int, createdAt: Date, transcriptionCount: Int = 0) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.transcriptionCount = transcriptionCount
    }
}

public struct Tag: Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var color: String

    public init(id: UUID, name: String, color: String) {
        self.id = id
        self.name = name
        self.color = color
    }

    public static let presetColors: [String] = [
        "#FF453A", "#FF9F0A", "#FFD60A", "#30D158",
        "#0A84FF", "#5E5CE6", "#BF5AF2", "#8E8E93",
    ]
}

extension Transcription: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.id.uuidString)
    }
}

public enum SidebarSelection: Hashable {
    case all
    case favorites
    case recent
    case folder(UUID)
    case tag(UUID)

    // swiftlint:disable:next force_unwrapping
    public static let uncategorizedFolderID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
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

    /// All languages supported by Whisper (superset)
    static let whisperLanguages: [SupportedLanguage] = [
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

    /// Languages supported by Voxtral Mini 4B Realtime (13 + auto)
    static let voxtralLanguages: [SupportedLanguage] = [
        SupportedLanguage(code: "auto", name: "Auto-detect"),
        SupportedLanguage(code: "ar", name: "Arabic"),
        SupportedLanguage(code: "de", name: "German"),
        SupportedLanguage(code: "en", name: "English"),
        SupportedLanguage(code: "es", name: "Spanish"),
        SupportedLanguage(code: "fr", name: "French"),
        SupportedLanguage(code: "hi", name: "Hindi"),
        SupportedLanguage(code: "it", name: "Italian"),
        SupportedLanguage(code: "ja", name: "Japanese"),
        SupportedLanguage(code: "ko", name: "Korean"),
        SupportedLanguage(code: "nl", name: "Dutch"),
        SupportedLanguage(code: "pt", name: "Portuguese"),
        SupportedLanguage(code: "ru", name: "Russian"),
        SupportedLanguage(code: "zh", name: "Chinese"),
    ]

    /// Languages supported by Cohere Transcribe 03-2026.
    static let cohereLanguages: [SupportedLanguage] = [
        SupportedLanguage(code: "auto", name: "Italian default"),
        SupportedLanguage(code: "ar", name: "Arabic"),
        SupportedLanguage(code: "de", name: "German"),
        SupportedLanguage(code: "el", name: "Greek"),
        SupportedLanguage(code: "en", name: "English"),
        SupportedLanguage(code: "es", name: "Spanish"),
        SupportedLanguage(code: "fr", name: "French"),
        SupportedLanguage(code: "it", name: "Italian"),
        SupportedLanguage(code: "ja", name: "Japanese"),
        SupportedLanguage(code: "ko", name: "Korean"),
        SupportedLanguage(code: "nl", name: "Dutch"),
        SupportedLanguage(code: "pl", name: "Polish"),
        SupportedLanguage(code: "pt", name: "Portuguese"),
        SupportedLanguage(code: "vi", name: "Vietnamese"),
        SupportedLanguage(code: "zh", name: "Chinese"),
    ]

    /// Returns languages for the given engine
    static func all(for engine: TranscriptionEngine) -> [SupportedLanguage] {
        switch engine {
        case .cohere: cohereLanguages
        case .whisper: whisperLanguages
        case .voxtral: voxtralLanguages
        }
    }

    /// Legacy accessor — returns Whisper languages (superset)
    static var all: [SupportedLanguage] {
        whisperLanguages
    }

    static func named(_ code: String) -> SupportedLanguage? {
        whisperLanguages.first { $0.code == code }
    }
}
