import Foundation

/// The maximum time each surface may stay on screen (PLAN §5.2 item 4), independent of the UI.
public enum SurfaceWatchdog {
    public static let overlay: Duration = .seconds(90)
    public static let gate: Duration = .seconds(5 * 60)
    public static let preannounce: Duration = .seconds(20)
    /// `--tenaz-smoke`: every surface closes within 3 s.
    public static let smoke: Duration = .milliseconds(2200)

    public static func limit(for surface: IntrusionSurface) -> Duration {
        surface == .overlay ? overlay : gate
    }

    /// Sleeps for `limit` on `clock`, then calls `fire` unless the task was cancelled (the surface
    /// closed first). Returns whether it fired.
    @discardableResult
    public static func run(clock: any TenazClock, limit: Duration, fire: @Sendable () async -> Void) async -> Bool {
        do { try await clock.sleep(for: limit) } catch { return false }
        guard !Task.isCancelled else { return false }
        await fire()
        return true
    }
}
