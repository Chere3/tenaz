/// Result of a promotion check. There is no demotion case: the public band never goes down.
public enum PromotionDecision: Hashable, Sendable {
    case promote(from: Double, to: Double)
    case hold(reasons: [String])
}
