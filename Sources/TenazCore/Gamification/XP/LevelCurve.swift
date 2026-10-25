import Foundation

/// `xpToNext(L) = round(60 + 40·L^1.4)`. The level is a pure function of total XP, and total XP
/// only grows, so the level never decreases.
public enum LevelCurve {
    public static func xpToNext(_ level: Int) -> Int {
        Int((60 + 40 * pow(Double(max(level, 1)), 1.4)).rounded())
    }

    public static func progress(totalXP: Int) -> LevelProgress {
        var level = 1
        var remaining = max(totalXP, 0)
        while remaining >= xpToNext(level) {
            remaining -= xpToNext(level)
            level += 1
        }
        return LevelProgress(level: level, xpIntoLevel: remaining, xpForLevel: xpToNext(level), totalXP: max(totalXP, 0))
    }
}
