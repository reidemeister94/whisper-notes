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
    @Environment(\.dismiss) private var dismiss

    private let newFolderSentinel = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
    private let defaultLanguageSentinel = ""

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
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Form
            VStack(spacing: 16) {
                // Title
                VStack(alignment: .leading, spacing: 4) {
                    Text("Title")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Enter a title...", text: $title)
                        .textFieldStyle(.roundedBorder)
                }

                // Folder
                VStack(alignment: .leading, spacing: 4) {
                    Text("Folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isCreatingFolder {
                        HStack {
                            TextField("New folder name...", text: $newFolderName)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    if !newFolderName.isEmpty {
                                        state.createFolder(name: newFolderName)
                                        selectedFolderId = state.folders.first { $0.name == newFolderName }?.id
                                    }
                                    newFolderName = ""
                                    isCreatingFolder = false
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Language")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Language", selection: Binding(
                        get: { languageOverride ?? defaultLanguageSentinel },
                        set: { newValue in
                            languageOverride = newValue == defaultLanguageSentinel ? nil : newValue
                        }
                    )) {
                        Text("Default (\(SupportedLanguage.named(state.language)?.name ?? state.language))")
                            .tag(defaultLanguageSentinel)
                        Divider()
                        ForEach(SupportedLanguage.all) { lang in
                            Text("\(lang.name) (\(lang.code))").tag(lang.code)
                        }
                    }
                    .labelsHidden()
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Recording area
            if state.isTranscribing {
                transcribingView
            } else {
                recordingControls
            }

            Spacer()

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
        .frame(width: 420, height: 520)
        .onAppear {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm"
            title = "Recording \(df.string(from: Date()))"
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

            Button {
                if recorder.isRecording {
                    stopAndTranscribe()
                } else {
                    recorder.startRecording()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(recorder.isRecording ? .red.opacity(0.12) : .red.opacity(0.08))
                        .frame(width: 72, height: 72)

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
            }
            .buttonStyle(.plain)
            .disabled(recorder.permissionDenied)

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

    private func stopAndTranscribe() {
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
            .frame(width: 3, height: height)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.4 + Double(index) * 0.1)
                        .repeatForever(autoreverses: true)
                ) {
                    height = CGFloat.random(in: 8 ... 24)
                }
            }
    }
}
