/// A writing or speaking response waiting for Claude (graded after submit, never during the exam).
public struct PendingGrade: Hashable, Sendable {
    public var taskId: String
    public var skill: ExamSkill
    public var kind: GradeKind
    /// The task as Claude sees it (situation + bullet tasks, discussion posts, interview questions).
    public var prompt: String
    public var text: String
    /// Typed instead of spoken (no microphone).
    public var typed: Bool
}
