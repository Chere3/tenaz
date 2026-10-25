import Foundation
import Observation
import TenazCore

/// The one `ClaudeJobQueue` of the process (PLAN §4.6), owned by `AppEnvironment`. On a normal launch
/// `start()` runs its `run(every:)` loop until quit; automation modes never start it, so snapshots,
/// smokes and self-tests make no Claude call unless a self-test drains on purpose (`drainNow`).
/// Every writing entry with a queued job is graded here: exam tasks, gate paragraphs, the Write sheet.
/// Screens showing pending grades watch `revision`, which moves after every job the queue processes.
@MainActor
@Observable
final class GradingService {
    private(set) var revision = 0
    private(set) var lastReport: ClaudeJobQueue.Report?

    @ObservationIgnored let cli: ClaudeCLI
    @ObservationIgnored private let queue: ClaudeJobQueue?
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var observing = false

    init(database: TenazDatabase?, cli: ClaudeCLI) {
        self.cli = cli
        queue = database.flatMap { try? ClaudeJobQueue(store: ExamStore(database: $0), runner: AppGradeRunner(cli: cli), clock: SystemClock()) }
    }

    var isStarted: Bool { loop != nil }

    /// Normal launch only (AppDelegate): drain now, then every minute.
    func start() {
        guard loop == nil, let queue else { return }
        loop = Task { [weak self] in
            await self?.attachObserver()
            // A grade that failed on an earlier day (offline, logged out) gets another chance.
            await queue.retryFailedJobs()
            await queue.run(every: .seconds(60))
        }
    }

    /// Quitting: a job cut short goes back to the queue without spending an attempt.
    func stop() {
        loop?.cancel()
        loop = nil
    }

    /// Something was just queued (a gate paragraph, a Write entry): grade it now rather than at the
    /// next tick. Does nothing until `start()`, so automation never reaches Claude this way.
    func nudge() {
        guard loop != nil else { return }
        Task { await drainNow() }
    }

    /// One drain of the shared queue. If the loop is already draining this returns at once and the
    /// running drain picks the new jobs up; `revision` moves as they finish.
    @discardableResult
    func drainNow() async -> ClaudeJobQueue.Report {
        guard let queue else { return ClaudeJobQueue.Report(unavailable: true) }
        await attachObserver()
        let report = await queue.drain()
        publish(report)
        return report
    }

    private func attachObserver() async {
        guard !observing, let queue else { return }
        observing = true
        await queue.observe { [weak self] report in
            Task { @MainActor in self?.publish(report) }
        }
    }

    private func publish(_ report: ClaudeJobQueue.Report) {
        lastReport = report
        revision += 1
    }
}

/// Grades through the `claude` CLI with Settings → Claude: the chosen model, and "Use Claude" off
/// keeps jobs waiting (requeued uncounted, as when Claude is not installed).
nonisolated struct AppGradeRunner: GradeRunner {
    /// Same keys as `SettingsModel.Keys`.
    static let enabledKey = "claudeEnabled"
    static let modelKey = "claudeModel"

    let cli: ClaudeCLI

    var model: String { UserDefaults.standard.string(forKey: Self.modelKey) ?? cli.model }

    func grade(_ request: GradeRequest) async throws -> GradeResult {
        guard UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true else { throw ClaudeCLIError.notInstalled }
        var c = cli
        c.model = model
        return try await CLIGradeRunner(cli: c).grade(request)
    }
}
