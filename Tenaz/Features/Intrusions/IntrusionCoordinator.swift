import AppKit
import Observation
import SwiftUI
import TenazCore

/// Owns every intrusive surface (PLAN §4.5). Each trigger goes through one pipeline:
/// kill switch → pause / meeting / snooze / quiet hours → `InterruptionPolicy(SignalProbes.read())`
/// → caps → show → log to `intrusion_log`. While a surface is on screen it re-reads the signals every
/// second and closes it for free on any meeting signal or kill switch. Everything ships OFF.
@MainActor
@Observable
final class IntrusionCoordinator {
    static let snoozeMinutes = 5.0
    static let notNowMinutes = 15.0
    static let meetingMinutes = 60.0
    static let snoozesPerDay = 3
    static let snoozedUntilKey = "intrusionsSnoozedUntil"
    static let lastUnlockKey = "lastUnlockAt"
    /// The gate prompt shown but not yet completed or skipped: the next gate shows it again.
    static let pendingGateKey = "gatePendingPromptId"

    let env: AppEnvironment
    let probes = SignalProbes()
    let killSwitch = KillSwitch()
    let store: IntrusionStore?
    private(set) var killState = KillSwitch.read()
    private(set) var visible: VisibleSurface?
    /// "allow", "defer: camera in use", ... for the Safety page.
    private(set) var lastDecision = "nothing yet"
    var settings = IntrusionSettings(defaults: .standard)

    @ObservationIgnored private let presenter = OverlayPresenter()
    @ObservationIgnored private let toastPresenter = OverlayPresenter()
    @ObservationIgnored private var tracker = ActivityTracker()
    @ObservationIgnored private var watchTask: Task<Void, Never>?
    @ObservationIgnored private var pendingTask: Task<Void, Never>?
    @ObservationIgnored private var unlockTask: Task<Void, Never>?
    @ObservationIgnored private var idleTimer: Timer?
    @ObservationIgnored private var keyMonitor: Any?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var lockedSince: Date?
    @ObservationIgnored private var smokeName: String?
    @ObservationIgnored private var started = false

    init(env: AppEnvironment) {
        self.env = env
        store = env.database.map(IntrusionStore.init(database:))
        killSwitch.onChange = { [weak self] in self?.killState = $0 }
        killSwitch.onEngage = { [weak self] reason in self?.killSwitchFired(reason) }
    }

    // MARK: Lifecycle

