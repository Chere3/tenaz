import Foundation

/// One row of the results-screen timeline.
public struct IntegrityTimelineEntry: Codable, Hashable, Sendable {
    public enum Severity: String, Codable, Sendable {
        case violation, warning, info
    }

    public var startTs: Int64
    public var endTs: Int64
    public var kind: String
    public var label: String
    public var severity: Severity
}
