import Foundation
import SwiftUI

enum TranscriptionEngine: String, CaseIterable {
    case whisper
    case cohere
    case voxtral

    var displayName: String {
        switch self {
        case .cohere: "Cohere Transcribe 03-2026"
        case .whisper: "Whisper (whisper.cpp)"
        case .voxtral: "Voxtral Realtime 4B"
        }
    }

    var settingsDescription: String {
        switch self {
        case .cohere: "Highest-quality local transcription backend for Italian speech."
        case .whisper: "Classic local whisper.cpp transcription."
        case .voxtral: "Realtime preview with final batch transcription."
        }
    }

    var supportsStreaming: Bool {
        self == .voxtral
    }
}

@MainActor
public final class AppState: ObservableObject {
    // Data
    @Published public var transcriptions: [Transcription] = []
    @Published public var folders: [Folder] = []
    @Published public var tags: [Tag] = []

    // Navigation
    @Published public var sidebarSelection: SidebarSelection? = .all
    @Published public var selectedTranscription: Transcription?
    @Published public var searchText = ""

    // Recording
    @Published public var showRecording = false
    @Published var isTranscribing = false

    // Streaming transcription (Voxtral real-time)
    @Published var streamingText = ""
    @Published var isStreamingTranscription = false

    // Delete confirmation (setting non-nil triggers the alert)
    @Published var transcriptionToDelete: Transcription?
    @Published var folderToDelete: Folder?

    /// User-facing error message (setting non-nil triggers an alert)
    @Published var errorMessage: String?

    /// Search focus trigger (increment to focus; avoids reset race condition)
    @Published public var searchFocusTrigger = 0

    /// Engine selection
    @Published var selectedEngine: TranscriptionEngine

    // Whisper settings
    @Published var whisperPath: String
    @Published var modelPath: String

    /// Cohere settings
    @Published var coherePythonPath: String

    // Voxtral settings
    @Published var voxtralModelDir: String
    @Published var voxtralDelay: Int

    // Common settings
    @Published var notesPath: String
    @Published public var language: String
    @Published public var hasCompletedSetup: Bool

    let db: Database
    var mdSync: MarkdownSync

    /// Voxtral engine (pre-loaded at app start for instant recording).
    /// Internal (not private) so the recording flow in `AppState+Transcription.swift` can reach it.
    var voxtralService: VoxtralService?
    @Published var isVoxtralLoading = false
    @Published var isVoxtralReady = false

    public init() {
        let defaults = UserDefaults.standard
        whisperPath = defaults.string(forKey: "whisperPath") ?? WhisperService.defaultWhisperPath
        modelPath = defaults.string(forKey: "modelPath") ?? WhisperService.defaultModelPath
        coherePythonPath = defaults.string(forKey: "coherePythonPath")
            ?? CohereService.defaultPythonPath
        language = defaults.string(forKey: "language") ?? "auto"
        hasCompletedSetup = defaults.bool(forKey: "hasCompletedSetup")

        // Engine selection
        let engineRaw = defaults.string(forKey: "selectedEngine") ?? "whisper"
        selectedEngine = TranscriptionEngine(rawValue: engineRaw) ?? .whisper

        // Voxtral settings
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        voxtralModelDir = defaults.string(forKey: "voxtralModelDir") ?? "\(home)/Models/voxtral-mini-4b"
        let savedDelay = defaults.integer(forKey: "voxtralDelay")
        voxtralDelay = savedDelay == 0 ? 480 : savedDelay

        let notes = defaults.string(forKey: "notesPath") ?? "\(home)/Documents/Whisper Notes"
        notesPath = notes
        db = Database()
        mdSync = MarkdownSync(baseURL: URL(fileURLWithPath: notes))

        // Migrate language if not supported by currently selected engine
        migrateLanguageIfNeeded()

        reload()

        // Pre-load Voxtral model in background if selected
        if selectedEngine == .voxtral {
            preloadVoxtralModel()
        }
    }

