import GRDB

/// Unlock state of one achievement from `Content/achievements.json`.
public struct AchievementRecord: Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "achievement"

    public var id: String
    public var unlockedAt: Int64?
    public var progress: Double

    public init(id: String, unlockedAt: Int64?, progress: Double) {
        self.id = id
        self.unlockedAt = unlockedAt
        self.progress = progress
    }
}
