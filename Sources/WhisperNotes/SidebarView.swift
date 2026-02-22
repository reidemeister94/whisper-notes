import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var state: AppState
    @State private var newFolderName = ""
    @State private var isAddingFolder = false
    @State private var newTagName = ""
    @State private var newTagColor = Tag.presetColors[4]
    @State private var isAddingTag = false
    @State private var renamingFolder: Folder?
    @State private var renameText = ""

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $state.sidebarSelection) {
                // Favorites (smart folders)
                Section("Favorites") {
                    sidebarRow("All Transcriptions", icon: "tray.full", iconColor: .blue,
                               count: state.transcriptions.count)
                        .tag(SidebarSelection.all)

                    sidebarRow("Favorites", icon: "star.fill", iconColor: .yellow,
                               count: state.transcriptions.filter(\.isFavorite).count)
                        .tag(SidebarSelection.favorites)

                    sidebarRow("Recent", icon: "clock", iconColor: .green,
                               count: recentCount)
                        .tag(SidebarSelection.recent)

                    sidebarRow("Uncategorized", icon: "archivebox", iconColor: .gray,
                               count: state.transcriptions.filter { $0.folderId == nil }.count)
                        .tag(SidebarSelection.folder(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!))
                }

                // Folders
                Section {
                    ForEach(state.folders) { folder in
                        if renamingFolder?.id == folder.id {
                            TextField("Folder name", text: $renameText)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    if !renameText.isEmpty {
                                        state.renameFolder(folder, to: renameText)
                                    }
                                    renamingFolder = nil
                                }
                        } else {
                            sidebarRow(folder.name, icon: "folder.fill", iconColor: .blue,
                                       count: folder.transcriptionCount)
                                .tag(SidebarSelection.folder(folder.id))
                                .contextMenu {
                                    Button("Rename") {
                                        renameText = folder.name
                                        renamingFolder = folder
                                    }
                                    Divider()
                                    Button("Delete", role: .destructive) {
                                        state.deleteFolder(folder)
                                    }
                                }
                        }
                    }

                    if isAddingFolder {
                        TextField("Folder name", text: $newFolderName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                if !newFolderName.isEmpty {
                                    state.createFolder(name: newFolderName)
                                }
                                newFolderName = ""
                                isAddingFolder = false
                            }
                    }
                } header: {
                    Text("Folders")
                }

                // Tags
                Section {
                    ForEach(state.tags) { tag in
                        HStack(spacing: 8) {
                            Image(systemName: "tag")
                                .font(.caption)
                                .foregroundStyle(Color(hex: tag.color))
                            Text(tag.name)
                            Spacer()
                            Text("\(tagCount(tag.id))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .tag(SidebarSelection.tag(tag.id))
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                state.deleteTag(tag)
                            }
                        }
                    }

                    if isAddingTag {
                        HStack(spacing: 6) {
                            TextField("Tag name", text: $newTagName)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    if !newTagName.isEmpty {
                                        state.createTag(name: newTagName, color: newTagColor)
                                    }
                                    newTagName = ""
                                    isAddingTag = false
                                }

                            Menu {
                                ForEach(Tag.presetColors, id: \.self) { color in
                                    Button {
                                        newTagColor = color
                                    } label: {
                                        Label(color == newTagColor ? "Selected" : "",
                                              systemImage: color == newTagColor ? "checkmark.circle.fill" : "circle.fill")
                                    }
                                    .tint(Color(hex: color))
                                }
                            } label: {
                                Circle()
                                    .fill(Color(hex: newTagColor))
                                    .frame(width: 14, height: 14)
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 24)
                        }
                    }
                } header: {
                    Text("Tags")
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Bottom toolbar
            HStack(spacing: 12) {
                Menu {
                    Button {
                        isAddingFolder = true
                    } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                    Button {
                        newTagColor = Tag.presetColors.randomElement() ?? Tag.presetColors[4]
                        isAddingTag = true
                    } label: {
                        Label("New Tag", systemImage: "tag")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.callout)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func sidebarRow(_ title: String, icon: String, iconColor: Color, count: Int) -> some View {
        Label {
            HStack {
                Text(title)
                Spacer()
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
        }
    }

    private var recentCount: Int {
        let cutoff = Date().addingTimeInterval(-7 * 86400)
        return state.transcriptions.filter { $0.createdAt >= cutoff }.count
    }

    private func tagCount(_ tagId: UUID) -> Int {
        state.transcriptions.filter { t in t.tags.contains { $0.id == tagId } }.count
    }
}
