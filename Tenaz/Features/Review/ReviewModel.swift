import Foundation
import Observation
import TenazCore

/// One review session, live: serves cards from `ReviewSession`, grades and saves every answer
/// (`ReviewStore.record`), sends it to the gamification engine, and drives the screen phases.
@Observable
final class ReviewModel {
    private(set) var state = ReviewViewState(phase: .loading)
    var typed = ""
    /// Called when the session ends with answers (refresh Today) or with none (leave the screen).
    @ObservationIgnored var onFinish: (_ answered: Int) -> Void = { _ in }

    @ObservationIgnored private let env: AppEnvironment
    @ObservationIgnored private var session: ReviewSession?
    @ObservationIgnored private var shownAt = Date.now
    @ObservationIgnored private var feedbackAt = Date.distantPast
    @ObservationIgnored private var failed: Set<String> = []
    @ObservationIgnored private var bestCombo = 0
    @ObservationIgnored private var startedBelowMinimum = false
    @ObservationIgnored private var checkpointShown = false
    @ObservationIgnored private var leveledUp = false
    @ObservationIgnored private var stageAdvanced = false
    @ObservationIgnored private var timer: Task<Void, Never>?

    /// Return within this window after feedback appears is ignored (key repeat, double submit).
    static let advanceDebounce: TimeInterval = 0.25
    /// A right answer moves on by itself after this long (tier S feedback stays under 1.2 s).
    static let autoAdvance: Duration = .milliseconds(1100)

    init(env: AppEnvironment) {
        self.env = env
    }

    // MARK: Lifecycle

    func start(now: Date = .now) {
        guard session == nil else { return }
        if let state = try? env.gamification?.state() {
            self.state.mood = TenaMood(rawValue: state.mood.rawValue) ?? .focused
            self.state.stage = TenaStage(rawValue: state.mascot.stage) ?? .juvenile
            self.state.progress.correctToday = state.today.correctRetrievals
        }
        startedBelowMinimum = state.progress.correctToday < StreakEngine.minCorrectRetrievals
        guard let store = env.reviewStore else {
            state.phase = .empty(message: "Tenaz could not open its database, so there is nothing to review.")
            return
        }
        do {
            let next = try store.startSession(book: PromptBook(vocab: env.content.vocab), surface: .session, now: now)
            guard !next.isFinished else {
                if let back = TodayLoader.comingBack(env.database, now: now) {
                    waitAndRestart(until: back.at)
                } else {
                    state.phase = .empty(message: "Today's set is done. New words arrive tomorrow at 4:00.")
                }
                return
            }
            session = next
            advance(now: now)
        } catch {
            NSLog("Tenaz: review session failed to start: \(error)")
            state.phase = .empty(message: "Something went wrong loading today's words. Try again in a minute.")
        }
    }

