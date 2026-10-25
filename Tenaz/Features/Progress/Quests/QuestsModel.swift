import Foundation
import TenazCore

/// What the Quests screen shows, taken from one `GamificationState`.
struct QuestsModel: Equatable {
    var quests: [QuestRecord]
    var weekly: QuestRecord?
    var mood: TenaMood
    var stage: TenaStage
    var streakDays: Int
    /// When the next 04:00 boundary is.
    var refreshAt: Date
    var now: Date

    static let empty = QuestsModel(quests: [], weekly: nil, mood: .neutral, stage: .juvenile, streakDays: 0,
                                   refreshAt: .distantFuture, now: .now)

    init(quests: [QuestRecord], weekly: QuestRecord?, mood: TenaMood, stage: TenaStage, streakDays: Int, refreshAt: Date, now: Date) {
        self.quests = quests
        self.weekly = weekly
        self.mood = mood
        self.stage = stage
        self.streakDays = streakDays
        self.refreshAt = refreshAt
        self.now = now
    }

    init(state: GamificationState, now: Date, calendar: Calendar = .current) {
        let start = DayBoundary.start(ofDayContaining: now, calendar: calendar)
        self.init(quests: state.quests, weekly: state.weeklyQuest, mood: ProgressMascot.mood(state.mood),
                  stage: ProgressMascot.stage(state.mascot.stage), streakDays: state.streak.daysPracticedLast7,
                  refreshAt: calendar.date(byAdding: .day, value: 1, to: start) ?? start, now: now)
    }

    var doneCount: Int { quests.filter(\.done).count }
    var core: QuestRecord? { quests.first { $0.slot == .core } }

    var refreshText: String {
        let minutes = max(0, Int(refreshAt.timeIntervalSince(now) / 60))
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? "in \(h) h \(m) min" : "in \(m) min"
    }

    /// Tena's one line: plain, warm, never shaming.
    var tenaLine: String {
        guard !quests.isEmpty else { return "Do one review for quests." }
        if doneCount == quests.count { return "All three! Great day." }
        if let core, !core.done {
            let left = max(0, core.target - core.progress)
            return core.progress == 0 ? "Start with the core quest."
                : "\(left) more \(left == 1 ? "review" : "reviews") to go!"
        }
        if quests.contains(where: { $0.slot == .skill && !$0.done }) { return "Core done! Write 2 sentences?" }
        return "Only the stretch is left."
    }
}

extension QuestsModel {
    /// The first quest not yet done, in slot order: what the one pill names.
    var nextUndone: QuestRecord? { quests.first { !$0.done } }
}
