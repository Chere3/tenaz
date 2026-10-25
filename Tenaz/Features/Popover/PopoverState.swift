import Foundation

/// What the menu-bar popover shows. The gamification and scheduling layers fill it; until they are
/// wired, `placeholder` stands in (the values from the wireframe in docs/research/11 §6.1).
struct PopoverState: Equatable {
    var mood: TenaMood
    var stage: TenaStage
    /// CEFR label of the current public band, e.g. "B1+".
    var levelLabel: String
    var streakDays: Int
    /// 0...100.
    var vitality: Double
    /// 0...100.
    var spirit: Double
    var dueCount: Int
    /// Tena's one line, plain and never shaming.
    var line: String
    /// The one primary button ("Review 12 words", "Placement test", "All done today").
    var primaryTitle = "Review"
    /// What the primary button does; the hero follows it so the screen never offers two next actions.
    var primary: HomePrimary = .review(count: 12)
    /// After 20:00 with today's minimum not yet done and a streak to lose.
    var streakAtRisk = false
    /// Intrusions are paused until this time ("Pause intrusions 1 h"), or nil.
    var pausedUntil: Date?
    /// The first due word, for Nagging's sign.
    var dueWord: String?

    /// The flood that tells the state: due = yellow, done = mint, streak at risk = oxblood, paused = paper.
    var flood: Flood? {
        if pausedUntil != nil { return nil }
        if streakAtRisk { return .risk }
        if case .allDone = primary { return .good }
        return .turn
    }

    static let placeholder = PopoverState(
        mood: .hungry,
        stage: .juvenile,
        levelLabel: "B1+",
        streakDays: 9,
        vitality: 62,
        spirit: 80,
        dueCount: 12,
        line: "12 words are hungry. Feed me?"
    )
}
