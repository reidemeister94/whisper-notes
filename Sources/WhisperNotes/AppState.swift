import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    // Data
    @Published var transcriptions: [Transcription] = []
    @Published var folders: [Folder] = []
    @Published var tags: [Tag] = []

    // Navigation
    @Published var sidebarSelection: SidebarSelection? = .all
    @Published var selectedTranscription: Transcription?
    @Published var searchText = ""

    // Recording
    @Published var showRecording = false
    @Published var isTranscribing = false

    // Settings
    @Published var whisperPath: String
    @Published var modelPath: String
    @Published var notesPath: String

    let db = Database()
    var mdSync: MarkdownSync

    init() {
        let defaults = UserDefaults.standard
        self.whisperPath = defaults.string(forKey: "whisperPath") ?? WhisperService.defaultWhisperPath
        self.modelPath = defaults.string(forKey: "modelPath") ?? WhisperService.defaultModelPath

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let notes = defaults.string(forKey: "notesPath") ?? "\(home)/Documents/Whisper Notes"
        self.notesPath = notes
        self.mdSync = MarkdownSync(baseURL: URL(fileURLWithPath: notes))

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
        defaults.set(notesPath, forKey: "notesPath")
        mdSync = MarkdownSync(baseURL: URL(fileURLWithPath: notesPath))
    }

    // MARK: - Filtered transcriptions

    var filteredTranscriptions: [Transcription] {
        var list = transcriptions

        switch sidebarSelection {
        case .all, nil:
            break
        case .favorites:
            list = list.filter { $0.isFavorite }
        case .recent:
            let cutoff = Date().addingTimeInterval(-7 * 86400)
            list = list.filter { $0.createdAt >= cutoff }
        case .folder(let id):
            // Special UUID = "Uncategorized" (no folder)
            if id == UUID(uuidString: "00000000-0000-0000-0000-000000000000") {
                list = list.filter { $0.folderId == nil }
            } else {
                list = list.filter { $0.folderId == id }
            }
        case .tag(let id):
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
    }

    func updateTranscription(_ t: Transcription) {
        // Track old title/folder for .md rename
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

    func createFolder(name: String) {
        let f = Folder(id: UUID(), name: name, sortOrder: folders.count, createdAt: Date())
        db.insertFolder(f)
        mdSync.createFolderDir(name)
        reload()
    }

    func renameFolder(_ folder: Folder, to name: String) {
        let oldName = folder.name
        var updated = folder
        updated.name = name
        db.updateFolder(updated)
        mdSync.renameFolderDir(from: oldName, to: name)
        reload()
    }

    func deleteFolder(_ folder: Folder) {
        mdSync.deleteFolderDir(folder.name)
        db.deleteFolder(folder.id)
        if sidebarSelection == .folder(folder.id) { sidebarSelection = .all }
        reload()
    }

    // MARK: - Tag CRUD

    func createTag(name: String, color: String) {
        let t = Tag(id: UUID(), name: name, color: color)
        db.insertTag(t)
        reload()
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

    // MARK: - Recording + Transcription

    func recordAndTranscribe(title: String, folderId: UUID?, audioURL: URL, duration: TimeInterval) {
        isTranscribing = true
        let service = WhisperService(whisperPath: whisperPath, modelPath: modelPath)

        let audioDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("WhisperNotes/Audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
        let audioFilename = "\(UUID().uuidString).wav"
        let permanentURL = audioDir.appendingPathComponent(audioFilename)
        try? FileManager.default.copyItem(at: audioURL, to: permanentURL)

        Task {
            do {
                let text = try await service.transcribe(audioURL: audioURL)
                createTranscription(
                    title: title, content: text, folderId: folderId,
                    duration: duration, audioFilename: audioFilename
                )
            } catch {
                print("Transcription error: \(error)")
                createTranscription(
                    title: title, content: "[Transcription failed: \(error.localizedDescription)]",
                    folderId: folderId, duration: duration, audioFilename: audioFilename
                )
            }
            isTranscribing = false
            showRecording = false
        }
    }

    // MARK: - Helpers

    func folderName(for id: UUID?) -> String? {
        guard let id = id else { return nil }
        return folders.first { $0.id == id }?.name
    }
}
