/// The real safeguard for thin commitment-device evidence (PLAN F10): per rule, how often it
/// fired and how often the learner escaped it. A rule whose escape rate is above 60% in each of the
/// last two weeks is suggested for turning off at the weekly review.
public enum PenaltyExperimentLog {
    public static let escapeRateThreshold = 0.6

    public struct Stats: Equatable, Sendable {
        public var fired = 0
        public var dismissed = 0
        public var escaped = 0
        public var ledToSession = 0
        public var shown: Int { fired + dismissed + escaped }
        public var escapeRate: Double { shown == 0 ? 0 : Double(escaped) / Double(shown) }
    }

    public static func stats(_ events: [PenaltyEventRecord], rule: String, days: ClosedRange<Int>) -> Stats {
        var s = Stats()
        for e in events where e.ruleId == rule && days.contains(e.day) {
            switch e.outcome {
            case .fired: s.fired += 1
            case .dismissed: s.dismissed += 1
            case .escaped: s.escaped += 1
            case .waived: continue
            }
            if e.ledToSession { s.ledToSession += 1 }
        }
        return s
    }

    /// Rules (raw ids) to suggest disabling as of `today`.
    public static func suggestDisable(_ events: [PenaltyEventRecord], today: Int) -> [String] {
        let thisWeek = LearningDays.adding(-6, to: today)...today
        let lastWeek = LearningDays.adding(-13, to: today)...LearningDays.adding(-7, to: today)
        let rules = Set(events.map(\.ruleId)).sorted()
        return rules.filter { rule in
            [lastWeek, thisWeek].allSatisfy { week in
                let s = stats(events, rule: rule, days: week)
                return s.shown > 0 && s.escapeRate > escapeRateThreshold
            }
        }
    }
}
