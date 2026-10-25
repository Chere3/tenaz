/// One presented thing in an exam section: a bank item, or a vocabulary card turned into a
/// 4-option cloze for the adaptive vocabulary probe.
public struct ExamTask: Hashable, Sendable, Identifiable {
    public enum Content: Hashable, Sendable {
        case item(ExamItem)
        /// The card's cloze sentence with shuffled options; `answer` is the correct option index.
        case vocab(VocabEntry, options: [String], answer: Int)
    }

    /// How the task is scored.
    public enum Scoring: Hashable, Sendable {
        case objective
        /// Listen & Repeat: word error rate mapped to 0-5.
        case wordErrorRate
        /// Writing or speaking, graded by Claude after submit.
        case claude(GradeKind)
    }

    public var content: Content
    public var sectionId: String
    /// The skill this task's evidence goes to (section skill if declared, else the item's own).
    public var skill: ExamSkill

    public var id: String {
        switch content {
        case let .item(item): item.id
        case let .vocab(entry, _, _): "vocab:\(entry.id)"
        }
    }

    public var item: ExamItem? { if case let .item(i) = content { i } else { nil } }

    public var level: CEFRLevel {
        switch content {
        case let .item(item): item.level
        case let .vocab(entry, _, _): entry.level
        }
    }

    public var difficulty: Double { AbilityEstimator.difficulty(for: level) }

    public var scoring: Scoring {
        guard let item else { return .objective }
        switch item.type {
        case .writeEmail, .writeDiscussion, .lifeParagraph: return .claude(.writing)
        case .interview: return .claude(.speaking)
        case .listenRepeat: return .wordErrorRate
        default: return .objective
        }
    }

    /// Builds the vocabulary-probe task with options shuffled by `rng`.
    public static func vocab(_ entry: VocabEntry, sectionId: String, skill: ExamSkill, rng: inout SeededRandom) -> ExamTask {
        let options = ([entry.answer] + entry.distractors).shuffled(using: &rng)
        let answer = options.firstIndex(of: entry.answer) ?? 0
        return ExamTask(content: .vocab(entry, options: options, answer: answer), sectionId: sectionId, skill: skill)
    }
}
