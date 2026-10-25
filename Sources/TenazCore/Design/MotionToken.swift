/// Motion tokens from docs/research/11-design-system.md §5.2. Every token collapses to the same
/// 0.2 s crossfade when Reduce Motion is on, so no screen has to remember to check it.
public enum MotionToken: String, CaseIterable, Sendable {
    /// Button press, selection.
    case tap
    /// Card appear, panel change, mood crossfade.
    case settle
    /// Correct-answer scale pop, badges.
    case pop
    /// Word enters the overlay, penalty hit (preceded by `hitStopMs`).
    case slam
    /// Tena's idle breathing (amplitude `floatAmplitude`).
    case float

    public static let reduced = MotionCurve.crossfade(duration: 0.20)
    public static let floatAmplitude = 4.0
    public static let slamHitStopMs = 3

    public var curve: MotionCurve {
        switch self {
        case .tap: .spring(duration: 0.18, bounce: 0.0)
        case .settle: .spring(duration: 0.35, bounce: 0.15)
        case .pop: .spring(duration: 0.45, bounce: 0.45)
        case .slam: .spring(duration: 0.30, bounce: 0.30)
        case .float: .loop(duration: 2.8)
        }
    }

    public func curve(reduceMotion: Bool) -> MotionCurve {
        reduceMotion ? Self.reduced : curve
    }
}
