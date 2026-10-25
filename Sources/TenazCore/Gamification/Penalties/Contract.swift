import Foundation

/// The learner's Contract: which rules are in force at a moment, from the append-only `penalty_rule`
/// rows. Every rule is off until the learner turns it on. The delay is asymmetric (PLAN F10): tightening
/// takes effect at the next 04:00 boundary, loosening 24 h after it is asked for, so nothing can be
/// bargained away in the moment. Kill switch, "Pause 1 h", quiet hours and every hatch are not
/// Contract changes and stay instant.
public struct Contract: Equatable, Sendable {
    public static let loosenDelayMs: Int64 = 24 * 3600 * 1000

    public var changes: [PenaltyRuleRecord]

    public init(changes: [PenaltyRuleRecord]) {
        self.changes = changes.filter { !$0.pendingCancelled }
            .sorted { ($0.effectiveAt, $0.createdAt) < ($1.effectiveAt, $1.createdAt) }
    }

    /// A new change requested at `now`; `nextBoundary` is the next 04:00 in Unix ms. Turning a rule
    /// on tightens and turning it off loosens; a parameter change on a rule that stays on must say
    /// which it is (`tightens`), and is treated as loosening when unsure. Returns nil for a rule
    /// that cannot be enabled.
    public func change(_ kind: PenaltyRuleKind, enabled: Bool, params: String = "{}", tightens: Bool? = nil,
                       at now: Int64, nextBoundary: Int64) -> PenaltyRuleRecord? {
        if enabled, !kind.canBeEnabled { return nil }
        let wasOn = isActive(kind, at: now)
        let direction: ChangeDirection
        if enabled != wasOn {
            direction = enabled ? .tighten : .loosen
        } else {
            direction = tightens == true ? .tighten : .loosen
        }
        let effective = direction == .tighten ? nextBoundary : now + Self.loosenDelayMs
        return PenaltyRuleRecord(kind: kind, enabled: enabled, params: params, createdAt: now,
                                 effectiveAt: effective, direction: direction)
    }

    /// The change in force for `kind` at `now` (shown as "You chose this on <createdAt>").
    public func inForce(_ kind: PenaltyRuleKind, at now: Int64) -> PenaltyRuleRecord? {
        changes.last { $0.kind == kind && $0.effectiveAt <= now }
    }

    public func isActive(_ kind: PenaltyRuleKind, at now: Int64) -> Bool {
        kind.canBeEnabled && (inForce(kind, at: now)?.enabled ?? false)
    }

    /// Changes made but not yet in force (shown with a countdown and a cancel button).
    public func pending(at now: Int64) -> [PenaltyRuleRecord] { changes.filter { $0.effectiveAt > now } }

    /// Every rule off: the shipped default.
    public static let empty = Contract(changes: [])
}
