import XCTest
@testable import WhisperNotesLib

final class CohereServiceTests: XCTestCase {
    func testDefaultPythonPathIsAbsolute() {
        XCTAssertTrue(CohereService.defaultPythonPath.hasPrefix("/"))
    }

    func testBundledBackendScriptPathPointsToCohereBackend() {
        let path = CohereService.defaultBackendScriptURL.path

        XCTAssertTrue(path.contains("CohereBackend"))
        XCTAssertTrue(path.hasSuffix("/cohere_transcribe.py"))
    }

    func testSetupCommandUsesBundledSetupScript() {
        let command = CohereService.setupCommand

        XCTAssertTrue(command.hasPrefix("bash "))
        XCTAssertTrue(command.contains("setup_cohere_backend.sh"))
    }

    func testArgumentsIncludeAudioPathAndLanguage() {
        let service = CohereService(
            pythonPath: "/fake/python",
            backendScriptURL: URL(fileURLWithPath: "/fake/cohere_transcribe.py"),
            language: "it"
        )
        let args = service.arguments(audioURL: URL(fileURLWithPath: "/tmp/audio.wav"))

        XCTAssertEqual(args, ["/fake/cohere_transcribe.py", "/tmp/audio.wav", "--language", "it"])
    }

    func testAutoLanguageFallsBackToItalian() {
        let service = CohereService(
            pythonPath: "/fake/python",
            backendScriptURL: URL(fileURLWithPath: "/fake/cohere_transcribe.py"),
            language: "auto"
        )
        let args = service.arguments(audioURL: URL(fileURLWithPath: "/tmp/audio.wav"))

        XCTAssertEqual(args, ["/fake/cohere_transcribe.py", "/tmp/audio.wav", "--language", "it"])
    }

    func testTranscribeThrowsBackendNotFound() async {
        let service = CohereService(
            pythonPath: "/bin/bash",
            backendScriptURL: URL(fileURLWithPath: "/nonexistent/cohere_transcribe.py")
        )
        do {
            _ = try await service.transcribe(audioURL: URL(fileURLWithPath: "/tmp/audio.wav"))
            XCTFail("Should have thrown")
        } catch let error as CohereError {
            if case let .backendNotFound(path) = error {
                XCTAssertEqual(path, "/nonexistent/cohere_transcribe.py")
            } else {
                XCTFail("Expected backendNotFound, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testTranscribeThrowsPythonNotFound() async throws {
        let scriptURL = try makeBackendScript(
            """
            #!/usr/bin/env bash
            echo "unused"
            """
        )
        defer { try? FileManager.default.removeItem(at: scriptURL) }

        let service = CohereService(
            pythonPath: "/nonexistent/python",
            backendScriptURL: scriptURL
        )

        do {
            _ = try await service.transcribe(audioURL: URL(fileURLWithPath: "/tmp/audio.wav"))
            XCTFail("Should have thrown")
        } catch let error as CohereError {
            if case let .pythonNotFound(path) = error {
                XCTAssertEqual(path, "/nonexistent/python")
            } else {
                XCTFail("Expected pythonNotFound, got \(error)")
            }
        }
    }

    func testTranscribeReturnsStdoutFromBackend() async throws {
        let scriptURL = try makeBackendScript(
            """
            #!/usr/bin/env bash
            echo "ciao dal modello"
            """
        )
        defer { try? FileManager.default.removeItem(at: scriptURL) }

        let service = CohereService(
            pythonPath: "/bin/bash",
            backendScriptURL: scriptURL,
            language: "it",
            timeoutSeconds: 5
        )
        let text = try await service.transcribe(audioURL: URL(fileURLWithPath: "/tmp/audio.wav"))

        XCTAssertEqual(text, "ciao dal modello")
    }

    func testTranscribeReportsBackendStderrOnFailure() async throws {
        let scriptURL = try makeBackendScript(
            """
            #!/usr/bin/env bash
            echo "boom" >&2
            exit 7
            """
        )
        defer { try? FileManager.default.removeItem(at: scriptURL) }

        let service = CohereService(
            pythonPath: "/bin/bash",
            backendScriptURL: scriptURL,
            language: "it",
            timeoutSeconds: 5
        )

        do {
            _ = try await service.transcribe(audioURL: URL(fileURLWithPath: "/tmp/audio.wav"))
            XCTFail("Should have thrown")
        } catch let error as CohereError {
            XCTAssertEqual(error.errorDescription, "Cohere transcription failed: boom")
        }
    }

    func testCohereErrorDescriptions() {
        XCTAssertEqual(
            CohereError.backendNotFound("/a").errorDescription,
            "Cohere backend not found in WhisperNotes: /a"
        )
        XCTAssertEqual(
            CohereError.pythonNotFound("/python").errorDescription,
            "Python executable not found at: /python"
        )
        XCTAssertEqual(
            CohereError.processFailed("oops").errorDescription,
            "Cohere transcription failed: oops"
        )
    }

    private func makeBackendScript(_ script: String) throws -> URL {
        let scriptURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("fake-cohere-backend-\(UUID().uuidString)")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: scriptURL.path
        )
        return scriptURL
    }
}
