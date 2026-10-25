import Foundation
import TenazCore

/// What the Exams screen lists: the history, unfinished attempts, and when each exam opens.
struct ExamsOverviewState {
    enum Availability: Equatable {
        case open
        case locked(String)
    }

    struct Unfinished: Identifiable {
        var id: String
        var kind: ExamKind
        var started: Date
        var answered: Int
        var resumable: Bool
    }

    var history: [ExamAttemptSummary] = []
    var unfinished: [Unfinished] = []
    var placementDone: Date?
    var weekly: Availability = .locked("after your placement")
    var monthly: Availability = .locked("after your placement")
    var dailyDoneToday = false

    static func load(store: ExamStore?, now: Date = .now, calendar: Calendar = .current) -> ExamsOverviewState {
        guard let store else { return ExamsOverviewState() }
        var state = ExamsOverviewState()
        state.history = (try? store.history()) ?? []
        for attempt in (try? store.unfinishedAttempts()) ?? [] {
            let resumable = (try? store.isResumable(attempt, now: now)) ?? false
            if !resumable, attempt.kind != ExamKind.placement.rawValue {
                try? store.abandon(attempt.id, at: now)
                continue
            }
            let summary = state.history.first { $0.id == attempt.id }
            state.unfinished.append(Unfinished(id: attempt.id, kind: ExamKind(rawValue: attempt.kind) ?? .daily,
                                               started: Date(timeIntervalSince1970: Double(attempt.startedAt) / 1000),
                                               answered: summary?.answered ?? 0, resumable: resumable))
        }
        state.history.removeAll { h in state.unfinished.contains { $0.id == h.id } }
        let done = state.history.filter { $0.status == "done" }
        state.placementDone = done.filter { $0.kind == .placement }.map(\.startedAt).min()
        state.dailyDoneToday = done.contains { $0.kind == .daily && DayBoundary.day(for: $0.startedAt) == DayBoundary.day(for: now) }
        if let placed = state.placementDone {
            let weekday = calendar.component(.weekday, from: now) // 1 = Sunday ... 5 = Thursday
            state.weekly = [1, 5, 6, 7].contains(weekday) ? .open : .locked("opens Thursday")
            let lastMonthly = done.filter { $0.kind == .monthly }.map(\.startedAt).max()
            let opens = (lastMonthly ?? placed).addingTimeInterval(28 * 86_400)
            state.monthly = now >= opens ? .open : .locked("opens \(opens.formatted(.dateTime.month(.abbreviated).day()))")
        }
        return state
    }
}
