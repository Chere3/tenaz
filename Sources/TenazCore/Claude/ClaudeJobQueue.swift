import Foundation

/// Runs the persistent `claude_job` queue one job at a time (PLAN §4.6, F6).
/// - Backoff after a failed call: 1, 5, then 30 minutes; a job fails for good on its 4th failure.
/// - A usage limit pauses the whole queue for 1 hour (the attempt is not counted).
/// - Claude not installed: the job stays queued, uncounted, and is retried in 1 hour.
/// - Monthly mocks run 3 times and take the median per criterion; if the runs disagree by more
///   than a point, 2 more runs are added (still the median) and the grade is flagged low-confidence.
/// Exam results never wait on this: they show the objective parts and "grade pending".
/// The app keeps exactly one per process (its init puts `running` jobs back in the queue, which
/// would double-grade a job another instance is working on).
public actor ClaudeJobQueue {
    public static let backoff: [Duration] = [.seconds(60), .seconds(5 * 60), .seconds(30 * 60)]
    public static let maxAttempts = 4
    public static let pauseAfterLimit: Duration = .seconds(3600)
    public static let extraRunsWhenSpread = 2

    /// What one `drain` did, for logs and tests.
    public struct Report: Equatable, Sendable {
        public var graded: [Int64] = []
        public var retried: [Int64] = []
        public var failed: [Int64] = []
        /// Claude is not installed or hit a usage limit; nothing else was tried.
        public var unavailable = false

        public init(unavailable: Bool = false) { self.unavailable = unavailable }
    }

    private let store: ExamStore
    private let runner: any GradeRunner
    private let clock: any TenazClock
    public private(set) var pausedUntil: Date?
    /// True while a drain is working; a second `drain` then returns at once (the running one keeps
    /// claiming due jobs, so a job queued meanwhile is still picked up and no two calls run in parallel).
    public private(set) var isDraining = false
    private var observer: (@Sendable (Report) -> Void)?

    public init(store: ExamStore, runner: any GradeRunner, clock: any TenazClock) throws {
        self.store = store
        self.runner = runner
        self.clock = clock
        // Jobs left `running` by a crash or quit go back to the queue.
        try store.resetRunningJobs()
    }

    /// Processes every due job once, oldest first, and returns. The app calls it after each
    /// submit and on a timer (`run(every:)`); tests call it directly.
    @discardableResult
    public func drain() async -> Report {
        var report = Report()
        if let until = pausedUntil, clock.now < until {
            report.unavailable = true
            return report
        }
        guard !isDraining else { return report }
        isDraining = true
        defer { isDraining = false }
        pausedUntil = nil
        while let job = try? store.claimNextJob(now: clock.now) {
            let result = await process(job)
            switch result {
            case .graded: report.graded.append(job.job.id ?? -1)
            case .retried: report.retried.append(job.job.id ?? -1)
            case .failed: report.failed.append(job.job.id ?? -1)
            case .unavailable: report.unavailable = true
            }
            // Screens showing pending grades reload after every job, not only at the end.
            observer?(report)
            if result == .unavailable { return report }
        }
        return report
    }

    /// Failed jobs get a fresh set of attempts (the app calls this once per launch).
    @discardableResult
    public func retryFailedJobs() -> Int {
        (try? store.requeueFailedJobs(at: clock.now)) ?? 0
    }

    /// Called after every processed job with the drain's report so far (on the queue's executor).
    public func observe(_ observer: @escaping @Sendable (Report) -> Void) {
        self.observer = observer
    }

    /// The app's loop: drain, then sleep. Ends when the surrounding task is cancelled.
    public func run(every interval: Duration = .seconds(60)) async {
        while !Task.isCancelled {
            await drain()
            do { try await clock.sleep(for: interval) } catch { return }
        }
    }

    // MARK: One job

    private enum Result { case graded, retried, failed, unavailable }

    private func process(_ job: ExamStore.GradeJob) async -> Result {
        guard let jobId = job.job.id else { return .failed }
        do {
            let request = try store.gradeRequest(for: job)
            var runs = job.finishedRuns
            while runs.count < target(for: job.payload.runs, runs: runs) {
                let result = try await runner.grade(request)
                try store.saveRun(result, entryId: job.payload.entryId, runIndex: runs.count, model: runner.model, at: clock.now)
                runs.append(result)
            }
            try store.completeGrade(job, at: clock.now)
            return .graded
        } catch is CancellationError {
            // The app is quitting or the loop was cancelled: not a Claude failure, so no attempt is spent.
            try? store.requeue(jobId, countAttempt: false, nextAttemptAt: clock.now, error: "cancelled")
            return .unavailable
        } catch let error as ClaudeCLIError {
            switch error {
            case .notInstalled:
                try? store.requeue(jobId, countAttempt: false, nextAttemptAt: clock.now + Self.seconds(Self.pauseAfterLimit),
                                   error: error.description)
                return .unavailable
            case .usageLimit:
                let until = clock.now + Self.seconds(Self.pauseAfterLimit)
                pausedUntil = until
                try? store.requeue(jobId, countAttempt: false, nextAttemptAt: until, error: error.description)
                return .unavailable
            case .timedOut, .failed, .noStructuredOutput:
                return retryOrFail(job, error: error.description)
            }
        } catch {
            return retryOrFail(job, error: String(describing: error))
        }
    }

    /// Runs wanted so far: the payload's count, plus the extra runs once three runs disagree
    /// (checked on the runs already saved too, so a retried monthly job still adds them).
    private func target(for planned: Int, runs: [GradeResult]) -> Int {
        guard planned == 3, runs.count >= 3, GradeAggregator.lowConfidence(Array(runs.prefix(3))) else { return planned }
        return planned + Self.extraRunsWhenSpread
    }

    private func retryOrFail(_ job: ExamStore.GradeJob, error: String) -> Result {
        guard let jobId = job.job.id else { return .failed }
        let attempts = job.job.attempts + 1
        if attempts >= Self.maxAttempts {
            try? store.failJob(job, error: error, at: clock.now)
            return .failed
        }
        let wait = Self.backoff[min(attempts, Self.backoff.count) - 1]
        try? store.requeue(jobId, countAttempt: true, nextAttemptAt: clock.now + Self.seconds(wait), error: error)
        return .retried
    }

    static func seconds(_ d: Duration) -> TimeInterval {
        Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18
    }
}
