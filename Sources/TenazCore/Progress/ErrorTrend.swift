/// One error-ledger category as the weekly review shows it.
public struct ErrorTrend: Equatable, Identifiable, Sendable {
    public var category: String
    public var name: String
    /// Total times seen.
    public var count: Int
    /// First seen in the review week.
    public var isNew: Bool
    /// Seen at least once in the review week.
    public var activeThisWeek: Bool
    /// The most recent example and its fix.
    public var example: String
    public var correction: String

    public var id: String { category }
}
