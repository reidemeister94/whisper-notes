import AppKit
import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var showSavedConfirmation = false

    public init() {}

    public var body: some View {
        Form {
            Section("Transcription Engine") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(TranscriptionEngine.allCases, id: \.self) { engine in
                        engineOption(engine)
                    }
                }

                if state.selectedEngine.supportsStreaming {
                    Label("Real-time streaming enabled", systemImage: "waveform")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Label("Batch mode (transcribes after recording)", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            switch state.selectedEngine {
            case .cohere:
                cohereSection
            case .whisper:
                whisperSection
            case .voxtral:
                voxtralSection
            }

            Section("Language") {
                Picker("Transcription language", selection: $state.language) {
                    ForEach(state.availableLanguages) { lang in
                        Text("\(lang.name) (\(lang.code))").tag(lang.code)
                    }
                }
                if state.selectedEngine == .whisper {
                    Text("Language used for speech recognition. \"Auto-detect\" lets whisper.cpp determine the language automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if state.selectedEngine == .cohere {
                    Text("Cohere is optimized here for Italian. \"Italian default\" passes Italian to the local transcriber.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Language used for speech recognition. \"Auto-detect\" lets Voxtral determine the language automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
                if showSavedConfirmation {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                        .transition(.opacity)
                }
                Spacer()
                Button("Save") {
                    state.saveSettings()
                    withAnimation {
                        showSavedConfirmation = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showSavedConfirmation = false
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 620)
        .padding()
        .onChange(of: state.selectedEngine) { _, newEngine in
            // Migrate language when engine changes
            let available = state.availableLanguages
            if !available.contains(where: { $0.code == state.language }) {
                state.language = "auto"
            }
            // Pre-load Voxtral model when engine switches to Voxtral
            if newEngine == .voxtral {
                state.preloadVoxtralModel()
            }
        }
    }

    private func engineOption(_ engine: TranscriptionEngine) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: state.selectedEngine == engine ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(state.selectedEngine == engine ? Color.accentColor : .secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(engine.displayName)
                    .foregroundStyle(.primary)
                Text(engine.settingsDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            state.selectedEngine = engine
        }
    }

    private var whisperSection: some View {
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
    }

    private var cohereSection: some View {
        Section("Cohere Transcribe") {
            HStack {
                TextField("Python executable", text: $state.coherePythonPath)
                    .textFieldStyle(.roundedBorder)
                Button("Browse") { browse(for: \.coherePythonPath) }
                    .accessibilityHint("Open file picker to locate the Python executable")
            }

            HStack {
                if FileManager.default.fileExists(atPath: CohereService.defaultBackendScriptURL.path) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                    Text("Bundled backend found")
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .accessibilityHidden(true)
                    Text("Bundled backend missing")
                }

                Spacer()

                if FileManager.default.fileExists(atPath: state.coherePythonPath) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                    Text("Python found")
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .accessibilityHidden(true)
                    Text("Python not found")
                }
            }
            .font(.caption)

            VStack(alignment: .leading, spacing: 8) {
                Text("Cohere runs locally through the backend bundled with WhisperNotes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Run setup once to install the local Python dependencies for Cohere Transcribe.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline) {
                    Text(CohereService.setupCommand)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(3)
                    Spacer()
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(
                            CohereService.setupCommand,
                            forType: .string
                        )
                    }
                    .accessibilityHint("Copy the Cohere setup command to the clipboard")
                }

                HStack {
                    Button("Use app venv") {
                        state.coherePythonPath = CohereService.applicationSupportPythonPath
                    }
                    .accessibilityHint("Use the Python virtual environment created by setup")

                    Text(CohereService.applicationSupportPythonPath)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    private var voxtralSection: some View {
        Section("Voxtral Realtime 4B") {
            HStack {
                TextField("Model directory", text: $state.voxtralModelDir)
                    .textFieldStyle(.roundedBorder)
                Button("Browse") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    panel.begin { response in
                        if response == .OK, let url = panel.url {
                            state.voxtralModelDir = url.path
                        }
                    }
                }
                .accessibilityHint("Open folder picker to locate Voxtral model directory")
            }

            // Model status
            HStack {
                let configPath = (state.voxtralModelDir as NSString)
                    .appendingPathComponent("config.json")
                if FileManager.default.fileExists(atPath: configPath) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                    Text("Model found")
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .accessibilityHidden(true)
                    Text("Model not found — download from HuggingFace (mistralai/Voxtral-Mini-4B-Realtime-2602)")
                }
            }
            .font(.caption)

            // Delay slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Transcription delay")
                    Spacer()
                    Text("\(state.voxtralDelay)ms")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(
                    value: Binding(
                        get: { Double(state.voxtralDelay) },
                        set: { state.voxtralDelay = Int($0) }
                    ),
                    in: 80 ... 2400,
                    step: 80
                )
                Text("Lower = faster response, higher = more accurate. 480ms recommended.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
