import Foundation
import Observation
import TenazCore

/// One batch of up to 3 words on the overlay (F1): grade each answer, save it, award XP, show the
/// reward or the penalty, and end with an outcome. No UI and no window code here.
@Observable
final class OverlayModel {
    let mode: OverlayMode
    private(set) var items: [SessionItem]
    private(set) var index = 0
    private(set) var phase = OverlayPhase.asking
    var text = ""
    var showHint = false
    private(set) var correctCount = 0
    private(set) var xpTotal = 0
    private(set) var earlyInputSeen = false
    let skipCost: Int
    let snoozesLeft: Int
    let shownAt: Date
    /// Ends the surface with an outcome (the coordinator logs and closes).
    var onFinish: (IntrusionOutcome) -> Void = { _ in }
    /// Penalties charged by this surface, refunded if a meeting closes it.
    private(set) var appliedPenaltyIds: [Int64] = []

    private var session: ReviewSession
    private let reviewStore: ReviewStore?
    private let gamification: GamificationEngine?
    private let inputGuard: EarlyInputGuard
    private var questionShownAt: Date
    private var failedCardIds: Set<String> = []
    private var advanceTask: Task<Void, Never>?

    init(items: [SessionItem], mode: OverlayMode, reviewStore: ReviewStore?, gamification: GamificationEngine?,
         skipCost: Int, snoozesLeft: Int, shownAt: Date = Date()) {
        self.items = items
        self.mode = mode
        self.reviewStore = reviewStore
        self.gamification = gamification
        self.skipCost = skipCost
        self.snoozesLeft = snoozesLeft
        self.shownAt = shownAt
        questionShownAt = shownAt
        inputGuard = EarlyInputGuard(shownAt: shownAt)
        session = ReviewSession(items: items, surface: .overlay)
        _ = session.next(now: shownAt)
    }

    var current: SessionItem? { items.indices.contains(index) ? items[index] : nil }
    var total: Int { items.count }

    /// Typing in the first 600 ms is discarded (keys meant for another app).
    func textChanged(_ new: String, now: Date = Date()) {
        guard !inputGuard.acceptsTyping(at: now), !new.isEmpty else { return }
        earlyInputSeen = true
        text = ""
    }

    /// Return: grade the typed answer, or move on from a wrong answer.
    func submit(now: Date = Date()) {
        switch phase {
        case .wrong: advance()
        case .asking:
            guard inputGuard.acceptsSubmit(at: now), let item = current, item.prompt.type != .recognition else { return }
            let typed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !typed.isEmpty else { return }
            grade(.typed(typed), given: typed, item: item, mode: .typed, now: now)
        default: break
        }
    }

    /// 1-4 or a click on a recognition option.
    func choose(_ option: Int, now: Date = Date()) {
        guard phase == .asking, inputGuard.acceptsSubmit(at: now), let item = current, item.prompt.type == .recognition,
              item.prompt.options.indices.contains(option) else { return }
        grade(.choice(option), given: item.prompt.options[option], item: item, mode: .choice, now: now)
    }

    func toggleHint() { if phase == .asking { showHint.toggle() } }

    func escape(_ action: OverlayEscape) {
        advanceTask?.cancel()
        switch action {
        case .skip:
            if let fx = try? gamification?.handle(.overlaySkipped), let id = fx.penalty?.eventId { appliedPenaltyIds.append(id) }
            onFinish(.skipped)
        case .snooze: onFinish(.snoozed)
        case .meeting: onFinish(.deferredMeeting)
        }
    }

    /// A meeting started while the overlay was up: give back anything this batch charged.
    func refundPenalties() {
        for id in appliedPenaltyIds { _ = try? gamification?.handle(.penaltyRefunded(eventId: id)) }
        appliedPenaltyIds.removeAll()
    }

    private func grade(_ answer: ReviewAnswer, given: String, item: SessionItem, mode: InputMode, now: Date) {
        let ms = Int(now.timeIntervalSince(questionShownAt) * 1000)
        guard let outcome = try? session.submit(answer, durationMs: ms, inputMode: mode, at: now) else { return }
        try? reviewStore?.record(outcome)
        let correct = outcome.rating != .again
        let fx = try? gamification?.handle(.reviewAnswered(AnsweredReview(
            cardId: item.card.id, correct: correct, difficulty: item.card.difficulty ?? 5,
            correctedAfterFail: correct && failedCardIds.contains(item.card.id), usedHint: showHint)))
        if correct {
            correctCount += 1
            let xp = fx?.xp ?? 0
            xpTotal += xp
            phase = .correct(xp: xp)
            scheduleAdvance(after: .milliseconds(850))
        } else {
            failedCardIds.insert(item.card.id)
            phase = .wrong(expected: item.prompt.expected ?? item.prompt.correctOption.map { item.prompt.options[$0] } ?? "", given: given)
            scheduleAdvance(after: .seconds(4))
        }
    }

    private func scheduleAdvance(after delay: Duration) {
        advanceTask?.cancel()
        advanceTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.advance()
        }
    }

    private func advance() {
        advanceTask?.cancel()
        text = ""
        showHint = false
        if index + 1 < items.count {
            index += 1
            _ = session.next(now: Date())
            questionShownAt = Date()
            phase = .asking
        } else {
            phase = .done(correct: correctCount, total: items.count, xp: xpTotal)
            advanceTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(1400))
                guard !Task.isCancelled, let self else { return }
                self.onFinish(.completed)
            }
        }
    }

    /// A finished state for snapshots.
    func preview(_ phase: OverlayPhase, text: String = "", index: Int = 0) {
        self.phase = phase
        self.text = text
        self.index = min(index, max(0, items.count - 1))
    }
}
