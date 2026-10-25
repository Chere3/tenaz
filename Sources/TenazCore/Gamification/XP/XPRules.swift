import Foundation

/// XP only for verified retrieval and production, never for opening the app (PLAN F9).
public enum XPRules {
    /// A correct review: `10 × (1.0 + 0.6·(D-1)/9)`, D = FSRS difficulty clamped to 1...10.
    public static func review(difficulty: Double) -> Int {
        let d = min(max(difficulty, 1), 10)
        return Int((10 * (1.0 + 0.6 * (d - 1) / 9)).rounded())
    }

    /// Failed earlier in the session, then recalled: rewards recovery.
    public static let correctedAfterFail = 3

    /// A written or spoken production, 15-40 by quality (0...1, from Claude or the local floors).
    /// Quality below `minimumQuality` earns nothing (anti-farming).
    public static func production(quality: Double) -> Int {
        guard quality >= minimumQuality else { return 0 }
        return Int((15 + 25 * min(quality, 1)).rounded())
    }

    public static let minimumQuality = 0.2

    /// One exam section, 100-300 by band (TOEFL-style 1-6).
    public static func examSection(band: Double) -> Int {
        let b = min(max(band, 1), 6)
        return Int((100 + 40 * (b - 1)).rounded())
    }

    /// Quest rewards stay inside 50-150.
    public static func quest(_ reward: Int) -> Int { min(max(reward, 50), 150) }

    /// Anti-farming: the first two times an item pays out in a day are full, then each repeat halves.
    /// `priorToday` is how many times this item already earned XP today.
    public static func antiFarming(_ base: Int, priorToday: Int) -> Int {
        guard priorToday >= 2 else { return base }
        return Int((Double(base) * pow(0.5, Double(priorToday - 1))).rounded(.down))
    }

    /// The first 7 days are generous (×1.5). `dayIndex` 0 is the install day.
    public static func welcomeBonus(_ amount: Int, dayIndex: Int) -> Int {
        dayIndex < 7 ? Int((Double(amount) * 1.5).rounded()) : amount
    }
}
