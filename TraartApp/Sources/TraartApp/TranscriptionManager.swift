import Foundation

protocol TranscriptionManagerDelegate: AnyObject {
    func transcriptionManager(_ manager: TranscriptionManager, didStartJob job: TranscriptionJob)
    func transcriptionManager(_ manager: TranscriptionManager, didUpdateProgress job: TranscriptionJob)
    func transcriptionManager(_ manager: TranscriptionManager, didCompleteJob job: TranscriptionJob)
    func transcriptionManager(_ manager: TranscriptionManager, didFailJob job: TranscriptionJob)
}

final class TranscriptionManager {
    weak var delegate: TranscriptionManagerDelegate?

    private(set) var currentJob: TranscriptionJob?
    private(set) var queue: [TranscriptionJob] = []
    private(set) var completedJobs: [TranscriptionJob] = []

    private var currentProcess: Process?
    private let workQueue = DispatchQueue(label: "com.traart.transcription", qos: .userInitiated)
    private var isProcessing = false

    private static let maxCompletedJobs = 10

    func transcribe(file: URL, outputDir: URL?) {
        let settings = SettingsManager.shared

        let outputDirectory: URL
        if let dir = outputDir {
            outputDirectory = dir
        } else if !settings.saveNextToFile, let settingsDir = settings.outputFolder {
            outputDirectory = settingsDir
        } else {
            outputDirectory = file.deletingLastPathComponent()
        }

        let baseName = file.deletingPathExtension().lastPathComponent
        let ext = settings.outputFileExtension

        // Dual transcription: two files — with diarization and without
        if settings.dualTranscription && settings.enableDiarization && settings.qualityPreset == 4 {
            var jobPlain = TranscriptionJob(sourceFile: file)
            jobPlain.forceDiarization = false
            jobPlain.outputFile = outputDirectory.appendingPathComponent(baseName + ext)

            var jobDiarized = TranscriptionJob(sourceFile: file)
            jobDiarized.forceDiarization = true
            jobDiarized.outputFile = outputDirectory.appendingPathComponent(baseName + "_speakers" + ext)

            queue.append(jobPlain)
            queue.append(jobDiarized)
        } else {
            var job = TranscriptionJob(sourceFile: file)
            job.outputFile = outputDirectory.appendingPathComponent(baseName + ext)
            queue.append(job)
        }

        processQueue()
    }

    func cancelCurrentJob() {
        currentProcess?.terminate()
        currentProcess = nil

        if var job = currentJob {
            job.status = .cancelled
            job.endTime = Date()
            addToCompleted(job)
            currentJob = nil
        }

        isProcessing = false
        processQueue()
    }

    private func processQueue() {
        guard !isProcessing, !queue.isEmpty else { return }
        isProcessing = true

        var job = queue.removeFirst()
        job.status = .running
        job.startTime = Date()
        currentJob = job

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.transcriptionManager(self, didStartJob: job)
        }

