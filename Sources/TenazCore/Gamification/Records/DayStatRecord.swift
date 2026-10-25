import GRDB

/// One learning day (`yyyymmdd`, 04:00 boundary): what was done and what it cost.
public struct DayStatRecord: Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "day_stat"

    public var day: Int
    public var correctRetrievals = 0
    public var reviewsDone = 0
    public var productions = 0
    public var qualified = false
    public var frozen = false
    public var minutesActive = 0
    public var firstActivityAt: Int64?
    public var vitalityLost = 0
    public var vitalityRegained = 0
    public var penaltyEvents = 0
    public var penaltyTaskMinutes = 0
    public var nightReviews = 0
    /// The kill switch or "Pause 1 h" was used: the day qualifies only if the minimum was done
    /// in-app, and no freeze can cover it (PLAN F9, F10 honest hatches).
    public var hatchUsed = false
    /// Uncorroborated "I'm in a meeting" claims today (the first 2 are free).
    public var meetingClaims = 0
    /// Set when the day has been settled (missed-minimum costs applied, freezes decided).
    public var closed = false

    public init(day: Int) { self.day = day }

    public var hadSession: Bool { reviewsDone > 0 || productions > 0 }
}
