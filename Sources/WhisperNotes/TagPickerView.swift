import SwiftUI

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
                        .accessibilityLabel("Remove \(tag.name)")
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
                        .accessibilityLabel("Create tag \(inputText)")
                        .accessibilityHint("Creates a new tag and assigns it to this transcription")
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
                        .accessibilityHint("Assign this tag to the transcription")
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
            let newTag = state.createTag(name: name, color: color)
            state.addTag(newTag, to: transcription)
        }
        inputText = ""
    }
}