        workQueue.async { [weak self] in
            self?.executeTranscription(job)
        }
    }

    private func executeTranscription(_ job: TranscriptionJob) {
        let settings = SettingsManager.shared
        let python = settings.pythonExecutable

        guard FileManager.default.fileExists(atPath: python.path) else {
            failJob(job, error: "Python окружение не найдено. Запустите установку.")
            return
        }

        guard let transcribeScript = EngineLocator.findScript("transcribe.py") else {
            failJob(job, error: "Скрипт транскрибации не найден.")
            return
        }

        guard let outputFile = job.outputFile else {
            failJob(job, error: "Не указан путь для результата.")
            return
        }

        // Ensure output directory exists
        let outputDir = outputFile.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        var arguments = [
            transcribeScript.path,
            job.sourceFile.path,
            outputFile.path
        ]

        // Per-job diarization override (for dual mode), or global setting
        let diarize = job.forceDiarization ?? settings.enableDiarization
        if diarize {
            arguments.append("--diarize")
            if settings.expectedSpeakers > 0 {
                arguments.append("--speakers")
                arguments.append(String(settings.expectedSpeakers))
            }
            // expectedSpeakers == 0 means auto-detect (no --speakers flag)
        }

        // Models directory (pre-downloaded by setup)
        arguments.append("--models-dir")
        arguments.append(settings.modelsDirectory.path)

        arguments.append("--format")
        arguments.append(settings.outputFormat)

        // Quality parameters
        arguments.append("--chunk-duration")
        arguments.append(String(settings.chunkDuration))
        arguments.append("--chunk-overlap")
        arguments.append(String(settings.chunkOverlap))
        arguments.append("--merge-gap")
        arguments.append(String(settings.mergeGap))
        arguments.append("--min-segment")
        arguments.append(String(settings.minSegmentDuration))
        arguments.append("--expansion-pad")
        arguments.append(String(settings.expansionPadding))

        let process = Process()
        process.executableURL = python
        process.arguments = arguments

        // Minimal sanitized environment — only what Python and ffmpeg need
        let currentEnv = ProcessInfo.processInfo.environment
        let extraPaths = "/opt/homebrew/bin:/usr/local/bin"
        let basePath = currentEnv["PATH"] ?? "/usr/bin:/bin"
        var env: [String: String] = [
            "PATH": "\(extraPaths):\(basePath)",
            "HOME": currentEnv["HOME"] ?? NSHomeDirectory(),
            "TMPDIR": currentEnv["TMPDIR"] ?? NSTemporaryDirectory(),
            "LANG": currentEnv["LANG"] ?? "en_US.UTF-8",
        ]
        // MPS (Metal) needs these for GPU access
        if let metalDevice = currentEnv["MTL_DEVICE"] { env["MTL_DEVICE"] = metalDevice }
        process.environment = env

        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe

        var stderrOutput = ""
        var stderrLineBuffer = ""

        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }
            stderrOutput += output

            // Buffer incomplete lines — pipe reads don't respect line boundaries
            stderrLineBuffer += output
            let lines = stderrLineBuffer.components(separatedBy: "\n")
            // Keep the last element as buffer (it's either empty or an incomplete line)
            stderrLineBuffer = lines.last ?? ""
            let completeLines = lines.dropLast().filter { !$0.isEmpty }
            if !completeLines.isEmpty {
                let linesToParse = completeLines.joined(separator: "\n")
                self?.parseProgressOutput(linesToParse, for: job)
            }
        }

        process.terminationHandler = { [weak self] proc in
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            stdoutPipe.fileHandleForReading.readabilityHandler = nil

            guard let self = self else { return }

            if proc.terminationStatus == 0 {
                self.completeJob(job)
            } else {
                // Save full stderr to transcription.log for debugging
                self.writeStderrToLog(stderrOutput, job: job, exitCode: proc.terminationStatus)

                // Extract last error from stderr
                var errorMsg = "Процесс завершился с кодом \(proc.terminationStatus)"
                let lines = stderrOutput.components(separatedBy: .newlines).filter { !$0.isEmpty }
                for line in lines.reversed() {
                    if let data = line.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let err = json["error"] as? String {
                        errorMsg = err
                        break
                    }
                    // Also check for plain text error lines
                    if line.contains("Error") || line.contains("error") || line.contains("Traceback") {
                        errorMsg = String(line.prefix(200))
                        break
                    }
                }
                self.failJob(job, error: errorMsg)
            }
        }

        do {
            currentProcess = process
            try process.run()
        } catch {
            failJob(job, error: "Не удалось запустить процесс: \(error.localizedDescription)")
        }
    }

    private func parseProgressOutput(_ output: String, for job: TranscriptionJob) {
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            // Parse warnings summary
            if let count = json["warnings_count"] as? Int {
                var updatedJob = currentJob ?? job
                updatedJob.warningsCount = count
                if let warnings = json["warnings"] as? [String] {
                    updatedJob.warnings = warnings
                }
                currentJob = updatedJob
                writeWarningsToLog(job: updatedJob)
                continue
            }

            // Parse individual warning (collect in current job)
            if let warning = json["warning"] as? String {
                var updatedJob = currentJob ?? job
                updatedJob.warnings.append(warning)
                updatedJob.warningsCount = updatedJob.warnings.count
                currentJob = updatedJob
                continue
            }

            // Parse progress
            guard let progress = json["progress"] as? Double else { continue }

            var updatedJob = currentJob ?? job
            updatedJob.progress = min(max(progress, 0.0), 1.0)

            if let stepStr = json["step"] as? String,
               let step = TranscriptionJob.TranscriptionStep(rawValue: stepStr) {
                updatedJob.step = step
            }

            updatedJob.etaSeconds = json["eta_seconds"] as? Double

            currentJob = updatedJob

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.transcriptionManager(self, didUpdateProgress: updatedJob)
            }
        }
    }

    private func writeStderrToLog(_ stderr: String, job: TranscriptionJob, exitCode: Int32) {
        let logFile = SettingsManager.shared.appSupportDirectory
            .appendingPathComponent("transcription.log")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())

        var entry = "\n=== [\(timestamp)] FAILED: \(job.sourceFileName) (exit \(exitCode)) ===\n"
        entry += stderr.suffix(3000) // last 3000 chars to avoid bloat
        entry += "\n=== END ===\n"

        if let data = entry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }

    private func writeWarningsToLog(job: TranscriptionJob) {
        guard !job.warnings.isEmpty else { return }
        let logFile = SettingsManager.shared.appSupportDirectory
            .appendingPathComponent("transcription.log")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())

        var logEntry = "\n[\(timestamp)] \(job.sourceFileName) — \(job.warningsCount) предупреждений\n"
        for (i, w) in job.warnings.enumerated() {
            logEntry += "  \(i + 1). \(w)\n"
        }

        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
        }

        // Trim log if > 500KB
        if let attrs = try? FileManager.default.attributesOfItem(atPath: logFile.path),
           let size = attrs[.size] as? Int, size > 500_000 {
            if let content = try? String(contentsOf: logFile, encoding: .utf8) {
                let lines = content.components(separatedBy: "\n")
                let trimmed = lines.suffix(500).joined(separator: "\n")
                try? trimmed.write(to: logFile, atomically: true, encoding: .utf8)
            }
        }
    }

    private func completeJob(_ job: TranscriptionJob) {
        // Guard: if this job was already cancelled/replaced, ignore the stale callback
        guard currentJob?.id == job.id else { return }

        var completed = job
        completed.status = .completed
        completed.progress = 1.0
        completed.endTime = Date()

        // Try to read the result file
        if let outputFile = completed.outputFile,
           let data = try? Data(contentsOf: outputFile) {
            let ext = outputFile.pathExtension.lowercased()
            if ext == "json",
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                completed.resultText = json["text"] as? String
                completed.speakersDetected = json["speakers_detected"] as? Int
            } else if let text = String(data: data, encoding: .utf8) {
                // For md/txt, store first 500 chars as preview
                completed.resultText = String(text.prefix(500))
            }
        }

        addToCompleted(completed)
        currentJob = nil
        currentProcess = nil
        isProcessing = false

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.transcriptionManager(self, didCompleteJob: completed)
        }

        processQueue()
    }

    private func failJob(_ job: TranscriptionJob, error: String) {
        // Guard: if this job was already cancelled/replaced, ignore the stale callback
        guard currentJob?.id == job.id else { return }

        var failed = job
        failed.status = .failed
        failed.error = error
        failed.endTime = Date()

        addToCompleted(failed)
        currentJob = nil
        currentProcess = nil
        isProcessing = false

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.transcriptionManager(self, didFailJob: failed)
        }

        processQueue()
    }

    private func addToCompleted(_ job: TranscriptionJob) {
        completedJobs.insert(job, at: 0)
        if completedJobs.count > Self.maxCompletedJobs {
            completedJobs = Array(completedJobs.prefix(Self.maxCompletedJobs))
        }
    }

}
