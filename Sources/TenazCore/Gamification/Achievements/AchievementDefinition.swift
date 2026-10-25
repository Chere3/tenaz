import Foundation

/// One entry of `Content/achievements.json` (research 02 §5). Hidden ones show "???" until unlocked.
public struct AchievementDefinition: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case progress = "P", mastery = "M", discovery = "D", streak = "S", hidden = "H"
    }

    public struct Reward: Codable, Equatable, Sendable {
        public var xp: Int
        public var scales: Int
    }

    public var id: String
    public var name: String
    public var description: String
    public var type: Kind
    /// An `AchievementEvaluator` key; unknown keys stay locked until their area exists.
    public var condition: String
    public var threshold: Double
    public var reward: Reward
    public var hidden: Bool
    /// Exam conditions: the band to reach and which exam kinds count (nil = all).
    public var band: Double?
    public var kinds: [ExamCreditKind]?
    public var hint: String?

    public static func loadAll(from url: URL) throws -> [AchievementDefinition] {
        try JSONDecoder().decode([AchievementDefinition].self, from: Data(contentsOf: url))
    }
}
