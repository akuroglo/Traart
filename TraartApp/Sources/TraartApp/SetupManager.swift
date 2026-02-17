import Foundation

final class SetupManager {
    private(set) var isSettingUp: Bool = false
    private(set) var setupProgress: Double = 0.0
    private(set) var setupStatus: String = ""
    private var process: Process?

    var onProgressUpdate: ((Double, String) -> Void)?

    // MARK: - Standalone Python config

    private static let pythonRelease = "20260211"
    private static let pythonVersion = "3.12.12"

    private static let pythonArm64URL =
        "https://github.com/astral-sh/python-build-standalone/releases/download/\(pythonRelease)/cpython-\(pythonVersion)+\(pythonRelease)-aarch64-apple-darwin-install_only_stripped.tar.gz"
    private static let pythonX86URL =
        "https://github.com/astral-sh/python-build-standalone/releases/download/\(pythonRelease)/cpython-\(pythonVersion)+\(pythonRelease)-x86_64-apple-darwin-install_only_stripped.tar.gz"

    private static let pythonArm64SHA256 = "22625deaf5757e7c266cf1a096c9151a06b598b1e14632a2ec9993d58ec5fe84"
    private static let pythonX86SHA256 = "a84ac7a36d465bc6eb68db84540fdb5da04333900e2c3cb34b5d454f2022048c"

    private static var standalonePythonDir: URL {
        SettingsManager.shared.appSupportDirectory.appendingPathComponent("python-standalone")
    }

    private static var standalonePython: URL {
        standalonePythonDir.appendingPathComponent("bin/python3")
    }

    // MARK: - Needs setup check

    static var needsSetup: Bool {
        let pythonBin = SettingsManager.shared.pythonExecutable
        guard FileManager.default.fileExists(atPath: pythonBin.path) else { return true }

        // Check that torch is actually importable
        let process = Process()
        process.executableURL = pythonBin
        process.arguments = ["-c", "import torch; import gigaam"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus != 0
        } catch {
            return true
        }
    }

    // MARK: - Setup

    func startSetup(completion: @escaping (Bool) -> Void) {
        guard !isSettingUp else { return }
        isSettingUp = true
        setupProgress = 0.0
        setupStatus = "Начало установки..."

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Log file — created early so Python download phase is also logged
            let logDir = SettingsManager.shared.appSupportDirectory
            try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
            let logFile = logDir.appendingPathComponent("setup.log")
            FileManager.default.createFile(atPath: logFile.path, contents: nil)
            let logHandle = try? FileHandle(forWritingTo: logFile)

            func writeLog(_ msg: String) {
                logHandle?.write(Data((msg + "\n").utf8))
            }
            writeLog("=== Setup started: \(Date()) ===")

            guard let scriptPath = EngineLocator.findScript("setup_env.py") else {
                writeLog("ERROR: setup_env.py not found")
                self.updateProgress(0.0, status: "Ошибка: скрипт установки не найден")
                self.isSettingUp = false
                logHandle?.closeFile()
                DispatchQueue.main.async { completion(false) }
                return
            }
            writeLog("Script: \(scriptPath.path)")

            // Ensure we have a suitable Python (download standalone if needed)
            self.updateProgress(0.01, status: "Поиск Python...")
            writeLog("Looking for Python 3.10+...")
            guard let pythonPath = self.ensurePython() else {
                writeLog("ERROR: Could not find or download Python")
                self.updateProgress(0.0, status: "Не удалось получить Python. Проверьте подключение к интернету.")
                self.isSettingUp = false
                logHandle?.closeFile()
                DispatchQueue.main.async { completion(false) }
                return
            }
            writeLog("Python: \(pythonPath)")

            let process = Process()
            self.process = process

            process.executableURL = URL(fileURLWithPath: pythonPath)
            process.arguments = [scriptPath.path, "--python", pythonPath]

            // Minimal PATH — system tools + Homebrew if available
            var env = ProcessInfo.processInfo.environment
            let brewPaths = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin"
            env["PATH"] = brewPaths + ":/usr/bin:/bin:/usr/sbin:/sbin"
            process.environment = env
            writeLog("PATH: \(env["PATH"] ?? "nil")")

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            let handle = pipe.fileHandleForReading
            handle.readabilityHandler = { [weak self] fileHandle in
                let data = fileHandle.availableData
                guard !data.isEmpty, let line = String(data: data, encoding: .utf8) else { return }
                writeLog("OUT: \(line.trimmingCharacters(in: .whitespacesAndNewlines))")
                self?.parseSetupOutput(line)
            }

            process.terminationHandler = { [weak self] proc in
                handle.readabilityHandler = nil
                self?.isSettingUp = false
                let success = proc.terminationStatus == 0
                writeLog("=== Exit code: \(proc.terminationStatus) ===")
                logHandle?.closeFile()
                if success {
                    self?.updateProgress(1.0, status: "Установка завершена")
                } else {
                    self?.updateProgress(self?.setupProgress ?? 0.0, status: "Ошибка установки (код: \(proc.terminationStatus))")
                }
                DispatchQueue.main.async { completion(success) }
            }

            do {
                try process.run()
            } catch {
                self.isSettingUp = false
                self.updateProgress(0.0, status: "Ошибка запуска: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(false) }
            }
        }
    }

