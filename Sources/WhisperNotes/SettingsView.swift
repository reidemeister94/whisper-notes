import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject var state: AppState

    public init() {}

    public var body: some View {
        Form {
            Section("Whisper") {
                HStack {
                    TextField("whisper-cli path", text: $state.whisperPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse") { browse(for: \.whisperPath) }
                        .accessibilityHint("Open file picker to locate whisper-cli binary")
                }
                HStack {
                    TextField("Model path", text: $state.modelPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse") { browse(for: \.modelPath) }
                        .accessibilityHint("Open file picker to locate whisper model file")
                }

                HStack {
                    if FileManager.default.fileExists(atPath: state.whisperPath) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .accessibilityHidden(true)
                        Text("whisper-cli found")
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .accessibilityHidden(true)
                        Text("whisper-cli not found")
                    }
                    Spacer()
                    if FileManager.default.fileExists(atPath: state.modelPath) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .accessibilityHidden(true)
                        Text("Model found")
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .accessibilityHidden(true)
                        Text("Model not found")
                    }
                }
                .font(.caption)
            }

            Section("Language") {
                Picker("Transcription language", selection: $state.language) {
                    ForEach(SupportedLanguage.all) { lang in
                        Text("\(lang.name) (\(lang.code))").tag(lang.code)
                    }
                }
                Text("Language used for speech recognition. \"Auto-detect\" lets whisper.cpp determine the language automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    .accessibilityHint("Open folder picker to choose notes storage location")
                }
                Text("Markdown files are saved here")
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
        .frame(width: 500, height: 400)
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
