import GRDB

/// The single row (id 1) holding Tena's state plus the engine's own bookkeeping.
public struct MascotStateRecord: Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "mascot_state"

    public var id = 1
    public var stage = 0
    /// Unix ms when the current stage was reached.
    public var stageSince: Int64
    public var vitality = MascotMeters.start
    public var spirit = MascotMeters.start
    /// JSON `{"owned": [...], "equipped": [...]}`; injury hides them in the UI, never deletes them.
    public var cosmetics = "{\"owned\":[],\"equipped\":[]}"
    public var repairActive = false
    public var repairReviews = 0
    public var repairParagraphDone = false
    public var healedAt: Int64?
    public var installedDay: Int
    /// Last learning day whose missed-minimum costs and freezes were settled.
    public var lastSettledDay: Int
    public var combo = 0
    public var bestCombo = 0
    public var questMultiplier = 1.0
    public var flyMentioned = false
    /// Highest mastered-note count seen; micro-growth follows it so it never regresses.
    public var masteredHighWater = 0
    /// Learning day the welcome-back +10 Vitality was last given (once per return).
    public var lastWelcomeBackDay: Int?

    public init(now: Int64, today: Int, yesterday: Int) {
        stageSince = now
        installedDay = today
        lastSettledDay = yesterday
    }
}
