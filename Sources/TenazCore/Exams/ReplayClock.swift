import Foundation

/// The clock a resumed attempt runs on: it holds a fixed time while the stored answers are
/// replayed (so latencies and section times come back as they were), then follows the system
/// clock once `goLive()` is called.
public final class ReplayClock: TenazClock, @unchecked Sendable {
    // Invariant: `fixed` is only read or written while holding `lock`.
    private let lock = NSLock()
    private var fixed: Date?

    public init(start: Date) { fixed = start }

    public var now: Date {
        lock.lock()
        defer { lock.unlock() }
        return fixed ?? Date()
    }

    /// Moves the fixed time forward (replay only; ignored once live).
    public func advance(by seconds: TimeInterval) {
        lock.lock()
        if let f = fixed { fixed = f + seconds }
        lock.unlock()
    }

    public func goLive() {
        lock.lock()
        fixed = nil
        lock.unlock()
    }

    public func sleep(for duration: Duration) async throws { try await Task.sleep(for: duration) }
}
