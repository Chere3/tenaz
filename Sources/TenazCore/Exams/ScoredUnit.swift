/// One piece of evidence for a skill posterior: a right/wrong answer or a 0-5 rubric score.
public struct ScoredUnit: Hashable, Sendable {
    public enum Outcome: Hashable, Sendable {
        case binary(Bool)
        case rubric(Double)
    }

    public var taskId: String
    public var skill: ExamSkill
    public var difficulty: Double
    /// Guessing floor c = 1/options for multiple choice, 0 for typed answers.
    public var guessing: Double
    /// < 1 for locally dependent units (the ten gaps of one Complete the Words passage).
    public var weight: Double
    public var outcome: Outcome

    public var isCorrect: Bool {
        switch outcome {
        case let .binary(c): c
        case let .rubric(s): s >= 3
        }
    }
}
