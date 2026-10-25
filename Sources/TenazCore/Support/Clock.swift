import Foundation

/// Injected time source so policies with timeouts and day boundaries can be tested instantly.
public protocol TenazClock: Sendable {
    var now: Date { get }
    func sleep(for duration: Duration) async throws
}

public struct SystemClock: TenazClock {
    public init() {}
    public var now: Date { Date() }
    public func sleep(for duration: Duration) async throws { try await Task.sleep(for: duration) }
}

/// Manual clock for tests: `sleep` returns immediately and advances time.
public final class TestClock: TenazClock, @unchecked Sendable {
    // Invariant: all access goes through `lock`.
    private let lock = NSLock()
    private var current: Date

    public init(_ start: Date = Date(timeIntervalSince1970: 1_792_000_000)) { current = start }

    public var now: Date { lock.lock(); defer { lock.unlock() }; return current }

    public func advance(by seconds: TimeInterval) { lock.lock(); current += seconds; lock.unlock() }

    public func sleep(for duration: Duration) async throws {
        let c = duration.components
        advance(by: Double(c.seconds) + Double(c.attoseconds) / 1e18)
    }
}

/// Learning days start at 04:00 local time, so a late-night session counts for "today".
public enum DayBoundary {
    public static let hour = 4

    /// `yyyymmdd` for the learning day containing `date`.
    public static func day(for date: Date, calendar: Calendar = .current) -> Int {
        let shifted = date.addingTimeInterval(-Double(hour) * 3600)
        let c = calendar.dateComponents([.year, .month, .day], from: shifted)
        return c.year! * 10000 + c.month! * 100 + c.day!
    }
}
