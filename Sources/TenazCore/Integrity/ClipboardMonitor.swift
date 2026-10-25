import Foundation

/// Pure logic for polling `NSPasteboard.general.changeCount` at 2 Hz during an exam: any change is a flag.
public struct ClipboardMonitor: Sendable {
    private var last: Int?

    public init() {}

    /// The first call only records the baseline.
    public mutating func observe(changeCount: Int) -> ClipboardFlag? {
        defer { last = changeCount }
        guard let last, changeCount != last else { return nil }
        return ClipboardFlag(changes: abs(changeCount - last))
    }
}
