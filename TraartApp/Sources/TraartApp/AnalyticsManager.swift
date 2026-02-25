import Foundation
import TelemetryDeck

final class AnalyticsManager {
    static let shared = AnalyticsManager()

    // MARK: - Distribution Channel

    enum DistributionChannel: String {
        case github
        case website
        case homebrew
        case unknown
    }

    private(set) var distributionChannel: DistributionChannel = .unknown

    // MARK: - Setup

    private init() {
        #if CHANNEL_GITHUB
        distributionChannel = .github
        #elseif CHANNEL_WEBSITE
        distributionChannel = .website
        #elseif CHANNEL_HOMEBREW
        distributionChannel = .homebrew
        #else
        distributionChannel = detectChannel()
        #endif
    }

    func configure() {
        guard SettingsManager.shared.analyticsEnabled else { return }

        let config = TelemetryDeck.Config(appID: "5693691E-9253-4BA5-BF96-B1E1DA7B032F")
        config.defaultParameters = { [weak self] in
            [
                "distributionChannel": self?.distributionChannel.rawValue ?? "unknown",
                "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                "buildNumber": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            ]
        }
        TelemetryDeck.initialize(config: config)
    }

    // MARK: - App Lifecycle Events

    func trackAppLaunched() {
        guard SettingsManager.shared.analyticsEnabled else { return }
        let processInfo = ProcessInfo.processInfo
        let osVersion = processInfo.operatingSystemVersion
        TelemetryDeck.signal("appLaunched", parameters: [
            "osVersion": "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)",
        ])
    }

    func trackAppTerminated() {
        guard SettingsManager.shared.analyticsEnabled else { return }
        TelemetryDeck.signal("appTerminated")
    }

    // MARK: - Setup / Onboarding Events

    func trackOnboardingCompleted() {
        guard SettingsManager.shared.analyticsEnabled else { return }
        TelemetryDeck.signal("onboardingCompleted")
    }

    func trackSetupStarted() {
        guard SettingsManager.shared.analyticsEnabled else { return }
        TelemetryDeck.signal("setupStarted")
    }

    func trackSetupCompleted(durationSeconds: Int) {
        guard SettingsManager.shared.analyticsEnabled else { return }
        TelemetryDeck.signal("setupCompleted", parameters: [
            "durationSeconds": String(durationSeconds),
        ])
    }

    func trackSetupFailed(error: String) {
        guard SettingsManager.shared.analyticsEnabled else { return }
        TelemetryDeck.signal("setupFailed", parameters: [
            "error": String(error.prefix(200)),
        ])
    }

    // MARK: - Transcription Events

    func trackTranscriptionStarted(diarizationEnabled: Bool, outputFormat: String, qualityPreset: String) {
        guard SettingsManager.shared.analyticsEnabled else { return }
        TelemetryDeck.signal("transcriptionStarted", parameters: [
            "diarizationEnabled": String(diarizationEnabled),
            "outputFormat": outputFormat,
            "qualityPreset": qualityPreset,
        ])
    }

    func trackTranscriptionCompleted(durationSeconds: Int, diarizationEnabled: Bool, speakersDetected: Int?) {
        guard SettingsManager.shared.analyticsEnabled else { return }
        var params: [String: String] = [
            "durationSeconds": String(durationSeconds),
            "diarizationEnabled": String(diarizationEnabled),
        ]
        if let speakers = speakersDetected {
            params["speakersDetected"] = String(speakers)
        }
        TelemetryDeck.signal("transcriptionCompleted", parameters: params)
    }

    func trackTranscriptionFailed(error: String) {
        guard SettingsManager.shared.analyticsEnabled else { return }
        TelemetryDeck.signal("transcriptionFailed", parameters: [
            "error": String(error.prefix(200)),
        ])
    }

    func trackTranscriptionCancelled() {
        guard SettingsManager.shared.analyticsEnabled else { return }
        TelemetryDeck.signal("transcriptionCancelled")
    }

    // MARK: - User Interaction Events

    func trackFileDropped() {
        guard SettingsManager.shared.analyticsEnabled else { return }
        TelemetryDeck.signal("fileDropped")
    }

    func trackFilePickerUsed() {
        guard SettingsManager.shared.analyticsEnabled else { return }
        TelemetryDeck.signal("filePickerUsed")
    }

    func trackAutoTranscribeTriggered() {
        guard SettingsManager.shared.analyticsEnabled else { return }
        TelemetryDeck.signal("autoTranscribeTriggered")
    }

    func trackSettingChanged(setting: String, value: String) {
        guard SettingsManager.shared.analyticsEnabled else { return }
        TelemetryDeck.signal("settingChanged", parameters: [
            "setting": setting,
            "value": value,
        ])
    }

    // MARK: - Channel Detection

    private func detectChannel() -> DistributionChannel {
        // Check for Homebrew receipt
        let homebrewCellar = "/opt/homebrew/Caskroom/traart"
        let homebrewCellarIntel = "/usr/local/Caskroom/traart"
        if FileManager.default.fileExists(atPath: homebrewCellar)
            || FileManager.default.fileExists(atPath: homebrewCellarIntel) {
            return .homebrew
        }
        return .unknown
    }
}
