import AppKit
import Observation
import SwiftUI
import TenazCore

/// Exam Mode (PLAN F5): the runner in a full-screen panel above other apps (the overlay recipe
/// with typing on, no kiosk presentation options, so Force Quit and Cmd-Tab still work), with
/// - the clipboard change count polled at 2 Hz,
/// - a frontmost-app timeline: any other app is hidden (never terminated) and logged; a deny-listed
///   one becomes an `app` event for the verdict, others are `focusLoss` info,
/// - meeting signals (camera, microphone not held by Tenaz, a calendar *meeting* now: another
///   attendee or a call link, never a personal time block) pausing the exam and closing the panel
///   at once, nothing flagged; a call app coming to the front pauses it too, signal or not,
/// - Esc held 3 s → confirm → void; Ctrl-Opt-Cmd-Esc, the `killSwitch` default or the
///   DISABLE_OVERLAYS file appearing void and close,
/// - a watchdog of section time + 10 min, plus the panel's own hard cap.
@Observable
final class ExamModeController {
    private(set) var runner: ExamRunner?
    /// 0...1 while Esc is held.
    private(set) var escProgress = 0.0
    var confirmingLeave = false
    /// The learner said "I'm not in a call" after a microphone pause: ignore the mic for this attempt.
    var ignoreMicrophone = false
    /// The learner said "I'm free" over a calendar meeting: ignore the calendar for this attempt.
    /// The camera always stays a hard block.
    var ignoreCalendar = false
    /// The panel has not had the keyboard for a while (another window or app took it): the panel shows
    /// "Click here to type". Cleared as soon as the panel is key again.
    private(set) var keyboardLost = false
    @ObservationIgnored private var notKeyTicks = 0
    /// Esc was released after the leave confirmation appeared, so a fresh Esc press may close it.
    @ObservationIgnored private var escReleasedSinceConfirm = false

    @ObservationIgnored var onClose: (ExamModeExit) -> Void = { _ in }
    /// The runner of the last panel, kept after close so a paused exam can be resumed.
    @ObservationIgnored private(set) var lastRunner: ExamRunner?
    var lastKind: ExamKind? { lastRunner?.blueprint.kind }
    @ObservationIgnored private let presenter = OverlayPresenter()
    @ObservationIgnored private let probes = SignalProbes()
    @ObservationIgnored private var denyList = DenyList()
    @ObservationIgnored private var clipboard = ClipboardMonitor()
    @ObservationIgnored private var keyMonitor: Any?
    @ObservationIgnored private var activationObserver: NSObjectProtocol?
    @ObservationIgnored private var loops: [Task<Void, Never>] = []
    @ObservationIgnored private var watchdog: Task<Void, Never>?
    @ObservationIgnored private var escTask: Task<Void, Never>?
    @ObservationIgnored private var away: (label: String, since: Date, denied: Bool)?
    @ObservationIgnored private var killBaseline = (file: false, defaults: false)

    var isShowing: Bool { runner != nil }
    /// The typing panel while the exam is up (key-window checks in `exam-live`).
    var panel: NSPanel? { presenter.mainPanel }

    enum StartBlock: Equatable { case camera, calendar(String) }

    /// The camera on, or a calendar meeting now: the exam must not open over a meeting.
    /// `ignoringCalendar` is the learner's "I'm free, start anyway"; the camera can't be overridden.
    func startBlock(ignoringCalendar: Bool) -> StartBlock? {
        if SignalProbes.cameraRunning() == true { return .camera }
        if !ignoringCalendar, probes.calendarMeetingNow() == true { return .calendar(probes.calendarMeetingTitle() ?? "a meeting") }
        return nil
    }

    /// Shows the runner full screen. `hardCap` is the panel's own last-resort timer. The ignore
    /// flags belong to the attempt: a different runner starts with both off, then the arguments apply.
    func present(_ runner: ExamRunner, denyList: DenyList, hardCap: Duration,
                 ignoringCalendar: Bool = false, ignoringMicrophone: Bool = false) {
        let sameAttempt = runner === lastRunner
        close(nil)
        if !sameAttempt { ignoreMicrophone = false; ignoreCalendar = false }
        if ignoringCalendar { ignoreCalendar = true }
        if ignoringMicrophone { ignoreMicrophone = true }
        self.runner = runner
        self.denyList = denyList
        runner.onEvent = { [weak self] event in self?.handle(event) }
        presenter.onForcedClose = { [weak self] _ in self?.watchdogFired() }
        presenter.show(fullScreen: true, acceptsTyping: true, maxOnScreen: hardCap) {
            ExamModeRoot(controller: self, runner: runner)
        }
        killBaseline = (FileManager.default.fileExists(atPath: KillSwitch.disableFile.path),
                        UserDefaults.standard.bool(forKey: Self.killSwitchKey))
        // A microphone already held when the exam opens (a voice assistant, a dictation app) is not a
        // new call: only a mic that starts during the exam pauses it. Camera and calendar always do.
        if SignalProbes.microphoneRunning() == true { ignoreMicrophone = true }
        startMonitors()
        resetWatchdog(runner.phase == .task ? (runner.section?.timeLimit ?? .zero) + Self.grace : Self.introGrace)
    }

