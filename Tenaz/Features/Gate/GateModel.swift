import Foundation
import Observation
import TenazCore

/// The unlock gate's logic (F2): live local checks, unlock, the honest emergency skip, "Joining a
/// call", the 5-minute limit with a free idle timeout. Claude grades the paragraph after it closes.
@Observable
final class GateModel {
    static let maxOnScreen: TimeInterval = 5 * 60
    static let strictCountdown: TimeInterval = 10

    let prompt: GatePrompt
    let requirement: GateRequirement
    let price: GateSkipPrice
    let strict: Bool
    let shownAt: Date
    var text = ""
    private(set) var checks: GateCheckResult
    private(set) var phase = GatePhase.writing
    private(set) var typedAny = false
    /// Typed, then another app took the front: a timeout then counts as abandoned.
    var leftAfterTyping = false
    var onFinish: (IntrusionOutcome) -> Void = { _ in }

    private let inputGuard: EarlyInputGuard
    private let store: IntrusionStore?
    private let gamification: GamificationEngine?
    private var armTask: Task<Void, Never>?

    init(prompt: GatePrompt, requirement: GateRequirement = .standard, price: GateSkipPrice, strict: Bool,
         store: IntrusionStore?, gamification: GamificationEngine?, shownAt: Date = Date()) {
        self.prompt = prompt
        self.requirement = requirement
        self.price = price
        self.strict = strict
        self.store = store
        self.gamification = gamification
        self.shownAt = shownAt
        inputGuard = EarlyInputGuard(shownAt: shownAt)
        checks = .empty(requirement, chunk: prompt.chunk)
    }

    var deadline: Date { shownAt.addingTimeInterval(Self.maxOnScreen) }

    /// Seconds until the skip button appears in strict mode (0 when it is there).
    func skipWait(at now: Date) -> Int {
        strict ? max(0, Int((Self.strictCountdown - now.timeIntervalSince(shownAt)).rounded(.up))) : 0
    }

    func textChanged(_ new: String, now: Date = Date()) {
        if !inputGuard.acceptsTyping(at: now), !new.isEmpty, !typedAny {
            text = ""
            return
        }
        if !new.isEmpty { typedAny = true }
        checks = GateChecker.check(new, chunk: prompt.chunk, requirement: requirement)
        if phase == .skipArmed { phase = .writing }
    }

    /// Return / UNLOCK.
    func submit(now: Date = Date()) {
        guard phase == .writing || phase == .skipArmed, inputGuard.acceptsSubmit(at: now) else { return }
        checks = GateChecker.check(text, chunk: prompt.chunk, requirement: requirement)
        guard checks.passes else { return }
        _ = try? store?.saveGateParagraph(prompt: prompt, text: text, checks: checks, at: now)
        let quality = min(1, 0.4 + 0.3 * checks.progress + 0.3 * checks.typeTokenRatio)
        _ = try? gamification?.handle(.gateCompleted(Production(refId: prompt.id, quality: quality, words: checks.words, text: text)))
        phase = .unlocked
        finish(.completed, after: .milliseconds(1100))
    }

    /// Esc: once arms, twice opens the confirmation (after the strict countdown, if strict).
    func escape(now: Date = Date()) {
        switch phase {
        case .writing:
            guard skipWait(at: now) == 0 else { return }
            phase = .skipArmed
            armTask?.cancel()
            armTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(2.5))
                guard !Task.isCancelled, let self, self.phase == .skipArmed else { return }
                self.phase = .writing
            }
        case .skipArmed: phase = .confirmingSkip
        case .confirmingSkip: phase = .writing
        default: break
        }
    }

    func openSkip(now: Date = Date()) {
        guard skipWait(at: now) == 0, phase == .writing || phase == .skipArmed else { return }
        phase = .confirmingSkip
    }

    func cancelSkip() { if phase == .confirmingSkip { phase = .writing } }

    /// The skip always works; it is only priced (and only when Response cost is on).
    func confirmSkip(useMercy: Bool) {
        guard phase == .confirmingSkip else { return }
        _ = try? gamification?.handle(.gateSkipped(useMercy: useMercy))
        onFinish(.skipped)
    }

    /// "Joining a call": free, closes now, gates wait 60 min.
    func joiningCall() { onFinish(.deferredMeeting) }

    /// 5 minutes are up. Idle and untouched is free; typed then left costs under Response cost.
    func timeUp() {
        guard phase != .unlocked, phase != .later else { return }
        let abandoned = typedAny && leftAfterTyping
        phase = .later
        _ = try? gamification?.handle(.gateTimedOut(abandoned: abandoned))
        finish(abandoned ? .timeoutAbandoned : .timeoutIdle, after: .milliseconds(1800))
    }

    func preview(text: String, phase: GatePhase = .writing) {
        self.text = text
        checks = GateChecker.check(text, chunk: prompt.chunk, requirement: requirement)
        self.phase = phase
    }

    private func finish(_ outcome: IntrusionOutcome, after delay: Duration) {
        Task { [weak self] in
            try? await Task.sleep(for: delay)
            self?.onFinish(outcome)
        }
    }
}
