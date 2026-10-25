import Foundation

/// Finds the work boundaries that may start a word overlay (F1): switching apps after 25+ minutes in
/// one app (it waits for hyperfocus to end instead of breaking it), and coming back after 5+ minutes idle.
public struct ActivityTracker: Sendable {
    public static let singleAppMinutes = 25.0
    public static let idleMinutes = 5.0

    public private(set) var frontmost: String?
    public private(set) var frontmostSince: Date?
    public private(set) var wasIdle = false

    public init() {}

    /// A new app came to the front. Returns `.appSwitch` when the previous one had 25+ minutes.
    public mutating func activated(_ bundleId: String?, at now: Date) -> IntrusionTrigger? {
        defer {
            frontmost = bundleId
            frontmostSince = now
        }
        guard let since = frontmostSince, bundleId != frontmost else { return nil }
        return now.timeIntervalSince(since) >= Self.singleAppMinutes * 60 ? .appSwitch : nil
    }

    /// Called about every 30 s with the seconds since the last input. Returns `.idleReturn` once,
    /// on the first check after a 5+ minute absence ends.
    public mutating func idle(seconds: Double) -> IntrusionTrigger? {
        if seconds >= Self.idleMinutes * 60 {
            wasIdle = true
            return nil
        }
        if wasIdle, seconds < 30 {
            wasIdle = false
            return .idleReturn
        }
        return nil
    }
}
