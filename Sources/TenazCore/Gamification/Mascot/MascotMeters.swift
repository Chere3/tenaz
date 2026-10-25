/// Tena's two meters, 0-100 (PLAN F8). Vitality never drops below 15: she gets sick, never dies.
public enum MascotMeters {
    public static let start = 80
    public static let max = 100
    public static let vitalityFloor = 15
    public static let spiritFloor = 0
    public static let sickAtOrBelow = 30
    public static let sadBelow = 30

    // Spirit deltas.
    public static let correctRecall = 2
    public static let wrongRecall = -3
    public static let writing = 5
    public static let dailyDecayWithoutSession = -6

    // Vitality deltas.
    public static let missedDailyMinimum = -10
    /// +2 for every 5 reviews done in a day...
    public static let regainPerReviews = 2
    public static let reviewsPerRegain = 5
    /// ...up to the day's loss. Below the starting 80, at least this much a day, so a sick Tena can
    /// heal by reviewing even with the repair-task rule off (assumption: "up to the day's loss"
    /// alone would leave her stuck once the losses are in the past). Regain never lifts her above
    /// 80 except to win back today's loss.
    public static let minDailyRegainAllowance = 20
    /// Finishing a repair task brings Vitality back to at least this.
    public static let healedVitality = 50

    public static func clampVitality(_ v: Int) -> Int { Swift.min(Swift.max(v, vitalityFloor), max) }
    public static func clampSpirit(_ s: Int) -> Int { Swift.min(Swift.max(s, spiritFloor), max) }

    public static func isSick(vitality: Int) -> Bool { vitality <= sickAtOrBelow }

    /// Vitality regained by the `reviewsDone`-th review of the day (2 on every 5th), within the allowance.
    public static func regain(reviewsDone: Int, regainedToday: Int, lostToday: Int, vitality: Int) -> Int {
        guard reviewsDone > 0, reviewsDone % reviewsPerRegain == 0 else { return 0 }
        let recovering = vitality < start
        let allowance = Swift.max(lostToday, recovering ? minDailyRegainAllowance : 0)
        var amount = Swift.min(regainPerReviews, allowance - regainedToday)
        if regainedToday + amount > lostToday { amount = Swift.min(amount, start - vitality) }
        return Swift.max(0, amount)
    }
}
