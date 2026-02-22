import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Form {
            Section("Whisper") {
                HStack {
                    TextField("whisper-cli path", text: $state.whisperPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse") { browse(for: \.whisperPath) }
                }
                HStack {
                    TextField("Model path", text: $state.modelPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse") { browse(for: \.modelPath) }
                }

                HStack {
                    if FileManager.default.fileExists(atPath: state.whisperPath) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("whisper-cli found")
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("whisper-cli not found")
                    }
                    Spacer()
                    if FileManager.default.fileExists(atPath: state.modelPath) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Model found")
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("Model not found")
                    }
                }
                .font(.caption)
            }

            Section("Storage") {
                HStack {
                    TextField("Notes folder", text: $state.notesPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        panel.begin { response in
                            if response == .OK, let url = panel.url {
                                state.notesPath = url.path
                            }
                        }
                    }
                }
                Text("Markdown files are saved here, compatible with Obsidian")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Save") {
                    state.saveSettings()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 320)
        .padding()
    }

    private func browse(for keyPath: ReferenceWritableKeyPath<AppState, String>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                state[keyPath: keyPath] = url.path
            }
        }
    }
}
