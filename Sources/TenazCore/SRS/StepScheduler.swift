import Foundation

/// FSRS-6 with learning steps: a line-by-line port of py-fsrs 6.3.2 `Scheduler.review_card`
/// (fuzz off), replayed against `Fixtures/fsrs_with_steps.json`. The long-term math is `FSRS`'s.
public struct StepScheduler: Sendable {
    public var fsrs: FSRS
    public var steps: LearningSteps

    public init(desiredRetention: Double = 0.90, steps: LearningSteps = .standard) {
        fsrs = FSRS(config: FSRSConfig(desiredRetention: desiredRetention))
        self.steps = steps
    }

    /// Reviews `card` at `now`. `lapses` counts Review → Again (app bookkeeping, not in py-fsrs).
    public func review(_ card: MemoryState, rating: Rating, at now: Date) -> MemoryState {
        var c = card
        // py-fsrs uses `timedelta.days`: whole days, rounded down.
        let days = card.lastReview.map { Int((now.timeIntervalSince($0) / 86400).rounded(.down)) }
        let sameDay = days.map { $0 < 1 } ?? false
        let r = fsrs.retrievability(card, elapsedDays: Double(max(0, days ?? 0)))
        let interval: TimeInterval

        switch card.state {
        case .learning, .relearning:
            let isLearning = card.state == .learning
            let list = isLearning ? steps.learning : steps.relearning
            let step = card.step ?? 0
            if let s = card.stability, let d = card.difficulty {
                c.stability = sameDay ? fsrs.shortTermStability(s, rating) : nextStability(d, s, r, rating)
                c.difficulty = fsrs.nextDifficulty(d, rating)
            } else {
                // Only a new card (Learning with no memory yet) lands here.
                c.stability = fsrs.initialStability(rating)
                c.difficulty = fsrs.initialDifficulty(rating)
            }
            if list.isEmpty || (step >= list.count && rating != .again) {
                interval = graduate(&c)
            } else {
                switch rating {
                case .again:
                    c.step = 0
                    interval = list[0]
                case .hard:
                    c.step = step
                    if step == 0 { interval = list.count == 1 ? list[0] * 1.5 : (list[0] + list[1]) / 2 } else { interval = list[step] }
                case .good:
                    if step + 1 == list.count {
                        interval = graduate(&c)
                    } else {
                        c.step = step + 1
                        interval = list[step + 1]
                    }
                case .easy:
                    interval = graduate(&c)
                }
            }
        case .review:
            let s = card.stability ?? fsrs.initialStability(rating)
            let d = card.difficulty ?? fsrs.initialDifficulty(rating)
            c.stability = sameDay ? fsrs.shortTermStability(s, rating) : nextStability(d, s, r, rating)
            c.difficulty = fsrs.nextDifficulty(d, rating)
            if rating == .again {
                c.lapses += 1
                if steps.relearning.isEmpty {
                    interval = reviewInterval(c)
                } else {
                    c.state = .relearning
                    c.step = 0
                    interval = steps.relearning[0]
                }
            } else {
                interval = reviewInterval(c)
            }
        }
        c.due = now.addingTimeInterval(interval)
        c.lastReview = now
        c.reps += 1
        return c
    }

    /// Seconds until the next review for each rating, for "again in 1 min" style hints.
    public func previewIntervals(_ card: MemoryState, at now: Date) -> [Rating: TimeInterval] {
        var out: [Rating: TimeInterval] = [:]
        for rating in Rating.allCases {
            out[rating] = (review(card, rating: rating, at: now).due ?? now).timeIntervalSince(now).rounded()
        }
        return out
    }

    private func nextStability(_ d: Double, _ s: Double, _ r: Double, _ rating: Rating) -> Double {
        rating == .again ? fsrs.forgetStability(d, s, r) : fsrs.recallStability(d, s, r, rating)
    }

    private func graduate(_ c: inout MemoryState) -> TimeInterval {
        c.state = .review
        c.step = nil
        return reviewInterval(c)
    }

    private func reviewInterval(_ c: MemoryState) -> TimeInterval {
        Double(fsrs.nextInterval(c.stability ?? FSRS.stabilityMin)) * 86400
    }
}