    /// Starts the kill switches and the triggers. Never in automation (snapshots, smokes, self-tests).
    func start() {
        guard !started, !LaunchArguments.current.isAutomation else { return }
        started = true
        killSwitch.start()
        let ws = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.unlockSignal() }
            })
        }
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.lockSignal() }
            })
        }
        observers.append(ws.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let id = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            MainActor.assumeIsolated { self?.appActivated(id) }
        })
        let distributed = DistributedNotificationCenter.default()
        observers.append(distributed.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.unlockSignal() }
        })
        observers.append(distributed.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.lockSignal() }
        })
        idleTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.idleTick() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.closeEverything(.killed, reason: "app quit") }
        }
    }

    // MARK: Triggers

    private func lockSignal() {
        if lockedSince == nil { lockedSince = Date() }
        // Never leave anything on screen behind a locked Mac.
        if visible != nil { finish(.deferredMidway, reason: "screen locked") }
    }

    /// Unlock, wake and the distributed unlock note arrive together: merge and debounce 1.5 s.
    private func unlockSignal() {
        unlockTask?.cancel()
        unlockTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.unlocked()
        }
    }

    private func unlocked() {
        guard !Self.screenLocked() else { return }
        let now = Date()
        let defaults = UserDefaults.standard
        let lastUnlock = IntrusionSettings.date(defaults, Self.lastUnlockKey)
        let qualifies = GateEligibility.qualifies(lockedSince: lockedSince, now: now, lastUnlock: lastUnlock)
        lockedSince = nil
        defaults.set(now.timeIntervalSince1970, forKey: Self.lastUnlockKey)
        settings = IntrusionSettings(defaults: defaults)
        if qualifies, settings.gateEnabled {
            request(.gate, trigger: .unlock)
        } else {
            request(.overlay, trigger: .unlock)
        }
    }

    private func appActivated(_ bundleId: String?) {
        if case let .gate(model, _, _) = visible, model.typedAny, bundleId != Bundle.main.bundleIdentifier {
            model.leftAfterTyping = true
        }
        // Exam Mode hides every other app it sees, which would read as app switches.
        guard !examInProgress else { return }
        if tracker.activated(bundleId, at: Date()) == .appSwitch { request(.overlay, trigger: .appSwitch) }
    }

    /// Nothing appears over a running Exam Mode attempt (same level, its own Esc monitor).
    private var examInProgress: Bool { ExamCenter.shared.isExamModeShowing }

    private func idleTick() {
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
        if tracker.idle(seconds: idle) == .idleReturn { request(.overlay, trigger: .idleReturn) }
    }

    static func screenLocked() -> Bool {
        guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (dict["CGSSessionScreenIsLocked"] as? Bool) ?? false
    }

    // MARK: Decision pipeline

    func makeRequest(_ surface: IntrusionSurface, trigger: IntrusionTrigger, now: Date = Date()) -> IntrusionRequest {
        let d = UserDefaults.standard
        settings = IntrusionSettings(defaults: d)
        killState = KillSwitch.read(d)
        return IntrusionRequest(
            surface: surface, trigger: trigger, now: now, settings: settings, killSwitch: killState,
            calendarGranted: SignalProbes.calendarGranted,
            pausedUntil: IntrusionSettings.date(d, IntrusionSettings.Keys.pausedUntil),
            meetingUntil: IntrusionSettings.date(d, IntrusionSettings.Keys.meetingUntil),
            snoozedUntil: IntrusionSettings.date(d, Self.snoozedUntilKey),
            signals: probes.read(), callOrChatFrontmost: SignalProbes.callOrChatFrontmost,
            history: (try? store?.history(surface, now: now)) ?? IntrusionHistory())
    }

    /// One trigger, start to finish.
    func request(_ surface: IntrusionSurface, trigger: IntrusionTrigger) {
        guard visible == nil, pendingTask == nil else { return }
        let r = makeRequest(surface, trigger: trigger)
        let verdict = IntrusionDecider.decide(r)
        lastDecision = "\(verdict.decision)\(verdict.reason.map { ": \($0)" } ?? "")"
        guard case let .show(mode) = verdict else {
            // "is off" is the normal state; logging it on every app switch would only add noise.
            if case let .deny(reason) = verdict, reason.hasSuffix("is off") { return }
            log(surface, trigger: trigger, verdict: verdict, outcome: .deferred, mode: nil)
            return
        }
        if examInProgress {
            log(surface, trigger: trigger, verdict: .deferred("exam in progress"), outcome: .deferred, mode: nil)
            return
        }
        switch surface {
        case .gate: showGate(trigger: trigger)
        case .overlay: preannounce(mode: mode, trigger: trigger)
        }
    }

    /// 20 s warning (toast), then wait for a 2 s pause in typing, then re-check and show (F1, R5).
    private func preannounce(mode: OverlayMode, trigger: IntrusionTrigger) {
        let deadline = Date().addingTimeInterval(20)
        toastPresenter.onForcedClose = nil
        toastPresenter.show(.toast, maxOnScreen: SurfaceWatchdog.preannounce + .seconds(1)) {
            PreannounceToast(deadline: deadline) { [weak self] in self?.notNow(trigger: trigger) }
        }
        pendingTask = Task { [weak self] in
            try? await Task.sleep(for: SurfaceWatchdog.preannounce)
            guard !Task.isCancelled else { return }
            self?.toastPresenter.close()
            // Wait for the learner to stop typing (up to the trigger's 5-minute validity).
            for _ in 0..<600 {
                let sinceKey = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
                if EarlyInputGuard.canShow(secondsSinceLastKey: sinceKey) { break }
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
            }
            guard let self, !Task.isCancelled else { return }
            self.pendingTask = nil
            if self.examInProgress {
                self.log(.overlay, trigger: trigger, verdict: .deferred("exam in progress"), outcome: .deferred, mode: nil)
                return
            }
            let again = IntrusionDecider.decide(self.makeRequest(.overlay, trigger: trigger))
            guard case let .show(finalMode) = again else {
                self.log(.overlay, trigger: trigger, verdict: again, outcome: .deferred, mode: nil)
                return
            }
            self.showOverlay(mode: mode == .sticker || finalMode == .sticker ? .sticker : .poster, trigger: trigger)
        }
    }

    private func notNow(trigger: IntrusionTrigger) {
        pendingTask?.cancel()
        pendingTask = nil
        toastPresenter.close()
        UserDefaults.standard.set(Date().addingTimeInterval(Self.notNowMinutes * 60).timeIntervalSince1970, forKey: Self.snoozedUntilKey)
        try? store?.logHatch(.notNow, at: Date())
        log(.overlay, trigger: trigger, verdict: .deny("not now"), outcome: .snoozed, mode: nil)
    }

    // MARK: Showing

    private var responseCostOn: Bool {
        guard let g = env.gamification else { return false }
        return (try? g.contract().isActive(.responseCost, at: Int64(Date().timeIntervalSince1970 * 1000))) ?? false
    }

    private var stage: TenaStage {
        (try? env.gamification?.state().mascot.stage).flatMap { TenaStage(rawValue: $0) } ?? .juvenile
    }

    func overlayBatch(now: Date = Date()) -> [SessionItem] {
        guard let session = try? env.reviewStore?.startSession(book: PromptBook(vocab: env.content.vocab), surface: .overlay, now: now)
        else { return [] }
        return OverlayBatch.pick(session.queue)
    }

    func makeOverlayModel(items: [SessionItem], mode: OverlayMode, now: Date = Date()) -> OverlayModel {
        let snoozes = (try? store?.hatchCount(.snooze, day: DayBoundary.day(for: now))) ?? 0
        return OverlayModel(items: items, mode: mode, reviewStore: env.reviewStore, gamification: env.gamification,
                            skipCost: responseCostOn ? 3 : 0, snoozesLeft: max(0, Self.snoozesPerDay - snoozes), shownAt: now)
    }

    private func showOverlay(mode: OverlayMode, trigger: IntrusionTrigger, items override: [SessionItem]? = nil) {
        let items = override ?? overlayBatch()
        guard !items.isEmpty else {
            log(.overlay, trigger: trigger, verdict: .deferred("nothing due"), outcome: .deferred, mode: mode)
            return
        }
        let now = Date()
        let model = makeOverlayModel(items: items, mode: mode, now: now)
        model.onFinish = { [weak self] outcome in self?.finish(outcome) }
        visible = .overlay(model, trigger: trigger, shownAt: now)
        let deadline = now.addingTimeInterval(smokeName == nil ? 90 : 2.2)
        let stage = self.stage
        presenter.onForcedClose = { [weak self] _ in self?.finish(.timeout, reason: "watchdog") }
        let limit = smokeName == nil ? SurfaceWatchdog.overlay : SurfaceWatchdog.smoke
        presenter.show(mode == .poster ? .poster : .sticker, maxOnScreen: limit) {
            Group {
                if mode == .poster {
                    WordOverlayView(model: model, deadline: deadline, stage: stage)
                } else {
                    WordStickerView(model: model, deadline: deadline)
                }
            }
            .environment(env)
        }
        log(.overlay, trigger: trigger, verdict: .show(mode), outcome: .shown, mode: mode)
        afterShow()
    }

    func makeGateModel(now: Date = Date()) -> GateModel {
        let forgotten = (try? store?.forgottenWords(now: now)) ?? []
        let history = (try? env.database.map { try ExposureStore(database: $0).all() }) ?? []
        var rng = SeededRandom(seed: UInt64.random(in: 1 ... UInt64(Int64.max)))
        let prompt = GatePrompt.pick(items: env.content.items, history: history, pendingId: UserDefaults.standard.string(forKey: Self.pendingGateKey),
                                     now: now, forgottenWords: forgotten, rng: &rng)
        let mercy = (try? env.gamification?.state().mercyLeft) ?? 0
        let strict = (try? env.gamification?.contract().isActive(.strictGate, at: Int64(now.timeIntervalSince1970 * 1000))) ?? false
        var requirement = GateRequirement.standard
        requirement.minWords = settings.gateMinWords
        return GateModel(prompt: prompt, requirement: requirement, price: GateSkipPrice(responseCostOn: responseCostOn, mercyLeft: mercy),
                         strict: strict, store: store, gamification: env.gamification, shownAt: now)
    }

    private func showGate(trigger: IntrusionTrigger) {
        let now = Date()
        let model = makeGateModel(now: now)
        markGateShown(model.prompt, now: now)
        model.onFinish = { [weak self] outcome in self?.finish(outcome) }
        visible = .gate(model, trigger: trigger, shownAt: now)
        let stage = self.stage
        presenter.onForcedClose = { [weak self] _ in self?.finish(.timeout, reason: "watchdog") }
        // The model says "we'll finish later" at 5:00; the presenter's watchdog is the hard backstop.
        let limit = smokeName == nil ? SurfaceWatchdog.gate + .seconds(10) : SurfaceWatchdog.smoke
        presenter.show(.fullScreen, maxOnScreen: limit, activate: true) {
            GateView(model: model, stage: stage).environment(env)
        }
        log(.gate, trigger: trigger, verdict: .show(.poster), outcome: .shown, mode: nil)
        afterShow()
    }

    /// A newly picked gate prompt is logged as shown and stays pending (sticky) until that gate is
    /// completed or skipped; a re-shown pending prompt is not a new exposure. Smokes leave both alone.
    private func markGateShown(_ prompt: GatePrompt, now: Date) {
        let defaults = UserDefaults.standard
        guard smokeName == nil, defaults.string(forKey: Self.pendingGateKey) != prompt.id else { return }
        defaults.set(prompt.id, forKey: Self.pendingGateKey)
        guard let database = env.database else { return }
        let item = env.content.items.first { $0.id == prompt.id }
        let row = ExposureRecord(itemId: prompt.id, groupId: item?.group, surface: .gate, kind: prompt.kind.rawValue, at: now)
        do { try ExposureStore(database: database).record(row) } catch { NSLog("Tenaz: gate exposure not recorded: \(error)") }
    }

    private func afterShow() {
        installKeyMonitor()
        watchTask?.cancel()
        watchTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.watchTick()
            }
        }
    }

    /// Every second while a surface is visible (F14): any kill switch or meeting signal closes it for free.
    private func watchTick() {
        guard let visible else { return }
        let now = Date()
        killState = KillSwitch.read()
        let signals = smokeName == nil ? probes.read() : InterruptionSignals()
        if let reason = IntrusionDecider.mustCloseVisible(killSwitch: killState, signals: signals, policy: InterruptionPolicy(), now: now) {
            finish(killState.isEngaged(at: now) ? .killed : .deferredMidway, reason: reason)
            return
        }
        if case let .gate(model, _, _) = visible, now >= model.deadline { model.timeUp() }
    }

    // MARK: Ending

    /// Closes the visible surface and logs how it ended. Hatches are counted, never blocked.
    func finish(_ outcome: IntrusionOutcome, reason: String? = nil) {
        guard let current = visible else { return }
        visible = nil
        watchTask?.cancel()
        removeKeyMonitor()
        presenter.onForcedClose = nil
        presenter.close()
        let now = Date()
        let d = UserDefaults.standard
        if outcome == .deferredMidway || outcome == .killed {
            if case let .overlay(model, _, _) = current { model.refundPenalties() }
        }
        switch outcome {
        case .snoozed:
            d.set(now.addingTimeInterval(Self.snoozeMinutes * 60).timeIntervalSince1970, forKey: Self.snoozedUntilKey)
            try? store?.logHatch(.snooze, at: now)
        case .deferredMeeting:
            meetingClaim(joiningCall: current.surface == .gate, now: now)
        case .skipped:
            try? store?.logHatch(current.surface == .gate ? .emergencySkip : .overlaySkip, at: now)
            if current.surface == .gate { d.removeObject(forKey: Self.pendingGateKey) }
        case .completed where current.surface == .gate:
            d.removeObject(forKey: Self.pendingGateKey)
            // The accepted paragraph was queued for Claude: grade it now on the app's one queue.
            env.grading.nudge()
        default: break
        }
        var row = IntrusionLogRecord(ts: IntrusionStore.ms(now), surface: current.surface, trigger: current.trigger, decision: "allow",
                                     reason: reason, outcome: outcome, durationMs: Int(now.timeIntervalSince(current.shownAt) * 1000),
                                     mode: current.mode, frontmostBundleId: SignalProbes.frontmostBundleId)
        if outcome == .deferredMidway { row.refundedCost = 0 }
        _ = try? store?.log(row)
        if let smokeName { endSmoke(smokeName, outcome: outcome, durationMs: row.durationMs ?? 0) }
    }

    /// "I'm in a meeting" / "Joining a call": always works at once. Free when a meeting signal
    /// corroborates it; otherwise counted (and priced only under Response cost, after 2 a day).
    private func meetingClaim(joiningCall: Bool, now: Date) {
        UserDefaults.standard.set(now.addingTimeInterval(Self.meetingMinutes * 60).timeIntervalSince1970,
                                  forKey: IntrusionSettings.Keys.meetingUntil)
        let corroborated = IntrusionDecider.mustCloseVisible(killSwitch: KillSwitchState(), signals: probes.read(),
                                                             policy: InterruptionPolicy(), now: now) != nil
        try? store?.logHatch(joiningCall ? .joiningCall : .meetingClaim, corroborated: corroborated, at: now)
        if !corroborated {
            _ = try? env.gamification?.handle(.meetingClaimUncorroborated(workCalendarVisible: SignalProbes.calendarGranted))
        }
    }

    /// The popover's "Pause intrusions 1 h": instant, free, counted (F10 honest hatches).
    func pauseOneHour() {
        let now = Date()
        UserDefaults.standard.set(now.addingTimeInterval(3600).timeIntervalSince1970, forKey: IntrusionSettings.Keys.pausedUntil)
        try? store?.logHatch(.pause1h, at: now)
        _ = try? env.gamification?.handle(.intrusionsPaused)
        pendingTask?.cancel()
        pendingTask = nil
        toastPresenter.close()
        closeEverything(.killed, reason: "paused 1 h")
    }

    private func killSwitchFired(_ reason: String) {
        pendingTask?.cancel()
        pendingTask = nil
        toastPresenter.close()
        // The same switch voids and closes an open Exam Mode (hotkey included; its own poll covers
        // the defaults key and the file too, a second call does nothing).
        ExamCenter.shared.mode.killSwitch()
        try? store?.logHatch(.killSwitch, at: Date())
        _ = try? env.gamification?.handle(.intrusionsPaused)
        closeEverything(.killed, reason: reason)
    }

    func closeEverything(_ outcome: IntrusionOutcome, reason: String) {
        if visible != nil { finish(outcome, reason: reason) } else { presenter.close() }
    }

    private func log(_ surface: IntrusionSurface, trigger: IntrusionTrigger, verdict: IntrusionVerdict, outcome: IntrusionOutcome, mode: OverlayMode?) {
        let row = IntrusionLogRecord(ts: IntrusionStore.ms(Date()), surface: surface, trigger: trigger, decision: verdict.decision,
                                     reason: verdict.reason, outcome: outcome, mode: mode, frontmostBundleId: SignalProbes.frontmostBundleId)
        _ = try? store?.log(row)
    }

    // MARK: Keyboard (Esc, number keys, ?, ⌃⌥⌘S) while a surface is key

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            (self?.handleKey(event) ?? false) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// True when the key was used here.
    private func handleKey(_ event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isEsc = event.keyCode == 53
        switch visible {
        case let .overlay(model, _, _):
            if isEsc, mods.isEmpty { model.escape(.skip); return true }
            if mods == [.control, .option, .command], event.charactersIgnoringModifiers == "s" {
                if model.snoozesLeft > 0 { model.escape(.snooze) }
                return true
            }
            if event.characters == "?" { model.toggleHint(); return true }
            if model.phase == .asking, model.current?.prompt.type == .recognition,
               let c = event.characters, let n = Int(c), (1...4).contains(n) {
                model.choose(n - 1)
                return true
            }
            if model.phase != .asking, model.current?.prompt.type == .recognition, event.keyCode == 36 { model.submit(); return true }
        case let .gate(model, _, _):
            if isEsc, mods.isEmpty { model.escape(); return true }
            if model.phase == .confirmingSkip, event.keyCode == 36 || event.keyCode == 76 { model.cancelSkip(); return true }
        case nil: break
        }
        return false
    }

    // MARK: Smoke (`--tenaz-smoke overlay|overlay-sticker|gate`)

    /// Shows the surface with real bundled content through the real pipeline (kill switch included;
    /// quiet hours and live meeting signals are skipped because the smoke runs unattended at night),
    /// lets the watchdog close it within 3 s, logs, prints and exits.
    func runSmoke(_ name: String) {
        smokeName = name
        let surface: IntrusionSurface = name == "gate" ? .gate : .overlay
        var r = makeRequest(surface, trigger: .smoke)
        r.settings.quietHours = QuietHours(startMinute: 0, endMinute: 0)
        r.signals = InterruptionSignals()
        r.history = IntrusionHistory()
        r.callOrChatFrontmost = false
        let verdict = IntrusionDecider.decide(r)
        guard case .show = verdict else {
            log(surface, trigger: .smoke, verdict: verdict, outcome: .deferred, mode: nil)
            print("smoke \(name) not shown: \(verdict.reason ?? "?")")
            exit(0)
        }
        switch name {
        case "gate": showGate(trigger: .smoke)
        default:
            let items = overlayBatch()
            showOverlay(mode: name == "overlay-sticker" ? .sticker : .poster, trigger: .smoke,
                        items: items.isEmpty ? IntrusionSamples.overlayItems(env.content) : items)
        }
    }

    private func endSmoke(_ name: String, outcome: IntrusionOutcome, durationMs: Int) {
        let rows = (try? env.database?.reader.read { db in
            try IntrusionLogRecord.filter(sql: "trigger = 'smoke'").order(sql: "id").fetchAll(db)
        }) ?? []
        let summary = rows.map { "\($0.outcome)\($0.mode.map { "/\($0)" } ?? "")" }.joined(separator: ", ")
        print("smoke \(name) closed: \(outcome.rawValue) after \(durationMs) ms; intrusion_log rows: \(rows.count) [\(summary)]")
        let ok = durationMs <= 3000 && rows.count >= 2 && !UserDefaults.standard.bool(forKey: IntrusionSettings.Keys.overlaysEnabled)
        exit(ok ? 0 : 1)
    }
}
