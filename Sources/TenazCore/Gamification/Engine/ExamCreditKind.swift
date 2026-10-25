public enum ExamCreditKind: String, Codable, CaseIterable, Sendable {
    case placement, dailyCheck, weeklyMock, monthlyMock
}

extension ExamCreditKind {
    /// Maps the exam engine's kind to the gamification kind (raw values differ for historical reasons:
    /// achievements.json uses these names).
    public init(_ kind: ExamKind) {
        switch kind {
        case .placement: self = .placement
        case .daily: self = .dailyCheck
        case .weekly: self = .weeklyMock
        case .monthly: self = .monthlyMock
        }
    }
}
