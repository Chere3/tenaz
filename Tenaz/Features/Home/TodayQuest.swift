/// One of today's quests as Home shows it.
struct TodayQuest: Equatable, Identifiable {
    var id: String
    var title: String
    var progress: Int
    var target: Int
    var done: Bool
    var rewardXP: Int

    var fraction: Double { target > 0 ? min(1, Double(progress) / Double(target)) : 0 }
}