    init(db: Database, mdSync: MarkdownSync, hasCompletedSetup: Bool = true) {
        self.db = db
        self.mdSync = mdSync
        whisperPath = WhisperService.defaultWhisperPath
        modelPath = WhisperService.defaultModelPath
        coherePythonPath = CohereService.defaultPythonPath
        notesPath = mdSync.baseURL.path
        language = "auto"
        self.hasCompletedSetup = hasCompletedSetup
        selectedEngine = .whisper
        voxtralModelDir = ""
        voxtralDelay = 480
        reload()
    }

    func reload() {
        transcriptions = db.fetchTranscriptions()
        folders = db.fetchFolders()
        tags = db.fetchTags()
    }

    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(whisperPath, forKey: "whisperPath")
        defaults.set(modelPath, forKey: "modelPath")
        defaults.set(coherePythonPath, forKey: "coherePythonPath")
        defaults.set(notesPath, forKey: "notesPath")
        defaults.set(language, forKey: "language")
        defaults.set(selectedEngine.rawValue, forKey: "selectedEngine")
        defaults.set(voxtralModelDir, forKey: "voxtralModelDir")
        defaults.set(voxtralDelay, forKey: "voxtralDelay")
        mdSync = MarkdownSync(baseURL: URL(fileURLWithPath: notesPath))
    }

    public func completeSetup() {
        UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
        hasCompletedSetup = true
        saveSettings()
    }

    /// Languages available for the currently selected engine
    var availableLanguages: [SupportedLanguage] {
        SupportedLanguage.all(for: selectedEngine)
    }

    private func migrateLanguageIfNeeded() {
        let available = SupportedLanguage.all(for: selectedEngine)
        if !available.contains(where: { $0.code == language }) {
            language = "auto"
        }
    }

    // MARK: - Filtered transcriptions

    var filteredTranscriptions: [Transcription] {
        var list = transcriptions

        switch sidebarSelection {
        case .all, nil:
            break
        case .favorites:
            list = list.filter(\.isFavorite)
        case .recent:
            let cutoff = Date().addingTimeInterval(-7 * 86400)
            list = list.filter { $0.createdAt >= cutoff }
        case let .folder(id):
            if id == SidebarSelection.uncategorizedFolderID {
                list = list.filter { $0.folderId == nil }
            } else {
                list = list.filter { $0.folderId == id }
            }
        case let .tag(id):
            list = list.filter { t in t.tags.contains { $0.id == id } }
        }

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                $0.title.lowercased().contains(q) || $0.content.lowercased().contains(q)
            }
        }

        return list
    }

    // MARK: - Transcription CRUD

    func createTranscription(title: String, content: String, folderId: UUID?, duration: TimeInterval, audioFilename: String?) {
        let now = Date()
        let t = Transcription(
            id: UUID(), title: title, content: content, folderId: folderId,
            isFavorite: false, duration: duration, audioFilename: audioFilename,
            createdAt: now, updatedAt: now, tags: []
        )
        db.insertTranscription(t)
        let folderName = folders.first { $0.id == folderId }?.name
        mdSync.write(t, folderName: folderName)
        reload()
        selectedTranscription = transcriptions.first { $0.id == t.id }
        if let folderId {
            sidebarSelection = .folder(folderId)
        }
    }

    func updateTranscription(_ t: Transcription) {
        let old = transcriptions.first { $0.id == t.id }
        let oldTitle = old?.title
        let oldFolderName = folderName(for: old?.folderId)

        var updated = t
        updated.updatedAt = Date()
        db.updateTranscription(updated)

        let newFolderName = folders.first { $0.id == updated.folderId }?.name
        mdSync.write(updated, folderName: newFolderName, previousTitle: oldTitle, previousFolderName: oldFolderName)

        reload()
        selectedTranscription = transcriptions.first { $0.id == t.id }
    }

    func deleteTranscription(_ t: Transcription) {
        let folderName = folders.first { $0.id == t.folderId }?.name
        mdSync.delete(t, folderName: folderName)
        db.deleteTranscription(t.id)
        if selectedTranscription?.id == t.id { selectedTranscription = nil }
        reload()
    }

    func toggleFavorite(_ t: Transcription) {
        var updated = t
        updated.isFavorite.toggle()
        updateTranscription(updated)
    }

    // MARK: - Folder CRUD

    @discardableResult
    public func createFolder(name: String) -> Folder {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let safeName = String(trimmed.prefix(200))
        let finalName = safeName.isEmpty ? "New Folder" : safeName
        let f = Folder(id: UUID(), name: finalName, sortOrder: folders.count, createdAt: Date())
        db.insertFolder(f)
        mdSync.createFolderDir(finalName)
        reload()
        return f
    }

    func renameFolder(_ folder: Folder, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let safeName = String(trimmed.prefix(200))
        guard !safeName.isEmpty else { return }
        let oldName = folder.name
        var updated = folder
        updated.name = safeName
        db.updateFolder(updated)
        mdSync.renameFolderDir(from: oldName, to: safeName)
        reload()
    }

    func deleteFolder(_ folder: Folder) {
        mdSync.deleteFolderDir(folder.name)
        db.deleteFolder(folder.id)
        if sidebarSelection == .folder(folder.id) { sidebarSelection = .all }
        reload()
    }

    // MARK: - Tag CRUD

    @discardableResult
    func createTag(name: String, color: String) -> Tag {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let safeName = String(trimmed.prefix(50))
        let t = Tag(id: UUID(), name: safeName.isEmpty ? "Untitled Tag" : safeName, color: color)
        db.insertTag(t)
        reload()
        return t
    }

    func deleteTag(_ tag: Tag) {
        db.deleteTag(tag.id)
        if sidebarSelection == .tag(tag.id) { sidebarSelection = .all }
        reload()
    }

    func addTag(_ tag: Tag, to transcription: Transcription) {
        var updated = transcription
        if !updated.tags.contains(where: { $0.id == tag.id }) {
            updated.tags.append(tag)
            updateTranscription(updated)
        }
    }

    func removeTag(_ tag: Tag, from transcription: Transcription) {
        var updated = transcription
        updated.tags.removeAll { $0.id == tag.id }
        updateTranscription(updated)
    }

    // MARK: - Delete confirmation

    func confirmDeleteTranscription(_ t: Transcription) {
        transcriptionToDelete = t
    }

    func executeDeleteTranscription() {
        guard let t = transcriptionToDelete else { return }
        deleteTranscription(t)
        transcriptionToDelete = nil
    }

    func confirmDeleteFolder(_ folder: Folder) {
        folderToDelete = folder
    }

    func executeDeleteFolder() {
        guard let folder = folderToDelete else { return }
        deleteFolder(folder)
        folderToDelete = nil
    }

    public func deleteSelectedItem() {
        if let transcription = selectedTranscription {
            confirmDeleteTranscription(transcription)
            return
        }
        if case let .folder(folderId) = sidebarSelection,
           folderId != SidebarSelection.uncategorizedFolderID,
           let folder = folders.first(where: { $0.id == folderId })
        {
            confirmDeleteFolder(folder)
        }
    }

    // MARK: - Keyboard shortcut helpers

    func moveTranscriptionToFolder(_ transcription: Transcription, folderId: UUID?) {
        var updated = transcription
        updated.folderId = folderId
        updateTranscription(updated)
    }

    func handleDrop(uuidStrings: [String], targetFolderId: UUID?) -> Bool {
        for uuidString in uuidStrings {
            guard let uuid = UUID(uuidString: uuidString),
                  let transcription = transcriptions.first(where: { $0.id == uuid })
            else { continue }
            moveTranscriptionToFolder(transcription, folderId: targetFolderId)
        }
        return !uuidStrings.isEmpty
    }

    public func toggleFavoriteSelected() {
        guard let transcription = selectedTranscription else { return }
        toggleFavorite(transcription)
    }

    // MARK: - Helpers

    func folderName(for id: UUID?) -> String? {
        guard let id else { return nil }
        return folders.first { $0.id == id }?.name
    }
}
