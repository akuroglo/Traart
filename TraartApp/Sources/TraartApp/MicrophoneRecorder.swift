import AVFoundation

final class MicrophoneRecorder: NSObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder?
    private var durationTimer: DispatchSourceTimer?
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
        // Read currentTime from the recorder itself — `duration` is updated
        // via main.async and may lag behind when the main thread is busy.
        let finalDuration = recorder.currentTime
        recorder.stop()
        cleanup()

        // Discard recordings shorter than 1 second
        if finalDuration < 1.0 {
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

            // Background timer reading recorder.currentTime so the menu
            // counter doesn't stall when the main runloop is saturated
            // (e.g. by parallel transcription progress events).
            let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
            timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
            timer.setEventHandler { [weak self] in
                guard let self = self, let rec = self.audioRecorder else { return }
                let t = rec.currentTime
                DispatchQueue.main.async {
                    self.duration = t
                    self.onDurationUpdate?(t)
                }
            }
            timer.resume()
            durationTimer = timer
        } catch {
            NSLog("Traart: MicrophoneRecorder failed to start: \(error.localizedDescription)")
        }
    }

    private func cleanup() {
        durationTimer?.cancel()
        durationTimer = nil
        audioRecorder = nil
        isRecording = false
    }
}
