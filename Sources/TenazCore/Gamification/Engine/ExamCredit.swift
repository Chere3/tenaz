/// A finished exam as gamification sees it. Only CLEAN and WARNING count for XP, streak and
/// achievements; VIOLATION and UNVERIFIABLE are kept for review only (PLAN F5).
public struct ExamCredit: Codable, Equatable, Sendable {
    public var attemptId: String?
    public var kind: ExamCreditKind
    /// Overall TOEFL-style band (1-6).
    public var band: Double
    public var sectionBands: [Double]
    public var integrity: ExamIntegrity
    /// Objective items answered correctly (streak retrieval credit when verified).
    public var correctItems: Int
    /// Written or spoken tasks completed (streak production credit when verified).
    public var productions: Int
    /// Below the target band (exam-stake rule).
    public var failed: Bool

    public init(attemptId: String? = nil, kind: ExamCreditKind, band: Double, sectionBands: [Double] = [],
                integrity: ExamIntegrity, correctItems: Int = 0, productions: Int = 0, failed: Bool = false) {
        self.attemptId = attemptId
        self.kind = kind
        self.band = band
        self.sectionBands = sectionBands
        self.integrity = integrity
        self.correctItems = correctItems
        self.productions = productions
        self.failed = failed
    }
}