    /// The integrator's global kill switch (hotkey, defaults, file) calls this too.
    func killSwitch() {
        guard let runner else { return }
        runner.abort(reason: "kill switch")
        close(.voided("kill switch"))
    }

    func leave() {
        confirmingLeave = false
        runner?.abort(reason: "left with Esc")
    }

    // MARK: Events

    /// Extra time past a section's limit before the watchdog closes the panel.
    static let grace: Duration = .seconds(600)
    /// On a section intro the timer is stopped and a break is fine; the panel still closes after this.
    static let introGrace: Duration = .seconds(45 * 60)
    static let killSwitchKey = "killSwitch"

    private func handle(_ event: ExamRunnerEvent) {
        switch event {
        case let .sectionStarted(limit): resetWatchdog(limit + Self.grace)
        case .sectionEnded: resetWatchdog(Self.introGrace)
        case .pausedForLater: close(.pausedForLater)
        case let .finished(id): close(.finished(id))
        case let .voided(reason): close(.voided(reason))
        }
    }

    private func watchdogFired() {
        guard let runner else { return }
        runner.suspendForWatchdog()
        close(.watchdog)
    }

    private func meetingStarted() {
        guard let runner, runner.phase == .task || runner.phase == .intro else { return }
        runner.pauseForMeeting()
        close(.meeting)
    }

    private func close(_ exit: ExamModeExit?) {
        stopMonitors()
        presenter.close()
        escProgress = 0
        confirmingLeave = false
        escReleasedSinceConfirm = false
        let wasShowing = runner != nil
        runner?.stopAudio()
        if let runner { lastRunner = runner }
        runner = nil
        if wasShowing, let exit { onClose(exit) }
    }

