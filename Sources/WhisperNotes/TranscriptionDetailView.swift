import SwiftUI
import UniformTypeIdentifiers

struct TranscriptionDetailView: View {
    let transcription: Transcription
    @EnvironmentObject var state: AppState
    @State private var editTitle = ""
    @State private var editContent = ""
    @State private var editingId: UUID?
    @State private var showTagPicker = false
    @State private var autosaveTask: Task<Void, Never>?
    @FocusState private var isContentFocused: Bool

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: title + toolbar (SnippetsLab style)
            HStack(spacing: 0) {
                TextField("Title", text: $editTitle)
                    .font(.title2.bold())
                    .textFieldStyle(.plain)
                    .onSubmit { save() }

                Spacer(minLength: 16)

                // Toolbar icons
                HStack(spacing: 4) {
                    // Favorite
                    ToolbarIconButton(
                        icon: transcription.isFavorite ? "star.fill" : "star",
                        color: transcription.isFavorite ? .yellow : nil,
                        help: "Toggle favorite"
                    ) {
                        state.toggleFavorite(transcription)
                    }

                    // Tags popover
                    ToolbarIconButton(icon: "tag", help: "Manage tags") {
                        showTagPicker.toggle()
                    }
                    .popover(isPresented: $showTagPicker, arrowEdge: .bottom) {
                        TagPickerView(transcription: transcription)
                            .frame(width: 280, height: 300)
                    }

                    // Copy
                    ToolbarIconButton(icon: "doc.on.doc", help: "Copy to clipboard") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(editContent, forType: .string)
                    }

                    // Export
                    ToolbarIconButton(icon: "square.and.arrow.up", help: "Export") {
                        exportMarkdown()
                    }

                    // More menu
                    Menu {
                        if let folderName = state.folderName(for: transcription.folderId) {
                            Label(folderName, systemImage: "folder")
                        }
                        Divider()

                        Menu("Move to Folder") {
                            Button("No Folder") {
                                state.moveTranscriptionToFolder(transcription, folderId: nil)
                            }
                            Divider()
                            ForEach(state.folders) { folder in
                                Button(folder.name) {
                                    state.moveTranscriptionToFolder(transcription, folderId: folder.id)
                                }
                            }
                        }

                        Button("Show in Finder") {
                            openInFinder()
                        }

                        Divider()

                        Button("Delete", role: .destructive) {
                            state.confirmDeleteTranscription(transcription)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 32)
                    .accessibilityLabel("More options")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.bar)

            Divider()

            // Metadata bar
            HStack(spacing: 16) {
                Label(Self.dateFormatter.string(from: transcription.createdAt), systemImage: "calendar")

                if transcription.duration > 0 {
                    Label(durationString, systemImage: "waveform")
                }

                if !transcription.tags.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(transcription.tags) { tag in
                            Text(tag.name)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color(hex: tag.color).opacity(0.15))
                                .foregroundStyle(Color(hex: tag.color))
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.bar.opacity(0.5))

            Divider()

            // Content editor
            TextEditor(text: $editContent)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .focused($isContentFocused)

            Divider()

            // Bottom status bar
            HStack {
                Text("\(wordCount) words")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                if hasUnsavedChanges {
                    Button("Save") { save() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .keyboardShortcut("s", modifiers: .command)
                        .accessibilityHint("Save pending changes to title and content")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .onAppear {
            editingId = transcription.id
            loadFields()
        }
        .onChange(of: transcription.id) { _, newId in
            if let prevId = editingId, prevId != newId {
                autoSavePrevious(prevId: prevId)
            }
            editingId = newId
            loadFields()
        }
        .onChange(of: editTitle) { _, _ in scheduleAutosave() }
        .onChange(of: editContent) { _, _ in scheduleAutosave() }
        .onDisappear { autosaveTask?.cancel() }
    }

    // MARK: - Helpers

    private func loadFields() {
        autosaveTask?.cancel()
        editTitle = transcription.title
        editContent = transcription.content
    }

    private func save() {
        autosaveTask?.cancel()
        var updated = transcription
        updated.title = editTitle
        updated.content = editContent
        state.updateTranscription(updated)
    }

    private func autoSavePrevious(prevId: UUID) {
        autosaveTask?.cancel()
        guard let prev = state.transcriptions.first(where: { $0.id == prevId }) else { return }
        if prev.title != editTitle || prev.content != editContent {
            var updated = prev
            updated.title = editTitle
            updated.content = editContent
            state.updateTranscription(updated)
        }
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        guard hasUnsavedChanges else { return }
        autosaveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, hasUnsavedChanges else { return }
            save()
        }
    }

    private var hasUnsavedChanges: Bool {
        editTitle != transcription.title || editContent != transcription.content
    }

    private var wordCount: Int {
        editContent.split(whereSeparator: { $0.isWhitespace }).count
    }

    private var durationString: String {
        let m = Int(transcription.duration) / 60
        let s = Int(transcription.duration) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func exportMarkdown() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(transcription.title).md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let content = "# \(transcription.title)\n\n\(editContent)\n"
                try? content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private func openInFinder() {
        let folderName = state.folderName(for: transcription.folderId)
        var dir = URL(fileURLWithPath: state.notesPath)
        if let f = folderName { dir = dir.appendingPathComponent(f) }
        NSWorkspace.shared.open(dir)
    }
}
