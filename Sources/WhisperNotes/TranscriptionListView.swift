import SwiftUI

struct TranscriptionListView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: search + add button (SnippetsLab style)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
                TextField("Search...", text: $state.searchText)
                    .textFieldStyle(.plain)
                    .font(.callout)
                if !state.searchText.isEmpty {
                    Button {
                        state.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }

                Divider()
                    .frame(height: 16)

                Button {
                    state.showRecording = true
                } label: {
                    Image(systemName: "plus")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("New Recording")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            if state.filteredTranscriptions.isEmpty {
                emptyState
            } else {
                List(state.filteredTranscriptions, selection: $state.selectedTranscription) { transcription in
                    TranscriptionRow(transcription: transcription)
                        .tag(transcription)
                        .contextMenu {
                            Button(transcription.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                                state.toggleFavorite(transcription)
                            }

                            if !state.folders.isEmpty {
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
                            }

                            Divider()

                            Button("Delete", role: .destructive) {
                                state.deleteTranscription(transcription)
                            }
                        }
                }
                .listStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            if state.searchText.isEmpty {
                Text("No transcriptions")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("No results")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct TranscriptionRow: View {
    let transcription: Transcription
    @EnvironmentObject var state: AppState

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Title
            HStack {
                Text(transcription.title)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)
                Spacer()
                if transcription.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
            }

            // Tags row
            if !transcription.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(transcription.tags.prefix(4)) { tag in
                        Text(tag.name)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color(hex: tag.color).opacity(0.2))
                            .foregroundStyle(Color(hex: tag.color))
                            .clipShape(Capsule())
                    }
                }
            }

            // Bottom row: folder + date
            HStack(spacing: 6) {
                if let folderName = state.folderName(for: transcription.folderId) {
                    Image(systemName: "folder")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(folderName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer()
                Text(relativeDate)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 3)
    }

    private var relativeDate: String {
        let cal = Calendar.current
        if cal.isDateInToday(transcription.createdAt) {
            return Self.timeFormatter.string(from: transcription.createdAt)
        }
        return Self.dateFormatter.localizedString(for: transcription.createdAt, relativeTo: Date())
    }
}
