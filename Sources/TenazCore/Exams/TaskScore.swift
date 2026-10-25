/// What gets stored in `exam_response` for one task.
public struct TaskScore: Hashable, Sendable {
    public var taskId: String
    public var sectionId: String
    public var skill: ExamSkill
    public var correct: Bool?
    public var scoreRaw: Double?
    public var scoreMax: Double?
    /// objective / wer / claude (pending) / local (empty answer scored 0 without Claude)
    public var source: String
}
