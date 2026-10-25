import Foundation

/// Database timestamps are Unix milliseconds (PLAN §4.3).
public extension Date {
    var unixMilliseconds: Int64 { Int64((timeIntervalSince1970 * 1000).rounded()) }

    init(unixMilliseconds ms: Int64) { self.init(timeIntervalSince1970: Double(ms) / 1000) }
}
