import Foundation

/// One row of the exam history: what the Exams screen lists.
public struct ExamAttemptSummary: Hashable, Sendable, Identifiable {
    public var id: String
    public var kind: ExamKind
    public var startedAt: Date
    public var endedAt: Date?
    /// running / done / void / abandoned
    public var status: String
    /// Overall band once every grade is in (nil while pending or for void attempts).
    public var overall: Double?
    public var low: Double?
    public var high: Double?
    /// Nil until the Tivra witness ran.
    public var integrity: IntegrityLevel?
    public var integrityConfirmed: Bool
    public var skillBands: [ExamSkill: Double]
    public var answered: Int

    public init(id: String, kind: ExamKind, startedAt: Date, endedAt: Date? = nil, status: String, overall: Double? = nil,
                low: Double? = nil, high: Double? = nil, integrity: IntegrityLevel? = nil, integrityConfirmed: Bool = false,
                skillBands: [ExamSkill: Double] = [:], answered: Int = 0) {
        self.id = id
        self.kind = kind
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.status = status
        self.overall = overall
        self.low = low
        self.high = high
        self.integrity = integrity
        self.integrityConfirmed = integrityConfirmed
        self.skillBands = skillBands
        self.answered = answered
    }
}