    private func resetWatchdog(_ limit: Duration) {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            try? await Task.sleep(for: limit)
            guard !Task.isCancelled else { return }
            self?.watchdogFired()
        }
    }

    // MARK: Monitors

    private func startMonitors() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            self?.key(event) ?? event
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let id = app?.bundleIdentifier
            let name = app?.localizedName
            let pid = app?.processIdentifier
            MainActor.assumeIsolated { self?.activated(bundleId: id, name: name, pid: pid) }
        }
        loops = [
            repeating(every: .milliseconds(500)) { $0.pollClipboard() },
            repeating(every: .seconds(2)) { $0.pollMeeting() },
            repeating(every: .seconds(1)) { $0.pollKillSwitch() },
            repeating(every: .milliseconds(500)) { $0.pollKeyboard() },
        ]
    }

    private func stopMonitors() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        activationObserver = nil
        loops.forEach { $0.cancel() }
        loops = []
        watchdog?.cancel()
        watchdog = nil
        escTask?.cancel()
        escTask = nil
        away = nil
        keyboardLost = false
        notKeyTicks = 0
    }

    /// Keeps the answers on the keyboard: if the panel isn't key, ask for it back once, and after
    /// about a second without it show "Click here to type" (a click always keys the panel).
    private func pollKeyboard() {
        guard let panel = presenter.mainPanel, !confirmingLeave else { return }
        if panel.isKeyWindow {
            notKeyTicks = 0
            if keyboardLost { keyboardLost = false }
            return
        }
        notKeyTicks += 1
        if notKeyTicks == 1 { regainKeyboard() }
        if notKeyTicks >= 2, !keyboardLost { keyboardLost = true }
    }

    /// "Click here to type" and the keyboard guard: bring Tenaz and the panel back to the front.
    func regainKeyboard() {
        NSApp.activate()
        presenter.mainPanel?.makeKeyAndOrderFront(nil)
    }

    private func repeating(every interval: Duration, _ body: @escaping (ExamModeController) -> Void) -> Task<Void, Never> {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled, let self else { return }
                body(self)
            }
        }
    }

    private func pollClipboard() {
        guard let flag = clipboard.observe(changeCount: NSPasteboard.general.changeCount) else { return }
        runner?.logIntegrity(.clipboard, detail: "clipboard changed \(flag.changes)×")
    }

    /// Smokes and self-tests never read live meeting signals: they would inherit the terminal's
    /// Calendar and Microphone grants and behave unlike the learner's own launch.
    private var readsMeetingSignals: Bool { !LaunchArguments.current.isAutomation }

    private func pollMeeting() {
        guard let runner, readsMeetingSignals else { return }
        let mic = !runner.usingMicrophone && !ignoreMicrophone && SignalProbes.microphoneRunning() == true
        let calendar = !ignoreCalendar && probes.calendarMeetingNow() == true
        if SignalProbes.cameraRunning() == true || mic || calendar { meetingStarted() }
    }

    private func pollKillSwitch() {
        let file = FileManager.default.fileExists(atPath: KillSwitch.disableFile.path)
        let flag = UserDefaults.standard.bool(forKey: Self.killSwitchKey)
        if (file && !killBaseline.file) || (flag && !killBaseline.defaults) { killSwitch() }
    }

    /// Another app came to the front: hide it and come back; log how long it stayed.
    private func activated(bundleId: String?, name: String?, pid: pid_t?) {
        guard let runner else { return }
        let now = Date.now
        if bundleId == Bundle.main.bundleIdentifier {
            if let away {
                let ms = Int64(now.timeIntervalSince(away.since) * 1000)
                runner.logIntegrity(away.denied ? .app : .focusLoss, detail: away.label, durationMs: ms)
            }
            away = nil
            // Coming back (Cmd-Tab, the Dock icon, or after hiding another app) may key the main
            // window behind the panel; the answers must keep the keyboard.
            presenter.mainPanel?.makeKeyAndOrderFront(nil)
            return
        }
        guard !ExamAllowlist.isAllowed(bundleId) else { return }
        // A call app is never hidden: the learner may be answering a call before its mic or camera starts.
        // The exam pauses at once (the panel would cover the call window), noted with no verdict weight.
        if readsMeetingSignals, let bundleId, ExamAllowlist.callApps.contains(bundleId) {
            runner.logIntegrity(.focusLoss, detail: "paused for \(name ?? bundleId)")
            meetingStarted()
            return
        }
        let denied = denyList.match(bundleId: bundleId, domain: nil, url: nil, mode: .strict) != nil
        away = (name ?? bundleId ?? "Another app", now, denied)
        if let pid { NSRunningApplication(processIdentifier: pid)?.hide() }
        NSApp.activate()
    }

    /// Esc held 3 s asks to leave; Ctrl-Opt-Cmd-Esc is the kill switch. Esc closes the confirm.
    private func key(_ event: NSEvent) -> NSEvent? {
        let commandDown = event.modifierFlags.contains(.command)
        if confirmingLeave, event.keyCode != 53, !commandDown {
            // The leave card is modal: Return is its "Keep going", and no other key types into the
            // answer behind it. Command shortcuts still pass (never trap the learner).
            if event.type == .keyDown, event.keyCode == 36 || event.keyCode == 76 {
                confirmingLeave = false
                escReleasedSinceConfirm = false
            }
            return nil
        }
        guard event.keyCode == 53 else { return event }
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.type == .keyDown, mods.isSuperset(of: [.control, .option, .command]) {
            killSwitch()
            return nil
        }
        if confirmingLeave {
            // The Esc that opened the confirm is still held (key repeat): only a fresh press after
            // a release closes it.
            if event.type == .keyUp {
                escReleasedSinceConfirm = true
            } else if event.type == .keyDown, !event.isARepeat, escReleasedSinceConfirm {
                confirmingLeave = false
                escReleasedSinceConfirm = false
            }
            return nil
        }
        if event.type == .keyDown, !event.isARepeat, escTask == nil {
            let start = Date.now
            escTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(50))
                    guard let self, !Task.isCancelled else { return }
                    self.escProgress = min(1, Date.now.timeIntervalSince(start) / 3)
                    if self.escProgress >= 1 {
                        self.confirmingLeave = true
                        self.escReleasedSinceConfirm = false
                        self.escProgress = 0
                        self.escTask = nil
                        return
                    }
                }
            }
        } else if event.type == .keyUp {
            escTask?.cancel()
            escTask = nil
            escProgress = 0
        }
        return nil
    }
}
