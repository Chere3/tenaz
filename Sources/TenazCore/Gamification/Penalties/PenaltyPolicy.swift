/// Prices a penalty under the safety caps (PLAN F10, section 2 row 4, section 5.2 item 9):
/// at most -30 Vitality a day, at most 5 minutes of penalty tasks a day, recovery mode after 3
/// penalty events (no more penalties today), nothing on a welcome-back day. A penalty is only
/// ever priced or waived; an escape hatch is never refused.
public enum PenaltyPolicy {
    public static let dailyVitalityCap = 30
    public static let dailyTaskMinutesCap = 5
    public static let recoveryAfterEvents = 3
    public static let mercyTokensPerMonth = 3
    /// Soft freeze: after this many missed days in a row the drain stops until the learner comes back.
    public static let softFreezeAfterMissedDays = 2
    /// The welcome-back day (3+ missed days) gives back this much Vitality, once.
    public static let welcomeBackVitality = 10
    /// Uncorroborated "I'm in a meeting" claims that stay free each day.
    public static let freeMeetingClaimsPerDay = 2

    public struct Day: Equatable, Sendable {
        public var vitalityLost = 0
        public var penaltyEvents = 0
        public var taskMinutes = 0
        public var welcomeBack = false

        public init(vitalityLost: Int = 0, penaltyEvents: Int = 0, taskMinutes: Int = 0, welcomeBack: Bool = false) {
            self.vitalityLost = vitalityLost
            self.penaltyEvents = penaltyEvents
            self.taskMinutes = taskMinutes
            self.welcomeBack = welcomeBack
        }

        public var recoveryMode: Bool { penaltyEvents >= PenaltyPolicy.recoveryAfterEvents }
    }

    public struct Decision: Equatable, Sendable {
        public var vitality = 0
        public var scales = 0
        public var mercyUsed = false
        public var outcome: PenaltyOutcome = .waived
        /// Counts toward the 3-event recovery threshold.
        public var countsAsEvent: Bool { outcome != .waived }
    }

    /// `ruleActive` says whether the cost's rule is in force; `mercyLeft` is this month's tokens.
    public static func price(_ cost: PenaltyCost, day: Day, ruleActive: Bool, wantsMercy: Bool = false,
                             mercyLeft: Int = 0, escaped: Bool = false) -> Decision {
        var d = Decision()
        if !ruleActive { return d }
        if day.welcomeBack || day.recoveryMode { return d }
        var vitality = cost.vitality
        if cost == .gateSkip, wantsMercy, mercyLeft > 0 {
            vitality = PenaltyCost.gateSkipWithMercy
            d.mercyUsed = true
        }
        let room = max(0, dailyVitalityCap - day.vitalityLost)
        d.vitality = max(vitality, -room)
        d.scales = cost.scales
        d.outcome = escaped ? .escaped : .fired
        return d
    }

    /// Whether a penalty task of `minutes` still fits in today's 5-minute budget.
    public static func taskFits(minutes: Int, day: Day) -> Bool {
        !day.welcomeBack && !day.recoveryMode && day.taskMinutes + minutes <= dailyTaskMinutesCap
    }

    /// Tokens left this month after `usedThisMonth`.
    public static func mercyLeft(usedThisMonth: Int) -> Int { max(0, mercyTokensPerMonth - usedThisMonth) }
}
