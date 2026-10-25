import Foundation

public struct ClipboardFlag: Hashable, Sendable {
    /// How many times the pasteboard changed since the last poll.
    public var changes: Int
}
