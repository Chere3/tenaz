/// A Rasch-model learner of known ability, for checking that an exam recovers the truth
/// (`--tenaz-selftest placement-sim` and the tests). Each scored unit is right with
/// P = c + (1 - c) / (1 + e^-(theta - b)); writing and speaking get a placeholder text, so they
/// stay "grade pending" exactly as when Claude is unavailable.
public struct SimulatedLearner: Sendable {
    public var theta: Double
    public var rng: SeededRandom

    public init(theta: Double, seed: UInt64) {
        self.theta = theta
        rng = SeededRandom(seed: seed)
    }

    private mutating func knows(_ task: ExamTask, guessing c: Double) -> Bool {
        let p = AbilityEstimator.probabilityCorrect(theta: theta, difficulty: task.difficulty, guessing: c)
        return Double.random(in: 0..<1, using: &rng) < p
    }

    /// Correct index, or a different one when the learner gets it wrong.
    private mutating func choose(_ task: ExamTask, options: Int, answer: Int) -> Int {
        knows(task, guessing: 1 / Double(max(options, 1))) ? answer : (answer + 1) % max(options, 1)
    }

    public mutating func answer(_ task: ExamTask) -> ExamAnswer {
        switch task.content {
        case let .vocab(_, options, answer):
            return .choices([choose(task, options: options.count, answer: answer)])
        case let .item(item):
            switch item.type {
            case .completeWords:
                return .gaps(CompleteWordsParser.gaps(item.passage ?? "").map { knows(task, guessing: 0) ? $0.hidden : "x" })
            case .readDaily, .readAcademic, .listenConversation, .listenAnnouncement, .listenTalk:
                return .choices((item.questions ?? []).map { choose(task, options: $0.options.count, answer: $0.answer) })
            case .listenResponse, .grammarMC:
                return .choices([choose(task, options: item.options?.count ?? 4, answer: item.answer?.index ?? 0)])
            case .buildSentence:
                return .text(knows(task, guessing: 0) ? item.answer?.text ?? "" : (item.chunks ?? []).reversed().joined(separator: " "))
            case .listenRepeat:
                let words = (item.sentence ?? "").split(separator: " ")
                return .text(knows(task, guessing: 0) ? words.joined(separator: " ") : words.prefix(words.count / 2).joined(separator: " "))
            case .writeEmail, .writeDiscussion, .lifeParagraph:
                return .text("Simulated response for \(item.id).")
            case .interview:
                return .texts((item.interviewQuestions ?? []).map { _ in "Simulated answer." })
            }
        }
    }

    /// Answers every task of `session` until it is complete, advancing `clock` a little per task.
    public mutating func take(_ session: inout ExamSession, clock: TestClock, secondsPerTask: Double = 20) {
        while let task = session.currentTask {
            clock.advance(by: secondsPerTask)
            session.answer(answer(task))
        }
    }
}
