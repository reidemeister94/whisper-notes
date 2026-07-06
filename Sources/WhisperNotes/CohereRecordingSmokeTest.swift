import AVFoundation
import Foundation

public struct CohereRecordingSmokeTestResult {
    public let markdownURL: URL
    public let transcription: String
}

enum CohereRecordingSmokeTestError: LocalizedError {
    case microphonePermissionDenied
    case recordingDidNotStart
    case recordedAudioMissing
    case transcriptionTimedOut
    case transcriptionFailed(String)
    case markdownMissing
    case emptyTranscription(URL)

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            "Microphone permission denied for WhisperNotes."
        case .recordingDidNotStart:
            "Recording did not start."
        case .recordedAudioMissing:
            "Recording stopped without producing an audio file."
        case .transcriptionTimedOut:
            "Cohere transcription did not finish before the smoke-test timeout."
        case let .transcriptionFailed(message):
            "Cohere transcription failed: \(message)"
        case .markdownMissing:
            "No Markdown file was created for the smoke-test recording."
        case let .emptyTranscription(url):
            "The smoke-test Markdown file has an empty transcription: \(url.path)"
        }
    }
}

@MainActor
public enum CohereRecordingSmokeTest {
    public static func run(appState: AppState) async throws -> CohereRecordingSmokeTestResult {
        printStage("configure")
        let env = ProcessInfo.processInfo.environment
        let phrase = env["WHISPER_NOTES_SMOKE_TEST_PHRASE"]
            ?? "Questa e' una prova di registrazione con il motore Cohere in WhisperNotes."
        let voice = env["WHISPER_NOTES_SMOKE_TEST_VOICE"]
        let title = env["WHISPER_NOTES_SMOKE_TEST_TITLE"]
            ?? "Cohere Recording Smoke Test"
        let notesPath = env["WHISPER_NOTES_SMOKE_TEST_NOTES_PATH"] ?? appState.notesPath

        appState.selectedEngine = .cohere
        appState.language = "it"
        appState.notesPath = notesPath
        appState.coherePythonPath = env["WHISPER_NOTES_COHERE_PYTHON"]
            ?? appState.coherePythonPath
        appState.hasCompletedSetup = true
        appState.saveSettings()

        let notesURL = URL(fileURLWithPath: notesPath, isDirectory: true)
        try FileManager.default.createDirectory(at: notesURL, withIntermediateDirectories: true)
        let filesBefore = markdownFiles(in: notesURL)

        printStage("recording_start")
        let recorder = AudioRecorder()
        recorder.startRecording()
        try await sleep(seconds: 1.0)

        if recorder.permissionDenied {
            throw CohereRecordingSmokeTestError.microphonePermissionDenied
        }
        guard recorder.isRecording else {
            throw CohereRecordingSmokeTestError.recordingDidNotStart
        }

        printStage("speaking")
        try await speak(phrase, voice: voice)
        try await sleep(seconds: 1.0)

        printStage("recording_stop")
        let duration = recorder.elapsedTime
        guard let audioURL = recorder.stopRecording() else {
            throw CohereRecordingSmokeTestError.recordedAudioMissing
        }

        printStage("transcribing")
        appState.recordAndTranscribe(
            title: title,
            folderId: nil,
            audioURL: audioURL,
            duration: duration,
            languageOverride: "it"
        )

        let markdownURL = try await waitForMarkdown(
            appState: appState,
            notesURL: notesURL,
            filesBefore: filesBefore
        )
        printStage("markdown_created")
        let transcription = try extractTranscription(from: markdownURL)
        guard !transcription.isEmpty else {
            throw CohereRecordingSmokeTestError.emptyTranscription(markdownURL)
        }
        return CohereRecordingSmokeTestResult(
            markdownURL: markdownURL,
            transcription: transcription
        )
    }

    private static func speak(_ phrase: String, voice: String?) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
                if let voice, !voice.isEmpty {
                    process.arguments = ["-v", voice, phrase]
                } else {
                    process.arguments = [phrase]
                }
                do {
                    try process.run()
                    process.waitUntilExit()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func waitForMarkdown(
        appState: AppState,
        notesURL: URL,
        filesBefore: Set<URL>
    ) async throws -> URL {
        let timeout = Date().addingTimeInterval(180)
        while Date() < timeout {
            if let message = appState.errorMessage {
                throw CohereRecordingSmokeTestError.transcriptionFailed(message)
            }

            let filesAfter = markdownFiles(in: notesURL)
            let created = filesAfter.subtracting(filesBefore)
            if !appState.isTranscribing, let newest = newestFile(in: created) {
                return newest
            }

            try await sleep(seconds: 0.5)
        }
        throw CohereRecordingSmokeTestError.transcriptionTimedOut
    }

    private static func markdownFiles(in directory: URL) -> Set<URL> {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files = Set<URL>()
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "md" {
            files.insert(fileURL)
        }
        return files
    }

    private static func newestFile(in files: Set<URL>) -> URL? {
        files.max { lhs, rhs in
            modificationDate(lhs) < modificationDate(rhs)
        }
    }

    private static func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            ?? .distantPast
    }

    private static func extractTranscription(from markdownURL: URL) throws -> String {
        let raw = try String(contentsOf: markdownURL, encoding: .utf8)
        let parts = raw.components(separatedBy: "---")
        if parts.count >= 3 {
            return parts.dropFirst(2).joined(separator: "---")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private static func printStage(_ stage: String) {
        print("SMOKE_TEST_STAGE \(stage)")
        fflush(stdout)
    }
}
