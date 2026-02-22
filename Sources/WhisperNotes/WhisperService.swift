import Foundation

struct WhisperService {
    var whisperPath: String
    var modelPath: String
    var language: String = "it"
    var timeoutSeconds: TimeInterval = 300

    static var defaultWhisperPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Documents/whisper.cpp/build/bin/whisper-cli"
    }

    static var defaultModelPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Documents/whisper.cpp/models/ggml-large-v3-turbo.bin"
    }

    func transcribe(audioURL: URL) async throws -> String {
        guard FileManager.default.fileExists(atPath: whisperPath) else {
            throw WhisperError.cliNotFound(whisperPath)
        }
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw WhisperError.modelNotFound(modelPath)
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: whisperPath)
                process.arguments = ["-m", modelPath, "-f", audioURL.path, "-l", language, "-nt"]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice

                do {
                    try process.run()

                    // Timeout: kill process if it takes too long
                    let timeout = DispatchWorkItem {
                        if process.isRunning { process.terminate() }
                    }
                    DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds, execute: timeout)

                    // FIX: read pipe BEFORE waitUntilExit to avoid deadlock
                    // when output exceeds pipe buffer (~64KB)
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    timeout.cancel()

                    guard process.terminationStatus == 0 else {
                        continuation.resume(throwing: WhisperError.processFailed(
                            "whisper-cli exited with code \(process.terminationStatus)"))
                        return
                    }

                    let raw = String(data: data, encoding: .utf8) ?? ""
                    let text = raw
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    continuation.resume(returning: text)
                } catch {
                    continuation.resume(throwing: WhisperError.processFailed(error.localizedDescription))
                }
            }
        }
    }
}

enum WhisperError: LocalizedError {
    case cliNotFound(String)
    case modelNotFound(String)
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .cliNotFound(let p): return "whisper-cli not found at: \(p)"
        case .modelNotFound(let p): return "Model not found at: \(p)"
        case .processFailed(let msg): return "Transcription failed: \(msg)"
        }
    }
}
