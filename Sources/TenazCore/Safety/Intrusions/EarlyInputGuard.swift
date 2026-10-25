import Foundation

/// Keystrokes meant for another app must never be graded (PLAN F1, critique #9): input in the first
/// 600 ms after a surface appears is discarded, and Return does not submit during the first second.
public struct EarlyInputGuard: Sendable {
    public static let inertSeconds = 0.6
    public static let submitLockSeconds = 1.0
    /// Show only after this long with no key pressed anywhere.
    public static let quietBeforeShowSeconds = 2.0

    public var shownAt: Date

    public init(shownAt: Date) { self.shownAt = shownAt }

    public func acceptsTyping(at now: Date) -> Bool { now.timeIntervalSince(shownAt) >= Self.inertSeconds }
    public func acceptsSubmit(at now: Date) -> Bool { now.timeIntervalSince(shownAt) >= Self.submitLockSeconds }

    /// Typing elsewhere just before the surface appeared: wait.
    public static func canShow(secondsSinceLastKey: Double) -> Bool { secondsSinceLastKey >= quietBeforeShowSeconds }
}
