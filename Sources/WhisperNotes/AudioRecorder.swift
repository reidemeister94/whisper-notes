import AVFoundation
import Foundation

@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var permissionDenied = false

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var startTime: Date?

    var recordingURL: URL {
        let tmp = FileManager.default.temporaryDirectory
        return tmp.appendingPathComponent("whisper-note-recording.wav")
    }

    func startRecording() {
        // Check microphone permission first
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
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
        ]

        try? FileManager.default.removeItem(at: recordingURL)

        do {
            recorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            guard recorder?.record() == true else {
                print("AVAudioRecorder.record() returned false")
                return
            }
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
        } catch {
            print("Recording error: \(error)")
        }
    }

    func stopRecording() -> URL? {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
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
