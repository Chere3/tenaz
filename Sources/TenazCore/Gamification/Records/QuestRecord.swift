import GRDB

/// One generated quest. Daily quests use their learning day; the weekly one uses the week's Monday.
public struct QuestRecord: Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "quest"

    public var id: String
    public var day: Int
    public var slot: QuestSlot
    public var template: String
    public var title: String
    public var metric: QuestMetric
    public var target: Int
    public var progress = 0
    public var done = false
    public var rewardXP: Int
    public var rewardScales: Int
    /// Stretch quests promise a cosmetic mystery drop; the roll itself is not implemented yet.
    public var mysteryDrop = false

    public init(day: Int, slot: QuestSlot, template: String, title: String, metric: QuestMetric,
                target: Int, rewardXP: Int, rewardScales: Int, mysteryDrop: Bool = false) {
        id = "\(day)-\(slot.rawValue)"
        self.day = day
        self.slot = slot
        self.template = template
        self.title = title
        self.metric = metric
        self.target = target
        self.rewardXP = rewardXP
        self.rewardScales = rewardScales
        self.mysteryDrop = mysteryDrop
    }
}
