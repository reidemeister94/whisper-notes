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

    // Include updatedAt so SwiftUI detects content changes and re-renders
    static func == (lhs: Transcription, rhs: Transcription) -> Bool {
        lhs.id == rhs.id
        && lhs.title == rhs.title
        && lhs.isFavorite == rhs.isFavorite
        && lhs.folderId == rhs.folderId
        && lhs.updatedAt == rhs.updatedAt
        && lhs.tags == rhs.tags
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct Folder: Identifiable, Hashable {
    let id: UUID
    var name: String
    var sortOrder: Int
    var createdAt: Date
    var transcriptionCount: Int = 0
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
