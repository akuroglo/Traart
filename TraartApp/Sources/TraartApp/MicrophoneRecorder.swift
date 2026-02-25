import AVFoundation

final class MicrophoneRecorder: NSObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder?
    private var durationTimer: Timer?
    private(set) var isRecording = false
    private(set) var duration: TimeInterval = 0

    var onDurationUpdate: ((TimeInterval) -> Void)?
    var onPermissionDenied: (() -> Void)?

    func startRecording() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.beginRecording()
                } else {
                    self?.onPermissionDenied?()
                }
            }
        }
    }

    func stopRecording() -> URL? {
        guard isRecording, let recorder = audioRecorder else { return nil }
        let url = recorder.url
        recorder.stop()
        cleanup()

        // Discard recordings shorter than 1 second
        if duration < 1.0 {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return url
    }

    func cancelRecording() {
        guard let recorder = audioRecorder else { return }
        let url = recorder.url
        recorder.stop()
        cleanup()
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Private

    private func beginRecording() {
        let timestamp = Int(Date().timeIntervalSince1970)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("traart-recording-\(timestamp).wav")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            recorder.record()
            audioRecorder = recorder
            isRecording = true
            duration = 0
            durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.duration += 1
                self.onDurationUpdate?(self.duration)
            }
        } catch {
            NSLog("Traart: MicrophoneRecorder failed to start: \(error.localizedDescription)")
        }
    }

    private func cleanup() {
        durationTimer?.invalidate()
        durationTimer = nil
        audioRecorder = nil
        isRecording = false
    }
}
