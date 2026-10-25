/// Where the learner is on the level curve.
public struct LevelProgress: Equatable, Sendable {
    public var level: Int
    public var xpIntoLevel: Int
    public var xpForLevel: Int
    public var totalXP: Int

    public var fraction: Double { Double(xpIntoLevel) / Double(max(xpForLevel, 1)) }
}
