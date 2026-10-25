import Foundation

/// The exam state machine (PLAN F5): sections in blueprint order, a per-section timer on the
/// injected clock, two-stage routing, adaptive sections, meeting pause/resume, abort (void) and
/// submit. Nothing is scored for the learner to see until `submit()`; no feedback during the test.
public struct ExamSession: Sendable {
    public enum Status: Equatable, Sendable {
        case running
        case paused(PauseReason)
        case submitted
        case voided
    }

    public enum PauseReason: String, Codable, Sendable {
        /// A meeting signal (F14): the timer stops and nothing is flagged.
        case meeting
        case user
    }

    public let id: String
    public let blueprint: ExamBlueprint
    public let seed: UInt64
    public let startedAt: Date
    /// Skill posteriors at the start (fresh priors for placement, stored states otherwise).
    public let priors: [ExamSkill: AbilityEstimator]
    public private(set) var status: Status = .running
    /// Index into `blueprint.sections`; nil once every section is done.
    public private(set) var sectionIndex: Int?
    /// Every task scheduled so far, in order (unanswered ones score as wrong).
    public private(set) var tasks: [ExamTask] = []
    public private(set) var responses: [ExamResponse] = []
    /// Router outcome per group.
    public private(set) var routes: [String: SectionSpec.Stage] = [:]
    public private(set) var pausedMs = 0
    public private(set) var endedAt: Date?

    private let library: ContentLibrary
    private let clock: any TenazClock
    public let includeOptional: Bool
    /// Item ids avoided because they were seen recently (stored so the attempt can be replayed).
    public let excluding: Set<String>
    private var rng: SeededRandom
    private var used: Set<String> = []
    private var sectionTasks: [ExamTask] = []
    private var taskIndex = 0
    private var adaptivePool: [ExamTask] = []
    private var adaptiveEstimate: AbilityEstimator?
    // Active time in the current section = sectionActiveMs + (now - runningSince) while running.
    private var sectionActiveMs = 0
    private var runningSince: Date?
    private var pausedAt: Date?
    private var taskStartMs = 0

    /// - Parameters:
    ///   - excluding: item ids seen recently; avoided unless the bank runs short.
    ///   - includeOptional: run optional sections (the monthly Grammar & Vocabulary block).
    public init(id: String = UUID().uuidString, blueprint: ExamBlueprint, library: ContentLibrary,
                priors: [ExamSkill: AbilityEstimator], excluding: Set<String> = [], seed: UInt64,
                includeOptional: Bool = false, clock: any TenazClock) {
        self.id = id
        self.blueprint = blueprint
        self.library = library
        self.priors = priors
        self.seed = seed
        self.includeOptional = includeOptional
        self.clock = clock
        self.excluding = excluding
        rng = SeededRandom(seed: seed)
        startedAt = clock.now
        enterSection(from: 0, now: startedAt)
    }

    // MARK: Reading state

    public var currentSection: SectionSpec? { sectionIndex.map { blueprint.sections[$0] } }

    public var currentTask: ExamTask? {
        guard sectionIndex != nil, taskIndex < sectionTasks.count else { return nil }
        return sectionTasks[taskIndex]
    }

    /// All sections done; the attempt can be submitted.
    public var isComplete: Bool { sectionIndex == nil }

    /// 0-based position of the current task in its section, and the section's length
    /// (an adaptive section reports its maximum).
    public var sectionPosition: Int { taskIndex }
    public var sectionLength: Int { currentSection?.adaptive?.max ?? sectionTasks.count }

    public var sectionElapsed: Duration { .milliseconds(activeMs(at: clock.now)) }

    public var sectionRemaining: Duration {
        guard let spec = currentSection else { return .zero }
        return max(.zero, spec.timeLimit - sectionElapsed)
    }

    public func response(for taskId: String) -> ExamResponse? { responses.last { $0.taskId == taskId } }

    // MARK: Actions

    /// Records the answer to the current task (nil = skipped) and moves on.
    /// Returns false while paused or after the attempt ended.
    @discardableResult
    public mutating func answer(_ answer: ExamAnswer?) -> Bool {
        guard status == .running, let task = currentTask else { return false }
        let now = clock.now
        responses.append(ExamResponse(taskId: task.id, sectionId: task.sectionId, answer: answer,
                                      latencyMs: activeMs(at: now) - taskStartMs, answeredAt: now))
        if var estimate = adaptiveEstimate {
            for unit in ObjectiveScorer.units(for: task, answer: answer) {
                estimate.apply(unit, weight: blueprint.kind.evidenceWeight)
            }
            adaptiveEstimate = estimate
        }
        advance(now)
        return true
    }

    /// Ends the section when its time is up. Call it from the UI's timer.
    @discardableResult
    public mutating func tick() -> Bool {
        guard status == .running, let spec = currentSection else { return false }
        let now = clock.now
        guard activeMs(at: now) >= Self.ms(spec.timeLimit) else { return false }
        finishSection(now)
        return true
    }

    /// The learner finishes the section early; its remaining tasks stay unanswered.
    public mutating func endSection() {
        guard status == .running, sectionIndex != nil else { return }
        finishSection(clock.now)
    }