    /// Nothing is due yet, but learning-step words come back today: show the wait, then start a
    /// fresh session when they are due.
    private func waitAndRestart(until back: Date) {
        state.phase = .waiting(until: back)
        timer?.cancel()
        timer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0.5, back.timeIntervalSinceNow)))
            guard !Task.isCancelled, let self, case .waiting = self.state.phase, session == nil else { return }
            start()
        }
    }

    /// Shows the next card, the wait for a missed word, or the end.
    func advance(now: Date = .now) {
        timer?.cancel()
        guard var current = session else { return }
        if let item = current.next(now: now) {
            session = current
            typed = ""
            shownAt = now
            state.phase = .question(ReviewCardModel(item))
            refreshRemaining()
        } else if let back = current.nextReturn {
            session = current
            state.phase = .waiting(until: back)
            refreshRemaining()
            timer = Task { [weak self] in
                try? await Task.sleep(for: .seconds(max(0.5, back.timeIntervalSinceNow)))
                guard !Task.isCancelled, let self, case .waiting = self.state.phase else { return }
                advance()
            }
        } else {
            finish()
        }
    }

    // MARK: Answers

    func choose(_ index: Int) {
        guard case let .question(card) = state.phase, card.isChoice else { return }
        answer(.choice(index), mode: .choice, card: card, chosen: index)
    }

    /// Return: check a typed answer, or move on from feedback.
    func submit() {
        switch state.phase {
        case let .question(card) where !card.isChoice:
            let text = typed.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            if card.type == .production {
                answer(.graded(Self.localProductionRating(text, chunk: card.headword)), mode: .typed, card: card, typedText: text)
            } else {
                answer(.typed(text), mode: .typed, card: card, typedText: text)
            }
        case .feedback, .checkpoint:
            next()
        default:
            break
        }
    }

    /// "I don't know": show the answer now; it counts as a miss and comes back soon.
    func reveal() {
        guard case let .question(card) = state.phase else { return }
        switch card.type {
        case .recognition: answer(.choice(-1), mode: .choice, card: card, chosen: nil)
        case .production: answer(.graded(.again), mode: .typed, card: card)
        default: answer(.typed(""), mode: .typed, card: card)
        }
    }

    func next(now: Date = .now) {
        switch state.phase {
        case .feedback:
            guard now.timeIntervalSince(feedbackAt) >= Self.advanceDebounce else { return }
            let more = !(session?.isFinished ?? true)
            if more, startedBelowMinimum, !checkpointShown, state.progress.correctToday >= StreakEngine.minCorrectRetrievals {
                checkpointShown = true
                timer?.cancel()
                state.phase = .checkpoint
            } else {
                advance(now: now)
            }
        case .checkpoint:
            advance(now: now)
        default:
            break
        }
    }

    /// Esc / Stop: end the session now. Everything answered is already saved.
    func stop() {
        finish()
    }

    private func answer(_ answer: ReviewAnswer, mode: InputMode, card: ReviewCardModel, chosen: Int? = nil, typedText: String = "") {
        guard var current = session else { return }
        let now = Date.now
        let duration = max(0, Int(now.timeIntervalSince(shownAt) * 1000))
        let outcome: ReviewOutcome
        do {
            outcome = try current.submit(answer, durationMs: duration, inputMode: mode, at: now)
        } catch {
            NSLog("Tenaz: answer rejected for \(card.id): \(error)")
            return
        }
        session = current
        do { try env.reviewStore?.record(outcome) } catch { NSLog("Tenaz: review not saved: \(error)") }

        let correct = outcome.rating != .again
        var xp = 0
        if let engine = env.gamification {
            do {
                let review = AnsweredReview(cardId: card.id, correct: correct, difficulty: outcome.before.difficulty ?? 5,
                                            correctedAfterFail: correct && failed.contains(card.id))
                var effects = try engine.handle(.reviewAnswered(review))
                if card.type == .production, correct {
                    let words = typedText.split(whereSeparator: \.isWhitespace).count
                    let production = Production(refId: card.id, quality: outcome.rating == .good ? 0.7 : 0.4, words: words, text: typedText)
                    let more = try engine.handle(.productionDone(production))
                    effects.xp += more.xp
                    effects.leveledUp = effects.leveledUp || more.leveledUp
                    effects.stageAdvanced = effects.stageAdvanced || more.stageAdvanced
                }
                xp = effects.xp
                leveledUp = leveledUp || effects.leveledUp
                stageAdvanced = stageAdvanced || effects.stageAdvanced
            } catch {
                NSLog("Tenaz: XP not recorded: \(error)")
            }
        }
        if !correct { failed.insert(card.id) }

        var progress = state.progress
        progress.answered += 1
        progress.xp += xp
        progress.combo = correct ? progress.combo + 1 : 0
        if correct {
            progress.correct += 1
            progress.correctToday += 1
        }
        bestCombo = max(bestCombo, progress.combo)
        state.progress = progress
        refreshRemaining()

        let feedback = ReviewFeedback(correct: correct, nearMiss: outcome.match == .nearMiss, chosenOption: chosen, typed: typedText, xp: xp,
                                      backIn: outcome.comesBackAt.map { $0.timeIntervalSince(now) }, combo: progress.combo)
        state.phase = .feedback(card, feedback)
        feedbackAt = now
        if correct { scheduleAutoAdvance(cardId: card.id, at: now) }
    }

    private func scheduleAutoAdvance(cardId: String, at shown: Date) {
        timer?.cancel()
        timer = Task { [weak self] in
            try? await Task.sleep(for: Self.autoAdvance)
            guard !Task.isCancelled, let self, case let .feedback(card, _) = state.phase,
                  card.id == cardId, feedbackAt == shown else { return }
            next()
        }
    }

    private func refreshRemaining() {
        guard let session else { return }
        let onScreen = state.phase.card != nil && state.phase.feedback == nil ? 1 : 0
        state.progress.remaining = session.queue.count + session.relearn.count + onScreen
    }

    private func finish() {
        timer?.cancel()
        let answered = state.progress.answered
        defer { onFinish(answered) }
        let engineState = try? env.gamification?.state()
        state.phase = .done(ReviewSummary(
            answered: answered, correct: state.progress.correct, xp: state.progress.xp, bestCombo: bestCombo,
            correctToday: engineState?.today.correctRetrievals ?? state.progress.correctToday,
            productionsToday: engineState?.today.productions ?? 0, dayQualified: engineState?.today.qualified ?? false,
            leveledUp: leveledUp, level: engineState?.level.level ?? 1, stageAdvanced: stageAdvanced,
            stageName: engineState?.stageName ?? "", mood: Self.reaction(accuracy: answered > 0 ? Double(state.progress.correct) / Double(answered) : 0,
                                                                         answered: answered, qualified: engineState?.today.qualified ?? false),
            stage: engineState.flatMap { TenaStage(rawValue: $0.mascot.stage) } ?? state.stage,
            comingBack: session?.relearn.count ?? 0
        ))
        session = nil
    }

    // MARK: Rules

    /// Tena's reaction at the end: proud when the day counts, ecstatic at 90 %+, happy otherwise.
    static func reaction(accuracy: Double, answered: Int, qualified: Bool) -> TenaMood {
        if answered == 0 { return .neutral }
        if qualified { return .proud }
        if accuracy >= 0.9 { return .ecstatic }
        return accuracy >= 0.6 ? .happy : .curious
    }

    /// P cards until the Claude rubric is wired (M8): the chunk must appear in a sentence of 4+ words.
    static func localProductionRating(_ text: String, chunk: String) -> Rating {
        let words = text.split(whereSeparator: \.isWhitespace).count
        let uses = text.localizedCaseInsensitiveContains(chunk)
        if uses, words >= 4 { return .good }
        return uses ? .hard : .again
    }
}
