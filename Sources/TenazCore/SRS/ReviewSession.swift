import Foundation

/// The review state machine (no UI, no database): serve a card, grade the answer, schedule it with
/// FSRS + learning steps, build the log row. A card that lands in a learning step (a miss comes back
/// in 1 min) returns within this session once it is due. The app wraps this in an `@Observable` store
/// and saves each outcome with `ReviewStore.record`.
public struct ReviewSession: Sendable {
    /// Cards whose next step is due within this window come back in the same session.
    public static let requeueHorizon: TimeInterval = 20 * 60

    public let surface: ReviewSurface
    public var steps: LearningSteps
    /// XP hook: called with every answer's event.
    public var onEvent: (@Sendable (ReviewEvent) -> Void)?
    public private(set) var queue: [SessionItem]
    /// Cards in learning steps, each with `card.due` set to when it comes back.
    public private(set) var relearn: [SessionItem] = []
    public private(set) var current: SessionItem?
    public private(set) var answered = 0

    public init(
        items: [SessionItem], surface: ReviewSurface, steps: LearningSteps = .standard,
        onEvent: (@Sendable (ReviewEvent) -> Void)? = nil
    ) {
        queue = items
        self.surface = surface
        self.steps = steps
        self.onEvent = onEvent
    }

    /// No card on screen, none queued, none coming back.
    public var isFinished: Bool { current == nil && queue.isEmpty && relearn.isEmpty }

    /// When the next learning-step card comes back, if any ("again in 1 min").
    public var nextReturn: Date? { relearn.map(\.card.dueDate).min() }

    /// The card to show at `now`: the current one if unanswered, else a learning-step card that is
    /// due, else the next queued card. nil when nothing is due yet (see `nextReturn`) or finished.
    public mutating func next(now: Date) -> SessionItem? {
        if let current { return current }
        let nowMs = now.unixMilliseconds
        if let i = relearn.indices.filter({ relearn[$0].card.due <= nowMs }).min(by: { relearn[$0].card.due < relearn[$1].card.due }) {
            current = relearn.remove(at: i)
        } else if !queue.isEmpty {
            current = queue.removeFirst()
        }
        return current
    }

    /// Grades the answer to the current card and schedules it.
    public mutating func submit(
        _ answer: ReviewAnswer, durationMs: Int, inputMode: InputMode, at now: Date, appFocusOk: Bool? = nil
    ) throws(ReviewSessionError) -> ReviewOutcome {
        guard let item = current else { throw .noCurrentCard }
        guard let rating = Grader.rating(for: item.prompt, answer: answer, durationMs: durationMs) else {
            throw .answerDoesNotFitCard
        }
        let match: MatchResult? = if case let .typed(s) = answer {
            AnswerMatcher.match(s, expected: item.prompt.expected ?? "", accepted: item.prompt.accepted)
        } else { nil }

        let before = item.card
        var after = before
        let scheduler = StepScheduler(desiredRetention: before.desiredRetention, steps: steps)
        after.apply(scheduler.review(before.memory, rating: rating, at: now))

        let inSteps = after.state == .learning || after.state == .relearning
        let comesBack = inSteps && after.dueDate.timeIntervalSince(now) <= Self.requeueHorizon ? after.dueDate : nil
        if comesBack != nil {
            var back = item
            back.card = after
            relearn.append(back)
        }
        current = nil
        answered += 1

        let event = ReviewEvent(
            cardId: before.id, noteId: before.noteId, cardType: before.type, rating: rating, correct: rating != .again,
            wasNew: before.state == .new, surface: surface, durationMs: durationMs, at: now
        )
        let log = ReviewLogRecord(
            before: before, after: after, rating: rating, at: now, durationMs: durationMs, inputMode: inputMode,
            surface: surface, answerText: answer.text, appFocusOk: appFocusOk
        )
        onEvent?(event)
        return ReviewOutcome(
            before: before, after: after, rating: rating, match: match, log: log, event: event,
            comesBackAt: comesBack, buryDay: DayBoundary.day(for: now)
        )
    }
}
