import AVFoundation
import Cvoxtral
import Foundation

enum VoxtralError: LocalizedError {
    case modelNotFound(String)
    case initFailed
    case streamInitFailed
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case let .modelNotFound(p): "Voxtral model not found at: \(p)"
        case .initFailed: "Failed to initialize Voxtral engine"
        case .streamInitFailed: "Failed to initialize Voxtral streaming context"
        case let .transcriptionFailed(msg): "Transcription failed: \(msg)"
        }
    }
}

/// Wraps voxtral.c streaming API for real-time and batch transcription.
/// Model loading is expensive (~5s for 8.3GB) — call `loadModel()` once at app start,
/// not per-recording. Streaming and batch operations reuse the loaded context.
final class VoxtralService: @unchecked Sendable {
    private var ctx: UnsafeMutablePointer<vox_ctx_t>?
    let modelDir: String
    let delayMs: Int
    private(set) var isModelLoaded = false

    init(modelDir: String, delayMs: Int = 480) {
        self.modelDir = modelDir
        self.delayMs = delayMs
    }

    deinit {
        if let ctx {
            vox_free(ctx)
        }
    }

    /// Load the model (blocking, ~5s for 8.3GB). Call on a background thread.
    func loadModel() throws {
        guard FileManager.default.fileExists(atPath: modelDir) else {
            throw VoxtralError.modelNotFound(modelDir)
        }
        guard let c = vox_load(modelDir) else {
            throw VoxtralError.initFailed
        }
        vox_set_delay(c, Int32(delayMs))
        ctx = c
        isModelLoaded = true
    }

    // MARK: - Streaming

    /// Start real-time streaming transcription.
    /// Returns an AsyncStream that yields text tokens as they're decoded.
    func startStreaming() throws -> AsyncStream<String> {
        guard let ctx else { throw VoxtralError.initFailed }
        guard let stream = vox_stream_init(ctx) else {
            throw VoxtralError.streamInitFailed
        }

        vox_stream_set_continuous(stream, 1)
        // Lower interval = faster first response (default 2.0s is too laggy)
        vox_set_processing_interval(stream, 0.5)

        self.stream = stream
        isStreaming = true
        accumulatedText = ""

        return AsyncStream { [weak self] continuation in
            self?.streamContinuation = continuation

            continuation.onTermination = { @Sendable _ in }

            self?.startTokenPolling(stream: stream, continuation: continuation)
        }
    }

    /// Feed PCM audio samples from the audio engine tap.
    func feedAudio(_ buffer: AVAudioPCMBuffer) {
        guard let stream, isStreaming,
              let channelData = buffer.floatChannelData
        else { return }

        let frameCount = Int(buffer.frameLength)
        let samples = channelData[0]
        vox_stream_feed(stream, samples, Int32(frameCount))
    }

    /// Signal end of audio and flush remaining tokens. BLOCKING — call off main thread.
    func stopStreaming() -> String {
        guard let stream, isStreaming else { return accumulatedText }
        isStreaming = false

        vox_stream_finish(stream)
        drainTokens(stream: stream)

        let result = accumulatedText
        streamContinuation?.finish()
        streamContinuation = nil

        vox_stream_free(stream)
        self.stream = nil
        accumulatedText = ""

        return result
    }

    // MARK: - Batch transcription (offline, on saved file)

    /// Transcribe a WAV file. BLOCKING — call off main thread.
    func transcribeFile(_ url: URL) throws -> String {
        guard let ctx else { throw VoxtralError.initFailed }

        guard let result = vox_transcribe(ctx, url.path) else {
            throw VoxtralError.transcriptionFailed("vox_transcribe returned nil")
        }

        let text = String(cString: result)
        free(result)
        return text
    }

    // MARK: - Private

    private var stream: OpaquePointer?
    private var isStreaming = false
    private var streamContinuation: AsyncStream<String>.Continuation?
    private(set) var accumulatedText = ""
    private var pollingTask: Task<Void, Never>?

    private func startTokenPolling(stream: OpaquePointer, continuation: AsyncStream<String>.Continuation) {
        pollingTask = Task.detached { [weak self] in
            var tokenPtrs = [UnsafePointer<CChar>?](repeating: nil, count: 16)

            while self?.isStreaming == true {
                let count = tokenPtrs.withUnsafeMutableBufferPointer { buf in
                    vox_stream_get(stream, buf.baseAddress, 16)
                }

                if count > 0 {
                    for i in 0 ..< Int(count) {
                        if let ptr = tokenPtrs[Int(i)] {
                            let token = String(cString: ptr)
                            self?.accumulatedText.append(token)
                            continuation.yield(token)
                        }
                    }
                }

                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
        }
    }

    private func drainTokens(stream: OpaquePointer) {
        var tokenPtrs = [UnsafePointer<CChar>?](repeating: nil, count: 16)
        while true {
            let count = tokenPtrs.withUnsafeMutableBufferPointer { buf in
                vox_stream_get(stream, buf.baseAddress, 16)
            }
            if count <= 0 { break }
            for i in 0 ..< Int(count) {
                if let ptr = tokenPtrs[Int(i)] {
                    let token = String(cString: ptr)
                    accumulatedText.append(token)
                    streamContinuation?.yield(token)
                }
            }
        }
    }
}