    // MARK: - Python resolution

    /// Ensure a suitable Python 3.10+ is available.
    /// Priority: standalone (already downloaded) → Homebrew → download standalone.
    private func ensurePython() -> String? {
        // 1. Standalone already downloaded?
        let standalone = Self.standalonePython
        if FileManager.default.isExecutableFile(atPath: standalone.path) {
            return standalone.path
        }

        // 2. Homebrew / system Python 3.10+?
        if let found = Self.findSystemPython() {
            return found
        }

        // 3. Download standalone Python
        updateProgress(0.01, status: "Скачивание Python \(Self.pythonVersion)...")
        if downloadStandalonePython() {
            if FileManager.default.isExecutableFile(atPath: standalone.path) {
                return standalone.path
            }
        }

        return nil
    }

    /// Find Python 3.10+ from Homebrew or system paths. Returns nil if not found.
    private static func findSystemPython() -> String? {
        let candidates = [
            "/opt/homebrew/bin/python3.13",
            "/opt/homebrew/bin/python3.12",
            "/opt/homebrew/bin/python3.11",
            "/opt/homebrew/bin/python3.10",
            "/usr/local/bin/python3.13",
            "/usr/local/bin/python3.12",
            "/usr/local/bin/python3.11",
            "/usr/local/bin/python3.10",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    // MARK: - Standalone Python download

    /// Download and extract standalone Python. Returns true on success.
    private func downloadStandalonePython() -> Bool {
        let isArm64 = ProcessInfo.processInfo.machineHardwareName == "arm64"
        let urlString = isArm64 ? Self.pythonArm64URL : Self.pythonX86URL
        let expectedHash = isArm64 ? Self.pythonArm64SHA256 : Self.pythonX86SHA256

        guard let url = URL(string: urlString) else { return false }

        let appSupport = SettingsManager.shared.appSupportDirectory
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        let archivePath = appSupport.appendingPathComponent("python-standalone.tar.gz")

        // Download
        let semaphore = DispatchSemaphore(value: 0)
        var downloadError: Error?

        let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            defer { semaphore.signal() }

            if let error = error {
                downloadError = error
                return
            }
            guard let tempURL = tempURL else {
                downloadError = NSError(domain: "Traart", code: 1, userInfo: [NSLocalizedDescriptionKey: "No download data"])
                return
            }

            do {
                // Move to final location
                if FileManager.default.fileExists(atPath: archivePath.path) {
                    try FileManager.default.removeItem(at: archivePath)
                }
                try FileManager.default.moveItem(at: tempURL, to: archivePath)
            } catch {
                downloadError = error
            }
        }

        // Observe download progress
        let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            let pct = progress.fractionCompleted
            self?.updateProgress(0.01 + pct * 0.03, status: "Скачивание Python... \(Int(pct * 100))%")
        }

        task.resume()
        semaphore.wait()
        observation.invalidate()

        if downloadError != nil {
            try? FileManager.default.removeItem(at: archivePath)
            return false
        }

        // Verify SHA-256
        updateProgress(0.04, status: "Проверка контрольной суммы...")
        guard verifySHA256(file: archivePath, expected: expectedHash) else {
            try? FileManager.default.removeItem(at: archivePath)
            updateProgress(0.0, status: "Ошибка: контрольная сумма Python не совпадает")
            return false
        }

        // Extract: tar xzf → produces "python/" directory
        updateProgress(0.045, status: "Распаковка Python...")
        let extractDir = Self.standalonePythonDir
        // Clean up old installation if present
        if FileManager.default.fileExists(atPath: extractDir.path) {
            try? FileManager.default.removeItem(at: extractDir)
        }

        let tarProcess = Process()
        tarProcess.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        tarProcess.arguments = ["xzf", archivePath.path, "-C", appSupport.path]
        tarProcess.standardOutput = FileHandle.nullDevice
        tarProcess.standardError = FileHandle.nullDevice

        do {
            try tarProcess.run()
            tarProcess.waitUntilExit()
            guard tarProcess.terminationStatus == 0 else {
                try? FileManager.default.removeItem(at: archivePath)
                return false
            }
        } catch {
            try? FileManager.default.removeItem(at: archivePath)
            return false
        }

        // tar extracts to "python/" — rename to "python-standalone/"
        let extractedDir = appSupport.appendingPathComponent("python")
        if FileManager.default.fileExists(atPath: extractedDir.path) {
            do {
                try FileManager.default.moveItem(at: extractedDir, to: extractDir)
            } catch {
                // If python-standalone already exists somehow, remove and retry
                try? FileManager.default.removeItem(at: extractDir)
                try? FileManager.default.moveItem(at: extractedDir, to: extractDir)
            }
        }

        // Remove quarantine attributes (macOS Gatekeeper)
        updateProgress(0.048, status: "Снятие карантина...")
        let xattrProcess = Process()
        xattrProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        xattrProcess.arguments = ["-cr", extractDir.path]
        xattrProcess.standardOutput = FileHandle.nullDevice
        xattrProcess.standardError = FileHandle.nullDevice
        try? xattrProcess.run()
        xattrProcess.waitUntilExit()

        // Cleanup archive
        try? FileManager.default.removeItem(at: archivePath)

        updateProgress(0.05, status: "Python \(Self.pythonVersion) готов")
        return true
    }

