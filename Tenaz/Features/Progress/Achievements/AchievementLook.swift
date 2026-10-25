import SwiftUI
import TenazCore

/// How an achievement is printed: rarity (from its reward, research 11 §6.6: single, double or
/// perforated border), ink by type, and a glyph by condition.
enum AchievementRarity: Int, Comparable {
    case common, rare, legendary

    init(xp: Int) {
        self = xp >= 150 ? .legendary : (xp >= 60 ? .rare : .common)
    }

    var title: String {
        switch self {
        case .common: "Common"
        case .rare: "Rare"
        case .legendary: "Legendary"
        }
    }

    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

enum AchievementLook {
    static func rarity(_ a: AchievementProgress) -> AchievementRarity { AchievementRarity(xp: a.definition.reward.xp) }

    static func typeTitle(_ kind: AchievementDefinition.Kind) -> String {
        switch kind {
        case .progress: "Progress"
        case .mastery: "Mastery"
        case .discovery: "Discovery"
        case .streak: "Streak"
        case .hidden: "Secret"
        }
    }

    static func fill(_ kind: AchievementDefinition.Kind) -> Color {
        switch kind {
        case .progress: Tokens.brand
        case .mastery: Tokens.correct
        case .discovery: Tokens.accent
        case .streak: Tokens.gold
        case .hidden: Tokens.ink
        }
    }

    static func glyphColor(_ kind: AchievementDefinition.Kind) -> Color {
        switch kind {
        case .progress, .mastery: Tokens.inverse
        case .discovery: Tokens.onAccent
        case .streak: Tokens.onGold
        case .hidden: Tokens.paper
        }
    }

    static func glyph(_ a: AchievementProgress) -> String {
        if a.definition.hidden, !a.isUnlocked { return "questionmark" }
        return glyphs[a.definition.condition] ?? "star.fill"
    }

    private static let glyphs: [String: String] = [
        "stage": "leaf.fill", "spokenGraded": "mic.fill", "correctRetrievals": "checkmark.circle.fill",
        "gateParagraphs": "lock.open.fill", "modesUsed": "square.grid.2x2.fill", "examsFinished": "flag.checkered",
        "notesIntroduced": "plus.rectangle.on.rectangle", "masteredNotes": "brain.head.profile",
        "comebackRecalls": "arrow.uturn.backward", "leechesCleared": "ladybug.fill", "longIntervalRecalls": "infinity",
        "bestCombo": "scope", "paragraphs": "text.alignleft", "cohesionB2Texts": "link", "errorFreeTexts": "checkmark.seal.fill",
        "connectorTexts": "point.3.connected.trianglepath.dotted", "standupB2": "person.wave.2.fill",
        "meetingRolePlayB2": "person.3.fill", "paraphraseSets": "arrow.triangle.2.circlepath", "registerPairs": "textformat.alt",
        "consecutiveExamsAtBand": "medal.fill", "bestExamBand": "rosette", "bestSectionBand": "crown.fill",
        "cleanExams": "shield.checkered", "speakingAboveAverage": "waveform", "bestStreak": "flame.fill",
        "freezesUsed": "snowflake", "weekendRun": "sun.max.fill", "weeklyGoalRun": "calendar",
        "repairsCompleted": "bandage.fill", "cosmeticsEquipped": "tshirt.fill", "cosmeticsOwned": "bag.fill",
        "nightReviews": "moon.stars.fill", "earlyDayRun": "sunrise.fill", "phoenix": "bird.fill",
        "codingExplained": "chevron.left.forwardslash.chevron.right", "qualifiedDaysWithoutMercy": "bolt.shield.fill",
        "flyMentioned": "ant.fill",
    ]

    /// "6 / 7", "Band 3.5 / 4.0" for exam bands, "0 / 2 exams at 3.0+" for exams in a row at a
    /// band, or "Not tracked yet" for areas not built.
    static func progressText(_ a: AchievementProgress) -> String {
        guard let value = a.value else { return "Not tracked yet" }
        let t = a.definition.threshold
        let condition = a.definition.condition
        if condition == "bestExamBand" || condition == "bestSectionBand" {
            return "Band \(min(value, t).formatted(.number.precision(.fractionLength(1)))) / \(t.formatted(.number.precision(.fractionLength(1))))"
        }
        if condition == "consecutiveExamsAtBand", let band = a.definition.band {
            return "\(Int(min(value, t))) / \(Int(t)) exams at \(band.formatted(.number.precision(.fractionLength(1))))+"
        }
        let unit = condition == "notesIntroduced" ? " met" : (condition == "masteredNotes" ? " mastered" : "")
        return "\(Int(min(value, t)).formatted()) / \(Int(t).formatted())\(unit)"
    }

    static func unlockedText(_ a: AchievementProgress) -> String? {
        a.unlockedAt.map { Date(unixMilliseconds: $0).formatted(.dateTime.month(.abbreviated).day()) }
    }
}
