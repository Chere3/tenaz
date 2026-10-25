import Foundation

/// The four review answers. Raw values match the FSRS rating integers 1...4.
public enum Rating: Int, Codable, CaseIterable, Sendable {
    case again = 1, hard, good, easy
}

/// Card lifecycle state.
public enum CardState: Int, Codable, Sendable {
    case learning = 1, review, relearning
}

/// The memory state of one card. A never-reviewed card has nil stability and difficulty.
public struct MemoryState: Codable, Equatable, Sendable {
    public var stability: Double?
    public var difficulty: Double?
    public var state: CardState = .learning
    public var due: Date?
    public var lastReview: Date?
    public var reps = 0
    public var lapses = 0
    /// Current learning/relearning step (py-fsrs `Card.step`); nil in review. Used by `StepScheduler` only.
    public var step: Int?

    public init(
        stability: Double? = nil, difficulty: Double? = nil, state: CardState = .learning,
        due: Date? = nil, lastReview: Date? = nil, reps: Int = 0, lapses: Int = 0, step: Int? = nil
    ) {
        self.stability = stability
        self.difficulty = difficulty
        self.state = state
        self.due = due
        self.lastReview = lastReview
        self.reps = reps
        self.lapses = lapses
        self.step = step
    }

    public var isNew: Bool { stability == nil || difficulty == nil }
}

/// One review, kept so parameters can be re-optimized later.
public struct ReviewLog: Codable, Equatable, Sendable {
    public var rating: Rating
    public var reviewedAt: Date
    public var elapsedDays: Double
    public var scheduledDays: Double
    public var state: CardState
}

public struct FSRSConfig: Sendable {
    /// FSRS-6 default weights, verbatim from py-fsrs v6.
    public static let defaultParameters: [Double] = [
        0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722,
        0.1666, 0.796, 1.4835, 0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425,
        0.0912, 0.0658, 0.1542,
    ]

    public var parameters: [Double]
    public var desiredRetention: Double
    public var maximumIntervalDays: Int

    public init(parameters: [Double] = defaultParameters, desiredRetention: Double = 0.90, maximumIntervalDays: Int = 36500) {
        precondition(parameters.count == 21, "FSRS-6 needs 21 parameters")
        precondition((0.70...0.99).contains(desiredRetention), "desiredRetention must be in 0.70...0.99")
        self.parameters = parameters
        self.desiredRetention = desiredRetention
        self.maximumIntervalDays = maximumIntervalDays
    }
}

/// FSRS-6 long-term scheduler, ported from fluo's Kotlin port (validated against py-fsrs 6.3.2
/// by the golden vectors in FSRSTests). `review` has no minute-level learning steps; the app schedules
/// through `StepScheduler`, which adds py-fsrs 6.3.2 learning steps on top of the math below.
public struct FSRS: Sendable {
    public let config: FSRSConfig
    private let w: [Double]
    private let decay: Double
    private let factor: Double
    static let stabilityMin = 0.001

    public init(config: FSRSConfig = FSRSConfig()) {
        self.config = config
        w = config.parameters
        decay = -config.parameters[20]
        factor = pow(0.9, 1.0 / decay) - 1.0
    }

    /// Probability of recall `elapsedDays` after the last review.
    public func retrievability(_ card: MemoryState, elapsedDays: Double) -> Double {
        guard let s = card.stability else { return 0 }
        return pow(1.0 + factor * (elapsedDays / s), decay)
    }

    public func retrievability(_ card: MemoryState, at now: Date) -> Double {
        guard let last = card.lastReview else { return 0 }
        return retrievability(card, elapsedDays: max(0, now.timeIntervalSince(last) / 86400))
    }

    public func review(_ card: MemoryState, rating: Rating, at now: Date) -> (card: MemoryState, log: ReviewLog) {
        let elapsed = card.lastReview.map { max(0, now.timeIntervalSince($0) / 86400) } ?? 0
        let scheduled: Double = {
            guard let due = card.due, let last = card.lastReview else { return 0 }
            return max(0, due.timeIntervalSince(last) / 86400)
        }()
        let log = ReviewLog(rating: rating, reviewedAt: now, elapsedDays: elapsed, scheduledDays: scheduled, state: card.state)
        let updated = card.isNew ? scheduleNew(card, rating, now) : scheduleExisting(card, rating, now, elapsed)
        return (updated, log)
    }

