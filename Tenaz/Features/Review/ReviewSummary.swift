/// The end screen.
struct ReviewSummary: Equatable {
    var answered: Int
    var correct: Int
    var xp: Int
    var bestCombo: Int
    var correctToday: Int
    var productionsToday: Int
    var dayQualified: Bool
    var leveledUp = false
    var level = 1
    var stageAdvanced = false
    var stageName = ""
    var mood: TenaMood
    var stage: TenaStage
    /// Cards still waiting in learning steps (they come back later today).
    var comingBack = 0

    var accuracy: Double { answered > 0 ? Double(correct) / Double(answered) : 0 }
}
