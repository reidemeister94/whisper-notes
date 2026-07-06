import Foundation

struct CohereService {
    var pythonPath: String
    var backendScriptURL: URL = Self.defaultBackendScriptURL
    var language = "it"
    var timeoutSeconds: TimeInterval = 900

    static var applicationSupportBackendDirectory: URL {
        let supportDir = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        return supportDir.appendingPathComponent("WhisperNotes/CohereBackend", isDirectory: true)
    }

    static var applicationSupportPythonPath: String {
        applicationSupportBackendDirectory
            .appendingPathComponent("venv/bin/python")
            .path
    }

    static var defaultPythonPath: String {
        let candidates = [
            applicationSupportPythonPath,
            "/opt/anaconda3/envs/whisper/bin/python",
            "/opt/miniconda3/envs/whisper/bin/python",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
            ?? "/usr/bin/python3"
    }

    static var bundledBackendDirectoryURL: URL? {
        Bundle.module.url(forResource: "CohereBackend", withExtension: nil)
    }

    static var defaultBackendScriptURL: URL {
        bundledBackendDirectoryURL?.appendingPathComponent("cohere_transcribe.py")
            ?? URL(fileURLWithPath: "/nonexistent/WhisperNotes/CohereBackend/cohere_transcribe.py")
    }

    static var setupScriptURL: URL? {
        bundledBackendDirectoryURL?.appendingPathComponent("setup_cohere_backend.sh")
    }

    static var setupCommand: String {
        guard let setupScriptURL else {
            return "Cohere backend not found in the app bundle."
        }
        return "bash \(shellQuoted(setupScriptURL.path))"
    }

    func arguments(audioURL: URL) -> [String] {
        [
            backendScriptURL.path,
            audioURL.path,
            "--language", resolvedLanguage,
        ]
    }

    func transcribe(audioURL: URL) async throws -> String {
        let resolvedPythonPath = pythonPath.isEmpty ? Self.defaultPythonPath : pythonPath

        guard FileManager.default.fileExists(atPath: backendScriptURL.path) else {
            throw CohereError.backendNotFound(backendScriptURL.path)
        }
        guard FileManager.default.fileExists(atPath: resolvedPythonPath) else {
            throw CohereError.pythonNotFound(resolvedPythonPath)
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: resolvedPythonPath)
                process.arguments = arguments(audioURL: audioURL)
                process.environment = Self.processEnvironment()

                let stdout = Pipe()
                let stderr = Pipe()
                process.standardOutput = stdout
                process.standardError = stderr

                do {
                    try process.run()

                    let timeout = DispatchWorkItem {
                        if process.isRunning { process.terminate() }
                    }
                    DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds, execute: timeout)

                    let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    timeout.cancel()

                    guard process.terminationStatus == 0 else {
                        let stderrText = String(data: stderrData, encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        let message = stderrText?.isEmpty == false
                            ? stderrText!
                            : "Cohere backend exited with code \(process.terminationStatus)"
                        continuation.resume(throwing: CohereError.processFailed(message))
                        return
                    }

                    let text = String(data: stdoutData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    continuation.resume(returning: text)
                } catch {
                    continuation.resume(throwing: CohereError.processFailed(error.localizedDescription))
                }
            }
        }
    }

    private var resolvedLanguage: String {
        language == "auto" ? "it" : language
    }

    private static func processEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let fallbackPath = [
            applicationSupportBackendDirectory.appendingPathComponent("venv/bin").path,
            "/opt/anaconda3/envs/whisper/bin",
            "/opt/miniconda3/envs/whisper/bin",
            "/opt/anaconda3/bin",
            "/opt/anaconda3/condabin",
            "/opt/miniconda3/bin",
            "/opt/miniconda3/condabin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
        ].joined(separator: ":")
        let currentPath = env["PATH"] ?? ""
        env["PATH"] = currentPath.isEmpty ? fallbackPath : "\(fallbackPath):\(currentPath)"
        env["PYTHONUNBUFFERED"] = "1"
        return env
    }

    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

enum CohereError: LocalizedError {
    case backendNotFound(String)
    case pythonNotFound(String)
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case let .backendNotFound(path): "Cohere backend not found in WhisperNotes: \(path)"
        case let .pythonNotFound(path): "Python executable not found at: \(path)"
        case let .processFailed(message): "Cohere transcription failed: \(message)"
        }
    }
}
