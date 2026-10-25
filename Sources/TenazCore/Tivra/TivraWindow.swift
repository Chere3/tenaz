import Foundation

/// A time window in Unix milliseconds, the unit Tivra stores everywhere.
public struct TivraWindow: Codable, Hashable, Sendable {
    public var startTs: Int64
    public var endTs: Int64

    public init(startTs: Int64, endTs: Int64) {
        self.startTs = startTs
        self.endTs = endTs
    }

    public init(start: Date, end: Date) {
        self.init(startTs: Int64(start.timeIntervalSince1970 * 1000), endTs: Int64(end.timeIntervalSince1970 * 1000))
    }

    /// Milliseconds of `[start, end]` that fall inside the window.
    public func overlapMs(start: Int64, end: Int64) -> Int64 {
        max(0, min(end, endTs) - max(start, startTs))
    }
}
