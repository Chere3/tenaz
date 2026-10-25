import TenazCore

/// Everything Today, the sidebar header and the menu-bar popover show, as one plain value.
/// `TodayLoader` builds it from the live stores; snapshots use the samples.
struct TodaySummary: Equatable {
    var mood: TenaMood
    var stage: TenaStage
    var stageName: String
    /// The public band after the placement test, nil before it.
    var band: Double?
    var catchingUp = false
    var streakDays: Int
    var bestStreak: Int
    /// Qualified days, oldest first, today last (7 values).
    var last7: [Bool]
    var vitality: Int
    var spirit: Int
    var level: Int
    var xpIntoLevel: Int
    var xpForLevel: Int
    var correctToday: Int
    var productionsToday: Int
    var qualifiedToday: Bool
    /// Cards left in today's set (never the raw due number).
    var todaySetCount: Int
    /// Learning-step words that come back later today.
    var comingBack: TodayComingBack?
    var quests: [TodayQuest]
    var write: TodayWritePrompt?
    var placementTaken: Bool
    var placementInProgress = false
    var placementMinutes: Int
    var placementParts = 7
    var dailyCheckMinutes = 8
    var welcomeBack = false

    var primary: HomePrimary {
        HomePrimary.decide(placementTaken: placementTaken, placementInProgress: placementInProgress,
                           placementMinutes: placementMinutes, todaySetCount: todaySetCount, comingBack: comingBack)
    }

    /// CEFR label of the measured band, or the B1+ starting estimate.
    var levelLabel: String {
        AbilityEstimator.cefr(forBand: band ?? StageEvidence.englishLevelPriorBand).label
    }

    var daysPracticedLast7: Int { last7.count(where: \.self) }

    var minimumCorrect: Int { StreakEngine.minCorrectRetrievals }
    var minimumProductions: Int { StreakEngine.minProductions }

    var glyphState: TenaGlyphState { TenaGlyphState(mood: mood, dueCount: placementTaken ? todaySetCount : 0) }

    /// Tena's one line: plain B1 English, never shaming.
    var line: String {
        if stage == .egg { return "Tap me to hatch. Let's start!" }
        if welcomeBack { return "Welcome back! One minute is enough to restart." }
        switch primary {
        case let .placement(minutes, inProgress):
            return inProgress ? "Let's finish your test. Your answers are saved." : "First, find your level: about \(minutes) min."
        case let .review(count):
            if mood == .hungry || mood == .nagging { return "\(count) words are hungry. Feed me?" }
            return count <= 5 ? "Only \(count) left. Easy!" : "\(count) words are ready for you."
        case let .comeBack(count, at):
            return "\(count == 1 ? "One word comes" : "\(count) words come") back at \(at.formatted(date: .omitted, time: .shortened)). Seeing them again helps!"
        case .allDone:
            if correctToday >= minimumCorrect, productionsToday < minimumProductions { return "Great! Now write one sentence for me." }
            return qualifiedToday ? "Done for today. I'm proud of you!" : "Words done. See you tomorrow!"
        }
    }
}
