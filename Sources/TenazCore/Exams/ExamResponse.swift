import Foundation

/// The learner's answer to one task, with the active (unpaused) time it took.
public struct ExamResponse: Codable, Hashable, Sendable {
    public var taskId: String
    public var sectionId: String
    public var answer: ExamAnswer?
    public var latencyMs: Int
    public var answeredAt: Date
}
