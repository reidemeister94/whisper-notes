import XCTest
@testable import WhisperNotesLib

final class WhisperServiceTests: XCTestCase {
    func testDefaultWhisperPathContainsWhisperCli() {
        let path = WhisperService.defaultWhisperPath
        XCTAssertTrue(path.contains("whisper-cli"))
        XCTAssertTrue(path.contains("whisper.cpp"))
    }

    func testDefaultModelPathContainsModel() {
        let path = WhisperService.defaultModelPath
        XCTAssertTrue(path.contains("ggml-large-v3-turbo.bin"))
    }

    func testDefaultLanguageIsAutoDetect() {
        let service = WhisperService(whisperPath: "/fake", modelPath: "/fake")
        XCTAssertEqual(service.language, "auto")
    }

    func testCustomLanguage() {
        var service = WhisperService(whisperPath: "/fake", modelPath: "/fake")
        service.language = "en"
        XCTAssertEqual(service.language, "en")
    }

    func testTranscribeThrowsCliNotFound() async {
        let service = WhisperService(
            whisperPath: "/nonexistent/whisper-cli",
            modelPath: "/nonexistent/model.bin"
        )
        do {
            _ = try await service.transcribe(audioURL: URL(fileURLWithPath: "/tmp/test.wav"))
            XCTFail("Should have thrown")
        } catch let error as WhisperError {
            if case .cliNotFound(let path) = error {
                XCTAssertEqual(path, "/nonexistent/whisper-cli")
            } else {
                XCTFail("Expected cliNotFound, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testTranscribeThrowsModelNotFound() async {
        let tempCli = NSTemporaryDirectory() + "fake-whisper-cli-\(UUID().uuidString)"
        FileManager.default.createFile(atPath: tempCli, contents: nil)
        defer { try? FileManager.default.removeItem(atPath: tempCli) }

        let service = WhisperService(
            whisperPath: tempCli,
            modelPath: "/nonexistent/model.bin"
        )
        do {
            _ = try await service.transcribe(audioURL: URL(fileURLWithPath: "/tmp/test.wav"))
            XCTFail("Should have thrown")
        } catch let error as WhisperError {
            if case .modelNotFound(let path) = error {
                XCTAssertEqual(path, "/nonexistent/model.bin")
            } else {
                XCTFail("Expected modelNotFound, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testWhisperErrorDescriptions() {
        XCTAssertEqual(
            WhisperError.cliNotFound("/a").errorDescription,
            "whisper-cli not found at: /a"
        )
        XCTAssertEqual(
            WhisperError.modelNotFound("/b").errorDescription,
            "Model not found at: /b"
        )
        XCTAssertEqual(
            WhisperError.processFailed("oops").errorDescription,
            "Transcription failed: oops"
        )
    }

    func testTimeoutDefaultIs300() {
        let service = WhisperService(whisperPath: "/fake", modelPath: "/fake")
        XCTAssertEqual(service.timeoutSeconds, 300)
    }
}