    public mutating func pause(_ reason: PauseReason) {
        guard status == .running else { return }
        let now = clock.now
        sectionActiveMs = activeMs(at: now)
        runningSince = nil
        pausedAt = now
        status = .paused(reason)
    }

    public mutating func resume() {
        guard case .paused = status else { return }
        let now = clock.now
        closePause(now)
        runningSince = now
        status = .running
    }

    /// Hold-Esc abort or kill switch: the attempt is void and never counts.
    public mutating func abort() {
        guard status == .running || isPaused else { return }
        let now = clock.now
        closePause(now)
        status = .voided
        endedAt = now
    }

    /// Ends the attempt and scores the objective parts. Unanswered tasks count as wrong.
    /// Returns nil if the attempt was already submitted or voided.
    public mutating func submit() -> ExamOutcome? {
        guard status == .running || isPaused else { return nil }
        let now = clock.now
        closePause(now)
        status = .submitted
        endedAt = now
        return ExamScorer.score(self)
    }

    // MARK: Flow

    private var isPaused: Bool { if case .paused = status { true } else { false } }

    private mutating func closePause(_ now: Date) {
        if let p = pausedAt { pausedMs += Self.ms(now.timeIntervalSince(p)) }
        pausedAt = nil
    }

    private func activeMs(at now: Date) -> Int {
        sectionActiveMs + (runningSince.map { Self.ms(now.timeIntervalSince($0)) } ?? 0)
    }

    private mutating func advance(_ now: Date) {
        taskIndex += 1
        if let rule = currentSection?.adaptive, let estimate = adaptiveEstimate {
            let stop = taskIndex >= rule.max || (taskIndex >= rule.min && estimate.sd < rule.stopSD)
            if !stop, let next = ItemPicker.nearest(to: estimate.mean, in: adaptivePool, excluding: used) {
                schedule(next)
            }
        }
        if taskIndex >= sectionTasks.count { finishSection(now) } else { taskStartMs = activeMs(at: now) }
    }

    private mutating func finishSection(_ now: Date) {
        guard let index = sectionIndex else { return }
        let spec = blueprint.sections[index]
        if spec.resolvedStage == .router, let group = spec.group {
            let units = sectionTasks.flatMap { ObjectiveScorer.units(for: $0, answer: response(for: $0.id)?.answer) }
            let total = units.map(\.weight).reduce(0, +)
            let right = units.filter(\.isCorrect).map(\.weight).reduce(0, +)
            routes[group] = total > 0 && right / total >= (spec.routeUpperAt ?? 0.6) ? .upper : .lower
        }
        enterSection(from: index + 1, now: now)
    }

    private mutating func enterSection(from start: Int, now: Date) {
        sectionTasks = []
        taskIndex = 0
        adaptivePool = []
        adaptiveEstimate = nil
        sectionActiveMs = 0
        taskStartMs = 0
        if status == .running { runningSince = now }
        for i in start..<blueprint.sections.count where includes(blueprint.sections[i]) {
            build(blueprint.sections[i])
            if !sectionTasks.isEmpty {
                sectionIndex = i
                return
            }
        }
        sectionIndex = nil
    }

    private func includes(_ spec: SectionSpec) -> Bool {
        if spec.isOptional && !includeOptional { return false }
        switch spec.resolvedStage {
        case .linear, .router: return true
        case .lower, .upper: return routes[spec.group ?? ""] == spec.resolvedStage
        }
    }

    private mutating func build(_ spec: SectionSpec) {
        adaptivePool = []
        adaptiveEstimate = nil
        if spec.adaptive != nil {
            var pool: [ExamTask] = []
            for pick in spec.picks {
                pool += ItemPicker.candidates(pick, section: spec, library: library, excluding: used.union(excluding), rng: &rng)
            }
            if pool.count < (spec.adaptive?.max ?? 0) {
                // The bank ran short after excluding recent items: allow them again.
                pool = []
                for pick in spec.picks {
                    pool += ItemPicker.candidates(pick, section: spec, library: library, excluding: used, rng: &rng)
                }
            }
            pool.shuffle(using: &rng)
            adaptivePool = pool
            let skills = Set(pool.map(\.skill)).sorted { $0.rawValue < $1.rawValue }
            let estimate = AbilityEstimator.mixture(skills.map { priors[$0] ?? AbilityEstimator() })
            adaptiveEstimate = estimate
            if let first = ItemPicker.nearest(to: estimate.mean, in: pool, excluding: used) { schedule(first) }
        } else {
            for pick in spec.picks {
                var chosen = ItemPicker.pick(pick, section: spec, library: library, excluding: used.union(excluding), rng: &rng)
                if chosen.count < pick.count {
                    let more = ItemPicker.pick(pick, section: spec, library: library,
                                               excluding: used.union(chosen.map(\.id)), rng: &rng)
                    chosen += more.prefix(pick.count - chosen.count)
                }
                chosen.forEach { schedule($0) }
            }
        }
    }

    private mutating func schedule(_ task: ExamTask) {
        sectionTasks.append(task)
        tasks.append(task)
        used.insert(task.id)
    }

    static func ms(_ seconds: TimeInterval) -> Int { Int((seconds * 1000).rounded()) }

    static func ms(_ d: Duration) -> Int {
        Int(d.components.seconds) * 1000 + Int(d.components.attoseconds / 1_000_000_000_000_000)
    }
}
