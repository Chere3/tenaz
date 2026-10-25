/// Turns `AchievementStats` into progress values and unlocks. Keys that need data no area
/// produces yet (Claude-graded writing/speaking, modes, paraphrases) return nil and stay locked.
public enum AchievementEvaluator {
    public static let supportedKeys: Set<String> = [
        "stage", "correctRetrievals", "gateParagraphs", "examsFinished", "notesIntroduced", "masteredNotes",
        "comebackRecalls", "leechesCleared", "longIntervalRecalls", "bestCombo", "paragraphs",
        "consecutiveExamsAtBand", "bestExamBand", "bestSectionBand", "cleanExams", "bestStreak", "freezesUsed",
        "weekendRun", "weeklyGoalRun", "repairsCompleted", "cosmeticsEquipped", "cosmeticsOwned", "nightReviews",
        "earlyDayRun", "phoenix", "qualifiedDaysWithoutMercy", "flyMentioned",
    ]

    /// Current value for the definition's condition, or nil when the key is not computable yet.
    public static func value(_ def: AchievementDefinition, _ s: AchievementStats) -> Double? {
        let exams = s.exams.filter { $0.integrity.isVerified && (def.kinds?.contains($0.kind) ?? true) }
        switch def.condition {
        case "stage": return Double(s.stage)
        case "correctRetrievals": return Double(s.correctRetrievals)
        case "gateParagraphs": return Double(s.gateParagraphs)
        case "examsFinished": return Double(exams.count)
        case "notesIntroduced": return Double(s.learning.notesIntroduced)
        case "masteredNotes": return Double(s.learning.masteredNotes)
        case "comebackRecalls": return Double(s.learning.comebackRecalls)
        case "leechesCleared": return Double(s.learning.leechesCleared)
        case "longIntervalRecalls": return Double(s.learning.longIntervalRecalls)
        case "bestCombo": return Double(s.bestCombo)
        case "paragraphs": return Double(s.paragraphs)
        case "consecutiveExamsAtBand":
            let band = def.band ?? 0
            var run = 0, best = 0
            for e in exams {
                run = e.band >= band ? run + 1 : 0
                best = max(best, run)
            }
            return Double(best)
        case "bestExamBand": return exams.map(\.band).max() ?? 0
        case "bestSectionBand": return exams.map { $0.sectionBands.max() ?? $0.band }.max() ?? 0
        case "cleanExams": return Double(exams.filter { $0.integrity == .clean }.count)
        case "bestStreak": return Double(s.bestStreak)
        case "freezesUsed": return Double(s.freezesUsed)
        case "weekendRun": return Double(s.weekendRun)
        case "weeklyGoalRun": return Double(s.weeklyGoalRun)
        case "repairsCompleted": return Double(s.repairsCompleted)
        case "cosmeticsEquipped": return Double(s.cosmeticsEquipped)
        case "cosmeticsOwned": return Double(s.cosmeticsOwned)
        case "nightReviews": return Double(s.nightReviews)
        case "earlyDayRun": return Double(s.earlyDayRun)
        case "phoenix": return s.phoenix ? 1 : 0
        case "qualifiedDaysWithoutMercy": return Double(s.qualifiedDaysWithoutMercy)
        case "flyMentioned": return s.flyMentioned ? 1 : 0
        default: return nil
        }
    }

    public static func isUnlocked(_ def: AchievementDefinition, _ s: AchievementStats) -> Bool {
        guard let v = value(def, s) else { return false }
        return v >= def.threshold
    }

    /// Definitions that are unlocked by `stats` and not in `alreadyUnlocked`.
    public static func newlyUnlocked(_ defs: [AchievementDefinition], stats: AchievementStats,
                                     alreadyUnlocked: Set<String>) -> [AchievementDefinition] {
        defs.filter { !alreadyUnlocked.contains($0.id) && isUnlocked($0, stats) }
    }
}
