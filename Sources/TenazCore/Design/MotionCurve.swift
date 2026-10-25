/// A UI-framework-free description of an animation curve; the app maps it to a SwiftUI `Animation`.
public enum MotionCurve: Equatable, Sendable {
    case spring(duration: Double, bounce: Double)
    /// Ambient loop (Tena breathing): eases in and out forever, reversing.
    case loop(duration: Double)
    /// The only curve allowed under Reduce Motion: a short crossfade.
    case crossfade(duration: Double)
}
