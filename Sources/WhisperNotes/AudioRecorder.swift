@preconcurrency import AVFoundation
import Foundation

@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var permissionDenied = false

    /// Called on each audio buffer during recording (for real-time streaming).
    var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?

    private var engine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var timer: Timer?
    private var startTime: Date?

    var recordingURL: URL {
        let tmp = FileManager.default.temporaryDirectory
        return tmp.appendingPathComponent("whisper-note-recording.wav")
    }

    func startRecording() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            beginRecording()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                Task { @MainActor in
                    if granted {
                        self.beginRecording()
                    } else {
                        self.permissionDenied = true
                    }
                }
            }
        case .denied, .restricted:
            permissionDenied = true
        @unknown default:
            permissionDenied = true
        }
    }

    private func beginRecording() {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard let targetFormat = makeTargetFormat() else {
            print("Failed to create target audio format")
            return
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            print("Failed to create audio converter")
            return
        }

        try? FileManager.default.removeItem(at: recordingURL)

        do {
            audioFile = try makeAudioFile()
        } catch {
            print("Failed to create audio file: \(error)")
            return
        }

        installInputTap(
            on: inputNode,
            inputFormat: inputFormat,
            targetFormat: targetFormat,
            converter: converter
        )

        do {
            try engine.start()
        } catch {
            print("Audio engine start error: \(error)")
            return
        }

        self.engine = engine
        isRecording = true
        startTime = Date()
        elapsedTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard let start = self.startTime else { return }
                self.elapsedTime = Date().timeIntervalSince(start)
            }
        }
    }

    private func makeTargetFormat() -> AVAudioFormat? {
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )
    }

    private func makeAudioFile() throws -> AVAudioFile {
        try AVAudioFile(
            forWriting: recordingURL,
            settings: [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
            ],
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
    }

    private func installInputTap(
        on inputNode: AVAudioInputNode,
        inputFormat: AVAudioFormat,
        targetFormat: AVAudioFormat,
        converter: AVAudioConverter
    ) {
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self,
                  let convertedBuffer = Self.convertedBuffer(
                      from: buffer,
                      inputFormat: inputFormat,
                      targetFormat: targetFormat,
                      converter: converter
                  )
            else {
                return
            }

            try? audioFile?.write(from: convertedBuffer)
            onAudioBuffer?(convertedBuffer)
        }
    }

    private static func convertedBuffer(
        from buffer: AVAudioPCMBuffer,
        inputFormat: AVAudioFormat,
        targetFormat: AVAudioFormat,
        converter: AVAudioConverter
    ) -> AVAudioPCMBuffer? {
        let ratio = targetFormat.sampleRate / inputFormat.sampleRate
        let frameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: frameCapacity
        ) else {
            return nil
        }

        var didProvideInput = false
        var conversionError: NSError?
        let status = converter.convert(to: convertedBuffer, error: &conversionError) { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            didProvideInput = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, conversionError == nil, convertedBuffer.frameLength > 0 else {
            if let conversionError {
                print("Audio conversion error: \(conversionError)")
            }
            return nil
        }
        return convertedBuffer
    }

    func stopRecording() -> URL? {
        timer?.invalidate()
        timer = nil

        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        audioFile = nil

        isRecording = false

        let url = recordingURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    func formatTime(_ interval: TimeInterval) -> String {
        let mins = Int(interval) / 60
        let secs = Int(interval) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
