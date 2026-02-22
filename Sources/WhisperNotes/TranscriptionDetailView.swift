import SwiftUI
import UniformTypeIdentifiers

struct TranscriptionDetailView: View {
    let transcription: Transcription
    @EnvironmentObject var state: AppState
    @State private var editTitle = ""
    @State private var editContent = ""
    @State private var editingId: UUID?
    @State private var showTagPicker = false
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

                // Toolbar icons (SnippetsLab style)
                HStack(spacing: 2) {
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
                                var t = transcription
                                t.folderId = nil
                                state.updateTranscription(t)
                            }
                            Divider()
                            ForEach(state.folders) { folder in
                                Button(folder.name) {
                                    var t = transcription
                                    t.folderId = folder.id
                                    state.updateTranscription(t)
                                }
                            }
                        }

                        Button("Show in Finder") {
                            openInFinder()
                        }

                        Divider()

                        Button("Delete", role: .destructive) {
                            state.deleteTranscription(transcription)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 28)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)

            Divider()

            // Metadata bar
            HStack(spacing: 16) {
                Label(Self.dateFormatter.string(from: transcription.createdAt), systemImage: "calendar")

                if transcription.duration > 0 {
                    Label(durationString, systemImage: "waveform")
                }

                if !transcription.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(transcription.tags) { tag in
                            Text(tag.name)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
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
            .padding(.vertical, 8)
            .background(.bar.opacity(0.5))

            Divider()

            // Content editor
            TextEditor(text: $editContent)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .focused($isContentFocused)

            Divider()

            // Bottom status bar
            HStack {
                Text("\(wordCount) words")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                if hasUnsavedChanges {
                    Button("Save") { save() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                        .keyboardShortcut("s", modifiers: .command)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
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
    }

    // MARK: - Helpers

    private func loadFields() {
        editTitle = transcription.title
        editContent = transcription.content
    }

    private func save() {
        var updated = transcription
        updated.title = editTitle
        updated.content = editContent
        state.updateTranscription(updated)
    }

    private func autoSavePrevious(prevId: UUID) {
        guard let prev = state.transcriptions.first(where: { $0.id == prevId }) else { return }
        if prev.title != editTitle || prev.content != editContent {
            var updated = prev
            updated.title = editTitle
            updated.content = editContent
            state.updateTranscription(updated)
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

// MARK: - Toolbar icon button

struct ToolbarIconButton: View {
    let icon: String
    var color: Color?
    var help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(color ?? .secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Tag Picker (SnippetsLab style)

struct TagPickerView: View {
    let transcription: Transcription
    @EnvironmentObject var state: AppState
    @State private var inputText = ""

    private var assignedTags: [Tag] {
        transcription.tags
    }

    private var suggestions: [Tag] {
        let assigned = Set(transcription.tags.map(\.id))
        var available = state.tags.filter { !assigned.contains($0.id) }
        if !inputText.isEmpty {
            let q = inputText.lowercased()
            available = available.filter { $0.name.lowercased().contains(q) }
        }
        return available
    }

    private var canCreateNew: Bool {
        let q = inputText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return false }
        return !state.tags.contains { $0.name.lowercased() == q }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Assign tags")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // Assigned tags + input (SnippetsLab style)
            FlowLayout(spacing: 4) {
                ForEach(assignedTags) { tag in
                    HStack(spacing: 3) {
                        Text(tag.name)
                            .font(.caption)
                        Button {
                            state.removeTag(tag, from: transcription)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.2))
                    .clipShape(Capsule())
                }

                TextField("Add tag...", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .frame(minWidth: 60)
                    .onSubmit {
                        createAndAssign()
                    }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.secondary.opacity(0.1))
            )
            .padding(.horizontal, 16)

            // Suggestions
            if !suggestions.isEmpty || canCreateNew {
                Text("Suggestions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)

                FlowLayout(spacing: 4) {
                    if canCreateNew {
                        Button {
                            createAndAssign()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "plus")
                                    .font(.system(size: 8, weight: .bold))
                                Text(inputText)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.2))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(suggestions) { tag in
                        Button {
                            state.addTag(tag, to: transcription)
                        } label: {
                            Text(tag.name)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }

            Spacer()
        }
    }

    private func createAndAssign() {
        let name = inputText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        if let existing = state.tags.first(where: { $0.name.lowercased() == name.lowercased() }) {
            state.addTag(existing, to: transcription)
        } else {
            let color = Tag.presetColors.randomElement() ?? Tag.presetColors[4]
            state.createTag(name: name, color: color)
            if let newTag = state.tags.first(where: { $0.name.lowercased() == name.lowercased() }) {
                state.addTag(newTag, to: transcription)
            }
        }
        inputText = ""
    }
}

// MARK: - Flow Layout for tag pills

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
