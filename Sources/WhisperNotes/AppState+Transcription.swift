import Foundation
import SwiftUI

extension AppState {

    // MARK: - Recording + Transcription

    func recordAndTranscribe(title: String, folderId: UUID?, audioURL: URL, duration: TimeInterval, languageOverride: String? = nil) {
        isTranscribing = true

        guard let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            errorMessage = "Cannot access Application Support directory."
            isTranscribing = false
            return
        }
        let audioDir = supportDir.appendingPathComponent("WhisperNotes/Audio", isDirectory: true)
        var audioFilename: String?
        do {
            try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
            let filename = "\(UUID().uuidString).wav"
            let permanentURL = audioDir.appendingPathComponent(filename)
            try FileManager.default.copyItem(at: audioURL, to: permanentURL)
            audioFilename = filename
        } catch {
            print("Audio file storage error: \(error)")
        }

        switch selectedEngine {
        case .cohere:
            transcribeWithCohere(
                title: title, folderId: folderId, audioURL: audioURL,
                duration: duration, audioFilename: audioFilename,
                languageOverride: languageOverride
            )
        case .whisper:
            transcribeWithWhisper(
                title: title, folderId: folderId, audioURL: audioURL,
                duration: duration, audioFilename: audioFilename,
                languageOverride: languageOverride
            )
        case .voxtral:
            // Finalize on background thread: stop streaming + batch transcribe for quality
            finalizeVoxtralRecording(
                title: title, folderId: folderId, audioURL: audioURL,
                duration: duration, audioFilename: audioFilename
            )
        }
    }

    private func transcribeWithCohere(
        title: String, folderId: UUID?, audioURL: URL,
        duration: TimeInterval, audioFilename: String?, languageOverride: String?
    ) {
        var service = CohereService(pythonPath: coherePythonPath)
        service.language = languageOverride ?? language

        Task {
            do {
                let text = try await service.transcribe(audioURL: audioURL)
                createTranscription(
                    title: title, content: text, folderId: folderId,
                    duration: duration, audioFilename: audioFilename
                )
            } catch {
                print("Cohere transcription error: \(error)")
                errorMessage = "Cohere transcription failed: \(error.localizedDescription). "
                    + "A note was created with the audio file — you can retry transcription later."
                createTranscription(
                    title: title, content: "",
                    folderId: folderId, duration: duration, audioFilename: audioFilename
                )
            }
            isTranscribing = false
            showRecording = false
        }
    }

    private func transcribeWithWhisper(
        title: String, folderId: UUID?, audioURL: URL,
        duration: TimeInterval, audioFilename: String?, languageOverride: String?
    ) {
        var service = WhisperService(whisperPath: whisperPath, modelPath: modelPath)
        service.language = languageOverride ?? language

        Task {
            do {
                let text = try await service.transcribe(audioURL: audioURL)
                createTranscription(
                    title: title, content: text, folderId: folderId,
                    duration: duration, audioFilename: audioFilename
                )
            } catch {
                print("Transcription error: \(error)")
                errorMessage = "Transcription failed: \(error.localizedDescription). "
                    + "A note was created with the audio file — you can retry transcription later."
                createTranscription(
                    title: title, content: "",
                    folderId: folderId, duration: duration, audioFilename: audioFilename
                )
            }
            isTranscribing = false
            showRecording = false
        }
    }

    // MARK: - Voxtral

    /// Pre-load Voxtral model in background (~5s for 8.3GB).
    /// Call at app start or when engine is switched to Voxtral.
    func preloadVoxtralModel() {
        guard !isVoxtralLoading, !isVoxtralReady else { return }
        isVoxtralLoading = true

        let modelDir = voxtralModelDir
        let delayMs = voxtralDelay

        Task.detached {
            let service = VoxtralService(modelDir: modelDir, delayMs: delayMs)
            do {
                try service.loadModel()
                await MainActor.run {
                    self.voxtralService = service
                    self.isVoxtralReady = true
                    self.isVoxtralLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isVoxtralLoading = false
                    self.errorMessage = "Voxtral model loading failed: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Start Voxtral streaming transcription. Model must be pre-loaded.
    func startVoxtralStreaming() throws -> VoxtralService {
        guard let service = voxtralService, service.isModelLoaded else {
            throw VoxtralError.initFailed
        }
        streamingText = ""
        isStreamingTranscription = true
        return service
    }

    /// Append a token to the streaming text (called from token stream consumer).
    func appendStreamingToken(_ token: String) {
        streamingText.append(token)
    }

    /// Finalize Voxtral recording: flush remaining tokens in background, save immediately.
    func finalizeVoxtralRecording(title: String, folderId: UUID?, audioURL _: URL, duration: TimeInterval, audioFilename: String?) {
        // Dismiss recording sheet immediately — don't block the UI
        showRecording = false

        let service = voxtralService
        let currentStreamText = streamingText

        // Show transcribing state while we flush
        isTranscribing = true
        streamingText = ""
        isStreamingTranscription = false

        Task.detached {
            // Flush remaining audio through encoder+decoder (blocking, ~2-5s)
            let finalText = service?.stopStreaming() ?? currentStreamText

            await MainActor.run {
                let content = finalText.isEmpty ? currentStreamText : finalText
                self.createTranscription(
                    title: title, content: content, folderId: folderId,
                    duration: duration, audioFilename: audioFilename
                )
                self.isTranscribing = false
            }
        }
    }
}
