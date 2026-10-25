import AppKit
import Foundation
import Observation
import TenazCore

/// Settings state, stored in UserDefaults (never SQL). Enabling overlays or the gate obeys F14:
/// only with Calendar access or the "detection only" acknowledgement. Turning anything off always works.
@Observable
final class SettingsModel {
    enum Keys {
        static let claudeEnabled = "claudeEnabled"
        static let claudeModel = "claudeModel"
        static let soundEnabled = "soundEnabled"
        static let soundVolume = "soundVolume"
        static let calmCelebrations = "calmCelebrations"
    }

    private let defaults: UserDefaults
    var settings: IntrusionSettings {
        didSet {
            var s = settings
            if !canEnable {
                // Losing both Calendar and the acknowledgement switches everything off at once.
                s.overlaysEnabled = false
                s.gateEnabled = false
            }
            s.clamp()
            if s != settings { settings = s }
            if settings != oldValue { settings.save(to: defaults) }
        }
    }
    private(set) var calendarGranted: Bool
    var claudeEnabled: Bool { didSet { defaults.set(claudeEnabled, forKey: Keys.claudeEnabled) } }
    var claudeModel: String { didSet { defaults.set(claudeModel, forKey: Keys.claudeModel) } }
    var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: Keys.soundEnabled) } }
    var soundVolume: Int { didSet { defaults.set(soundVolume, forKey: Keys.soundVolume) } }
    var calmCelebrations: Bool { didSet { defaults.set(calmCelebrations, forKey: Keys.calmCelebrations) } }
    private(set) var claudeTest = ClaudeTestState.idle

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        settings = IntrusionSettings(defaults: defaults)
        calendarGranted = SignalProbes.calendarGranted
        claudeEnabled = defaults.object(forKey: Keys.claudeEnabled) as? Bool ?? true
        claudeModel = defaults.string(forKey: Keys.claudeModel) ?? "sonnet"
        soundEnabled = defaults.object(forKey: Keys.soundEnabled) as? Bool ?? true
        soundVolume = defaults.object(forKey: Keys.soundVolume) as? Int ?? 40
        calmCelebrations = defaults.bool(forKey: Keys.calmCelebrations)
    }

    var canEnable: Bool { IntrusionEnableRule.canEnable(calendarGranted: calendarGranted, acknowledged: settings.detectionOnlyAck) }
    var lockReason: String? { IntrusionEnableRule.lockReason(calendarGranted: calendarGranted, acknowledged: settings.detectionOnlyAck) }
    var anythingOn: Bool { settings.overlaysEnabled || settings.gateEnabled }

    func refresh() {
        calendarGranted = SignalProbes.calendarGranted
        settings = IntrusionSettings(defaults: defaults)
    }

    /// Shows the system Calendar prompt (only from this button, never automatically).
    func requestCalendar(probes: SignalProbes) async {
        calendarGranted = await probes.requestCalendarAccess()
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    /// One real Claude call through the CLI (claude.ai session, never an API key).
    func testClaude(_ cli: ClaudeCLI) async {
        claudeTest = .running
        var c = cli
        c.model = claudeModel
        guard c.isAvailable else {
            claudeTest = .failed("The claude command is not installed at \(c.executable.path).")
            return
        }
        let schema = #"{"type":"object","properties":{"ok":{"type":"boolean"}},"required":["ok"],"additionalProperties":false}"#
        let start = Date()
        do {
            let ping = try await c.structured(ClaudePing.self, prompt: "Reply with ok = true.", system: "You are a connection test. Answer only with the JSON.",
                                              schema: schema, timeout: .seconds(60))
            let secs = Date().timeIntervalSince(start)
            claudeTest = ping.ok ? .ok(String(format: "Connected with %@ in %.1f s.", claudeModel, secs)) : .failed("Claude answered, but not as expected.")
        } catch {
            claudeTest = .failed(String(describing: error).prefix(160).description)
        }
    }
}
