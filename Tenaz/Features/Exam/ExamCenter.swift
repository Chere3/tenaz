import AppKit
import Observation
import TenazCore

/// The exam area's state, shared by the Placement and Exams screens: what runs where, the
/// Tivra witness, results to show, and an exam paused by a meeting.
@Observable
final class ExamCenter {
    enum Screen {
        case overview
        /// A Daily Check running in the main window (no Exam Mode).
        case running(ExamRunner)
        case results(ExamResultModel)
    }

    static let shared = ExamCenter(environment: AppDelegate.environment, navigator: AppDelegate.navigator)

    var screen: Screen = .overview
    /// An Exam Mode attempt paused by a meeting or the watchdog; resumable from the window.
    private(set) var paused: ExamRunner?
    private(set) var pausedReason: ExamModeExit?
    private(set) var witness: ExamWitness = .checking
    private(set) var problem: String?
    /// The exam waits because the calendar shows a meeting now: "I'm free, start anyway" is offered.
    private(set) var calendarBlocked = false
    @ObservationIgnored private var blockedRunner: ExamRunner?
    /// Bumped when attempts change, so lists reload.
    private(set) var revision = 0
    /// Results still verifying, grading or crediting. Kept alive here so leaving the results
    /// screen (e.g. "Start reviewing") never cancels the placement credit.
    @ObservationIgnored private var finishing: [String: ExamResultModel] = [:]
    let mode = ExamModeController()

    @ObservationIgnored let environment: AppEnvironment
    @ObservationIgnored let store: ExamStore?
    @ObservationIgnored let reader = TivraReader()
    @ObservationIgnored private let navigator: Navigator
    /// Set by a view that has `openWindow`, so the results can bring the main window back.
    @ObservationIgnored var openMainWindow: () -> Void = {}
    @ObservationIgnored private(set) lazy var denyList: DenyList = Self.loadDenyList()

    /// The bundled deny-list plus the bundle ids of installed apps resolved by name.
    static func loadDenyList() -> DenyList {
        let url = Bundle.main.resourceURL?.appending(path: "Content/denylist.json")
        let base = url.flatMap { try? DenyList.load(from: $0) } ?? DenyList()
        return DenyListResolver.resolve(base)
    }

    init(environment: AppEnvironment, navigator: Navigator) {
        self.environment = environment
        self.navigator = navigator
        store = environment.database.map(ExamStore.init)
        mode.onClose = { [weak self] exit in self?.modeClosed(exit) }
    }

    var isExamModeShowing: Bool { mode.isShowing }

    // MARK: Witness

    /// Reads Tivra's capture health over the last 10 minutes (read-only).
    func refreshWitness() async {
        let window = TivraWindow(start: .now.addingTimeInterval(-600), end: .now)
        do {
            let health = try await reader.health(window: window)
            witness = health.isHealthy ? .watching : .notWatching(health.problems.first ?? "capture gap")
        } catch {
            witness = .notWatching("Tivra isn't running here")
        }
    }

    // MARK: Starting

    func startPlacement() { start(.placement) }

    /// Safety net if Exam Mode's full-screen panel misbehaves: the same placement in the main window.
    /// No app hiding or paste monitoring, so the result is a level estimate, not a verified exam.
    func startPlacementInWindow() {
        guard let blueprint = environment.blueprints.blueprint(for: .placement) else {
            problem = "The exam can't start: the database or the exam plan is missing."
            return
        }
        start(blueprint, examMode: false)
    }

    /// Shows the Placement route (intro, pledge, Continue), never a new attempt directly.
    func openPlacement() {
        problem = nil
        navigator.route = .placement
    }

    func startDailyCheck() { start(.daily) }

    func startMock(_ kind: ExamKind) { start(kind) }

    private func start(_ kind: ExamKind) {
        guard let blueprint = environment.blueprints.blueprint(for: kind) else {
            problem = "The exam can't start: the database or the exam plan is missing."
            return
        }
        start(blueprint)
    }

    /// Begins a new attempt of `blueprint` (the Start buttons via their kind; `exam-live` with a short one).
    func start(_ blueprint: ExamBlueprint, examMode forced: Bool? = nil) {
        problem = nil
        calendarBlocked = false
        blockedRunner = nil
        guard let store else {
            problem = "The exam can't start: the database or the exam plan is missing."
            return
        }
        let kind = blueprint.kind
        do {
            let examMode = forced ?? (kind != .daily)
            let runner = try ExamRunner.begin(blueprint, library: environment.content, store: store, examMode: examMode)
            launch(runner)
        } catch {
            problem = "The exam can't start: \(error.localizedDescription)"
        }
    }

    /// Rebuilds an unfinished attempt (pause between sections, crash, quit) and continues it.
    /// The attempt paused by a meeting or the watchdog is continued in memory, never rebuilt twice.
    func resume(_ attemptId: String) {
        problem = nil
        if paused?.session.id == attemptId {
            resumePaused()
            return
        }
        guard let store else { return }
        do {
            let runner = try ExamRunner.resume(attemptId, catalog: environment.blueprints, library: environment.content, store: store)
            launch(runner)
        } catch {
            problem = "Couldn't continue that exam: \(error)"
        }
        revision += 1
    }