    /// Interval in days each rating would give, for button hints.
    public func previewIntervals(_ card: MemoryState, at now: Date) -> [Rating: Int] {
        var out: [Rating: Int] = [:]
        for r in Rating.allCases {
            let next = review(card, rating: r, at: now).card
            out[r] = Int(((next.due ?? now).timeIntervalSince(now) / 86400).rounded())
        }
        return out
    }

    private func scheduleNew(_ card: MemoryState, _ rating: Rating, _ now: Date) -> MemoryState {
        var c = card
        let s = max(w[rating.rawValue - 1], Self.stabilityMin)
        c.stability = s
        c.difficulty = clamp(w[4] - exp(w[5] * Double(rating.rawValue - 1)) + 1)
        c.state = rating == .again ? .learning : .review
        c.due = now.addingTimeInterval(Double(nextInterval(s)) * 86400)
        c.lastReview = now
        c.reps += 1
        return c
    }

    private func scheduleExisting(_ card: MemoryState, _ rating: Rating, _ now: Date, _ elapsed: Double) -> MemoryState {
        var c = card
        let r = retrievability(card, elapsedDays: elapsed)
        let oldD = card.difficulty!
        let oldS = card.stability!
        let s = rating == .again ? forgetStability(oldD, oldS, r) : recallStability(oldD, oldS, r, rating)
        if rating == .again, card.state == .review { c.lapses += 1 }
        c.difficulty = nextDifficulty(oldD, rating)
        c.stability = s
        c.state = rating == .again ? .relearning : .review
        c.due = now.addingTimeInterval(Double(nextInterval(s)) * 86400)
        c.lastReview = now
        c.reps += 1
        return c
    }

    func initialStability(_ rating: Rating) -> Double { max(w[rating.rawValue - 1], Self.stabilityMin) }

    func initialDifficulty(_ rating: Rating) -> Double { clamp(w[4] - exp(w[5] * Double(rating.rawValue - 1)) + 1) }

    func nextDifficulty(_ d: Double, _ rating: Rating) -> Double {
        let deltaD = -w[6] * Double(rating.rawValue - 3)
        let dp = d + deltaD * (10 - d) / 9
        let easyInit = w[4] - exp(w[5] * 3) + 1
        return clamp(w[7] * easyInit + (1 - w[7]) * dp)
    }

    func recallStability(_ d: Double, _ s: Double, _ r: Double, _ rating: Rating) -> Double {
        let hard = rating == .hard ? w[15] : 1
        let easy = rating == .easy ? w[16] : 1
        let inc = exp(w[8]) * (11 - d) * pow(s, -w[9]) * (exp(w[10] * (1 - r)) - 1) * hard * easy + 1
        return max(s * inc, Self.stabilityMin)
    }

    /// py-fsrs 6.3.2: the post-lapse stability is capped by the short-term term `S / e^(w17·w18)`.
    func forgetStability(_ d: Double, _ s: Double, _ r: Double) -> Double {
        let sf = w[11] * pow(d, -w[12]) * (pow(s + 1, w[13]) - 1) * exp(w[14] * (1 - r))
        return max(min(sf, s / exp(w[17] * w[18])), Self.stabilityMin)
    }

    /// Same-day review (py-fsrs `_short_term_stability`); never shrinks on Hard/Good/Easy.
    func shortTermStability(_ s: Double, _ rating: Rating) -> Double {
        var inc = exp(w[17] * (Double(rating.rawValue) - 3 + w[18])) * pow(s, -w[19])
        if rating != .again { inc = max(inc, 1) }
        return max(s * inc, Self.stabilityMin)
    }

    /// Whole days until the next review. Python `round` is half-to-even, so `.toNearestOrEven`.
    func nextInterval(_ s: Double) -> Int {
        let interval = (s / factor) * (pow(config.desiredRetention, 1 / decay) - 1)
        return min(max(1, Int(interval.rounded(.toNearestOrEven))), config.maximumIntervalDays)
    }

    func clamp(_ d: Double) -> Double { min(max(d, 1), 10) }
}
