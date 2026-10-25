/// Adaptive quest targets (PLAN F9): over the last 7 days, >85% of skill/stretch quests done
/// raises targets 10%; <50% lowers them 15%. The multiplier stays within 0.5...2.0.
public enum QuestTuning {
    public static let raiseAbove = 0.85
    public static let lowerBelow = 0.50
    public static let minQuestsToAdapt = 3
    public static let range = 0.5...2.0

    public static func nextMultiplier(_ current: Double, done: Int, total: Int) -> Double {
        guard total >= minQuestsToAdapt else { return current }
        let rate = Double(done) / Double(total)
        var next = current
        if rate > raiseAbove { next = current * 1.10 } else if rate < lowerBelow { next = current * 0.85 }
        return min(max(next, range.lowerBound), range.upperBound)
    }

    public static func scaled(_ base: Int, by multiplier: Double) -> Int {
        max(1, Int((Double(base) * multiplier).rounded()))
    }
}