    /// Verify SHA-256 hash of a file.
    private func verifySHA256(file: URL, expected: String) -> Bool {
        // Use /usr/bin/shasum (always available on macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shasum")
        process.arguments = ["-a", "256", file.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return false }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return false }

            // Output format: "hash  filename\n"
            let hash = output.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: " ").first ?? ""
            return hash == expected
        } catch {
            return false
        }
    }

    // MARK: - Cancel

    func cancelSetup() {
        process?.terminate()
        process = nil
        isSettingUp = false
    }

    // MARK: - Progress parsing

    /// Progress floor — setup_env.py progress is scaled to [floor..1.0]
    /// so it never overwrites the Python download phase (0.0–0.05).
    private static let setupScriptProgressFloor: Double = 0.05

    private func parseSetupOutput(_ output: String) {
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                // Not JSON, treat as status message
                updateProgress(setupProgress, status: line.trimmingCharacters(in: .whitespaces))
                continue
            }

            let rawProgress = json["progress"] as? Double ?? 0.0
            let status = json["status"] as? String ?? setupStatus
            // Scale setup_env.py progress (0.0–1.0) into (0.05–1.0) range
            let floor = Self.setupScriptProgressFloor
            let scaledProgress = floor + rawProgress * (1.0 - floor)
            updateProgress(scaledProgress, status: status)
        }
    }

    private func updateProgress(_ progress: Double, status: String) {
        // Never let progress go backwards (except for errors at 0.0)
        let effectiveProgress = progress > 0 ? max(progress, self.setupProgress) : progress
        self.setupProgress = effectiveProgress
        self.setupStatus = status
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onProgressUpdate?(self.setupProgress, self.setupStatus)
        }
    }
}

// MARK: - ProcessInfo extension for architecture detection

private extension ProcessInfo {
    var machineHardwareName: String {
        var sysinfo = utsname()
        uname(&sysinfo)
        return withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "unknown"
            }
        }
    }
}
