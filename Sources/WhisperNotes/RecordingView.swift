import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var state: AppState
    @StateObject private var recorder = AudioRecorder()
    @State private var title = ""
    @State private var selectedFolderId: UUID?
    @State private var isCreatingFolder = false
    @State private var newFolderName = ""
    @State private var languageOverride: String?
    @State private var errorMessage: String?
    @State private var voxtralTokenStream: AsyncStream<String>?
    @State private var tokenConsumerTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss

    private let newFolderSentinel = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
    private let defaultLanguageSentinel = ""

    private var defaultLanguageName: String {
        state.availableLanguages.first { $0.code == state.language }?.name ?? state.language
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Recording")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .disabled(recorder.isRecording || state.isTranscribing)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Form
            VStack(spacing: 20) {
                // Title
                VStack(alignment: .leading, spacing: 6) {
                    Text("Title")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextField("Enter a title...", text: $title)
                        .textFieldStyle(.roundedBorder)
                }

                // Folder
                VStack(alignment: .leading, spacing: 6) {
                    Text("Folder")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    if isCreatingFolder {
                        HStack {
                            TextField("New folder name...", text: $newFolderName)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    commitPendingFolderCreation()
                                }
                            Button("Cancel") {
                                isCreatingFolder = false
                                selectedFolderId = nil
                            }
                            .controlSize(.small)
                        }
                    } else {
                        Picker("Folder", selection: $selectedFolderId) {
                            Text("No Folder").tag(nil as UUID?)
                            ForEach(state.folders) { folder in
                                Text(folder.name).tag(folder.id as UUID?)
                            }
                            Divider()
                            Label("New Folder...", systemImage: "folder.badge.plus")
                                .tag(newFolderSentinel as UUID?)
                        }
                        .labelsHidden()
                        .onChange(of: selectedFolderId) { _, newValue in
                            if newValue == newFolderSentinel {
                                selectedFolderId = nil
                                isCreatingFolder = true
                            }
                        }
                    }
                }
                // Language override
                VStack(alignment: .leading, spacing: 6) {
                    Text("Language")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Picker("Language", selection: Binding(
                        get: { languageOverride ?? defaultLanguageSentinel },
                        set: { newValue in
                            languageOverride = newValue == defaultLanguageSentinel ? nil : newValue
                        }
                    )) {
                        Text("Default (\(defaultLanguageName))")
                            .tag(defaultLanguageSentinel)
                        Divider()
                        ForEach(state.availableLanguages) { lang in
                            Text("\(lang.name) (\(lang.code))").tag(lang.code)
                        }
                    }
                    .labelsHidden()
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Recording area
            if state.isTranscribing, !state.selectedEngine.supportsStreaming {
                transcribingView
            } else {
                recordingControls
            }

            // Live transcription text (Voxtral streaming)
            if state.isStreamingTranscription, !state.streamingText.isEmpty {
                liveTranscriptionView
            }

            Spacer()

            // Voxtral loading status
            if state.selectedEngine == .voxtral, state.isVoxtralLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading Voxtral model...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 4)
            }

            // Errors
            if recorder.permissionDenied {
                Label(
                    "Microphone access denied. Check System Settings.",
                    systemImage: "mic.slash"
                )
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            } else if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }
        }
        .frame(width: 420, height: state.selectedEngine.supportsStreaming ? 620 : 520)
        .onAppear {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm"
            title = "Recording \(df.string(from: Date()))"
        }
        .onDisappear {
            tokenConsumerTask?.cancel()
        }
    }

    private var recordingControls: some View {
        VStack(spacing: 16) {
            Text(recorder.formatTime(recorder.elapsedTime))
                .font(.system(size: 44, weight: .ultraLight, design: .monospaced))
                .foregroundStyle(recorder.isRecording ? .primary : .tertiary)

            if recorder.isRecording {
                HStack(spacing: 4) {
                    ForEach(0 ..< 5, id: \.self) { i in
                        RecordingBar(index: i)
                    }
                }
                .frame(height: 24)
            }

            ZStack {
                Circle()
                    .fill(recorder.isRecording ? .red.opacity(0.12) : .red.opacity(0.08))

                if recorder.isRecording {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.red)
                        .frame(width: 24, height: 24)
                } else {
                    Circle()
                        .fill(.red)
                        .frame(width: 32, height: 32)
                }
            }
            .frame(width: 72, height: 72)
            .contentShape(Circle())
            .opacity(recorder.permissionDenied ? 0.45 : 1)
            .onTapGesture {
                guard !recorder.permissionDenied else { return }
                toggleRecording()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Start recording")
            .accessibilityHint(
                recorder.isRecording
                    ? "Stops recording and begins transcription"
                    : "Starts audio recording"
            )
            .accessibilityAction {
                toggleRecording()
            }

            Text(recorder.isRecording ? "Click to stop" : "Click to record")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var transcribingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Transcribing...")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
            Text("This may take a moment")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var liveTranscriptionView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text("Live Transcription")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)

            ScrollViewReader { proxy in
                ScrollView {
                    Text(state.streamingText)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .id("streamingText")
                }
                .frame(maxHeight: 120)
                .onChange(of: state.streamingText) { _, _ in
                    proxy.scrollTo("streamingText", anchor: .bottom)
                }
            }
        }
    }

    private func commitPendingFolderCreation() {
        guard isCreatingFolder, !newFolderName.isEmpty else { return }
        let folder = state.createFolder(name: newFolderName)
        selectedFolderId = folder.id
        newFolderName = ""
        isCreatingFolder = false
    }

    private func startRecording() {
        if state.selectedEngine == .voxtral {
            guard state.isVoxtralReady else {
                errorMessage = state.isVoxtralLoading
                    ? "Voxtral model is still loading, please wait..."
                    : "Voxtral model not loaded. Check Settings."
                return
            }

            // Start streaming for live preview (model already loaded)
            do {
                let service = try state.startVoxtralStreaming()
                let tokenStream = try service.startStreaming()
                voxtralTokenStream = tokenStream

                recorder.onAudioBuffer = { buffer in
                    service.feedAudio(buffer)
                }

                tokenConsumerTask = Task {
                    for await token in tokenStream {
                        await MainActor.run {
                            state.appendStreamingToken(token)
                        }
                    }
                }
            } catch {
                errorMessage = "Voxtral streaming failed: \(error.localizedDescription)"
                return
            }
        }

        recorder.startRecording()
    }

    private func toggleRecording() {
        if recorder.isRecording {
            stopAndTranscribe()
        } else {
            commitPendingFolderCreation()
            startRecording()
        }
    }

    private func stopAndTranscribe() {
        commitPendingFolderCreation()

        // Stop audio capture first
        tokenConsumerTask?.cancel()
        tokenConsumerTask = nil
        recorder.onAudioBuffer = nil

        guard let audioURL = recorder.stopRecording() else {
            errorMessage = "No audio recorded"
            return
        }

        let finalTitle = title.isEmpty ? "Untitled Recording" : title
        state.recordAndTranscribe(
            title: finalTitle,
            folderId: selectedFolderId,
            audioURL: audioURL,
            duration: recorder.elapsedTime,
            languageOverride: languageOverride
        )
    }
}

struct RecordingBar: View {
    let index: Int
    @State private var height: CGFloat = 5

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(.red)
            .frame(width: 4, height: height)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.4 + Double(index) * 0.1)
                        .repeatForever(autoreverses: true)
                ) {
                    height = CGFloat.random(in: 8 ... 32)
                }
            }
    }
}
