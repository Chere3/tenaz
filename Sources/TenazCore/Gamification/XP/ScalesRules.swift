/// Scales: the one cosmetic currency, about 1 per 10 XP, never below 0, no real money (PLAN F9).
public enum ScalesRules {
    /// Scales earned when total XP moves from `before` to `after` (exactly 1 per 10 XP over time).
    public static func earned(totalXPBefore before: Int, after: Int) -> Int {
        max(0, after / 10 - before / 10)
    }

    public static let missedDayCost = 20

    /// The change actually applied to `balance`, so the balance never goes negative.
    public static func clampedChange(_ change: Int, balance: Int) -> Int {
        max(change, -max(balance, 0))
    }
}
