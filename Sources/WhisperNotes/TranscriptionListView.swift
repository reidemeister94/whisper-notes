import SwiftUI

struct TranscriptionListView: View {
    @EnvironmentObject var state: AppState
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: search + add button
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                        .font(.body)
                    TextField("Search...", text: $state.searchText)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .focused($isSearchFieldFocused)
                    if !state.searchText.isEmpty {
                        Button {
                            state.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                                .font(.body)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.secondary.opacity(0.1))
                )

                Button {
                    state.showRecording = true
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.body)
                        .foregroundStyle(.red)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("New Recording")
                .accessibilityLabel("New Recording")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if state.filteredTranscriptions.isEmpty {
                emptyState
            } else {
                List(state.filteredTranscriptions, selection: $state.selectedTranscription) { transcription in
                    TranscriptionRow(transcription: transcription)
                        .tag(transcription)
                        .draggable(transcription)
                        .contextMenu {
                            Button(transcription.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                                state.toggleFavorite(transcription)
                            }

                            if !state.folders.isEmpty {
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
                            }

                            Divider()

                            Button("Delete", role: .destructive) {
                                state.confirmDeleteTranscription(transcription)
                            }
                        }
                }
                .listStyle(.plain)
            }
        }
        .onChange(of: state.searchFocusTrigger) { _, _ in
            isSearchFieldFocused = true
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: state.searchText.isEmpty ? "waveform" : "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            if state.searchText.isEmpty {
                Text("No transcriptions yet")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("Record something to get started")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                Text("No results")
                    .font(.body.weight(.medium))
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
        VStack(alignment: .leading, spacing: 6) {
            // Title
            HStack {
                Text(transcription.title)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)
                Spacer()
                if transcription.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("Favorite")
                }
            }

            // Tags row
            if !transcription.tags.isEmpty {
                HStack(spacing: 5) {
                    ForEach(transcription.tags.prefix(4)) { tag in
                        Text(tag.name)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(hex: tag.color).opacity(0.15))
                            .foregroundStyle(Color(hex: tag.color))
                            .clipShape(Capsule())
                    }
                }
            }

            // Bottom row: folder + date
            HStack(spacing: 6) {
                if let folderName = state.folderName(for: transcription.folderId) {
                    Image(systemName: "folder")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(folderName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer()
                Text(relativeDate)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 6)
    }

    private var relativeDate: String {
        let cal = Calendar.current
        if cal.isDateInToday(transcription.createdAt) {
            return Self.timeFormatter.string(from: transcription.createdAt)
        }
        return Self.dateFormatter.localizedString(for: transcription.createdAt, relativeTo: Date())
    }
}