    /// Continue the exam paused by a meeting or the watchdog. `notInACall` ("Not in a meeting?")
    /// ignores the microphone and the calendar for the rest of the attempt; the camera still blocks.
    func resumePaused(notInACall: Bool = false) {
        guard let runner = paused else { return }
        problem = nil
        launch(runner, ignoringCalendar: notInACall, ignoringMicrophone: notInACall)
    }

    /// "I'm free, start anyway" after a calendar meeting kept the exam from opening.
    func startAnyway() {
        guard let runner = blockedRunner else { return }
        problem = nil
        launch(runner, ignoringCalendar: true)
    }

    private func launch(_ runner: ExamRunner, ignoringCalendar: Bool = false, ignoringMicrophone: Bool = false) {
        runner.witness = witness
        if runner.examMode {
            let sameAttempt = runner === mode.lastRunner
            if meetingBlocksStart(runner, ignoringCalendar: ignoringCalendar || (sameAttempt && mode.ignoreCalendar)) { return }
            if paused === runner {
                paused = nil
                pausedReason = nil
            }
            screen = .overview
            let remaining = runner.blueprint.nominalMinutes + 30
            mode.present(runner, denyList: denyList, hardCap: .seconds(Int(remaining * 60)),
                         ignoringCalendar: ignoringCalendar, ignoringMicrophone: ignoringMicrophone)
        } else {
            runner.onEvent = { [weak self] event in
                switch event {
                case let .finished(id): self?.showResults(id, kind: runner.blueprint.kind)
                case .voided: self?.screen = .overview
                default: break
                }
            }
            screen = .running(runner)
            navigator.route = .exams
        }
    }

    /// Never open the full-screen exam over a call or a calendar meeting; the attempt stays resumable.
    /// A calendar meeting can be overridden ("I'm free, start anyway"); the camera can't.
    private func meetingBlocksStart(_ runner: ExamRunner, ignoringCalendar: Bool) -> Bool {
        calendarBlocked = false
        blockedRunner = nil
        guard !LaunchArguments.current.isAutomation, let block = mode.startBlock(ignoringCalendar: ignoringCalendar) else { return false }
        switch block {
        case .camera:
            problem = "Your camera is on, so the exam waits. Start it again when the call ends. Your answers are saved."
        case let .calendar(title):
            problem = "Your calendar shows \"\(title)\" now, so the exam waits. Your answers are saved."
            calendarBlocked = true
            blockedRunner = runner
        }
        revision += 1
        return true
    }

    private func modeClosed(_ exit: ExamModeExit) {
        revision += 1
        switch exit {
        case let .finished(id):
            clearPaused()
            showResults(id, kind: mode.lastKind ?? .placement)
            bringMainWindow()
        case .voided, .pausedForLater:
            clearPaused()
            bringMainWindow()
        case .meeting:
            // Never pop anything during a meeting: the paused card waits in the window.
            paused = mode.lastRunner
            pausedReason = exit
        case .watchdog:
            // A long break on a section intro: show where to continue instead of a bare desktop.
            paused = mode.lastRunner
            pausedReason = exit
            bringMainWindow()
        }
    }

    /// The attempt that just ended is no longer the paused one (its runner must never relaunch).
    private func clearPaused() {
        guard let paused, paused === mode.lastRunner || paused.phase == .finished || paused.phase == .voided else { return }
        self.paused = nil
        pausedReason = nil
        if blockedRunner === paused { blockedRunner = nil; calendarBlocked = false }
    }

    // MARK: Results

    func showResults(_ attemptId: String, kind: ExamKind) {
        let model = finishing[attemptId] ?? ExamResultModel(attemptId: attemptId, kind: kind, store: store)
        screen = .results(model)
        navigator.route = .exams
        revision += 1
        finishing[attemptId] = model
        model.onWorkDone = { [weak self] in
            self?.finishing[attemptId] = nil
            self?.revision += 1
        }
        model.start(grading: environment.grading, gamification: environment.gamification, denyList: denyList, reader: reader)
    }

    /// Normal launch: finished attempts whose credit never ran (quit or crash during the results'
    /// verify/grade wait) get it now, in the background, without changing the screen.
    func creditLeftovers() {
        guard let store, let leftovers = try? store.uncreditedAttempts(since: .now.addingTimeInterval(-14 * 86_400)) else { return }
        for (id, kind) in leftovers where finishing[id] == nil {
            let model = ExamResultModel(attemptId: id, kind: kind, store: store)
            finishing[id] = model
            model.onWorkDone = { [weak self] in
                self?.finishing[id] = nil
                self?.revision += 1
            }
            model.start(grading: environment.grading, gamification: environment.gamification, denyList: denyList, reader: reader)
        }
    }

    /// Leaves the results screen; its background work (grading, credit) keeps going.
    func closeResults() {
        screen = .overview
        revision += 1
    }

    func goReview() {
        closeResults()
        navigator.route = .review
    }

    func leaveRunning(_ runner: ExamRunner) {
        runner.abort(reason: "left the Daily Check")
        screen = .overview
        revision += 1
    }

    private func bringMainWindow() {
        NSApp.activate()
        if let window = NSApp.windows.first(where: { $0.title == "Tenaz" && $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openMainWindow()
        }
    }
}
