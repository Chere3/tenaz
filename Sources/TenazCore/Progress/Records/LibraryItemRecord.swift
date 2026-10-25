import GRDB

/// The learner's status on one catalog item (`library_item`).
public struct LibraryItemRecord: Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "library_item"

    public var itemId: String
    public var status: LibraryStatus
    public var startedAt: Int64
    public var updatedAt: Int64
    public var finishedAt: Int64?
    /// "tooHard", "boring" or "noTime" (one tap, research 08 §6.4).
    public var abandonReason: String?

    public init(itemId: String, status: LibraryStatus, startedAt: Int64, updatedAt: Int64) {
        self.itemId = itemId
        self.status = status
        self.startedAt = startedAt
        self.updatedAt = updatedAt
    }
}
