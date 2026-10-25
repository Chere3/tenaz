/// One achievement as the UI shows it: hidden ones read "???" until unlocked.
public struct AchievementProgress: Equatable, Sendable, Identifiable {
    public var definition: AchievementDefinition
    public var unlockedAt: Int64?
    /// Current value of the condition, nil when it cannot be computed yet.
    public var value: Double?

    public var id: String { definition.id }
    public var isUnlocked: Bool { unlockedAt != nil }
    public var displayName: String { definition.hidden && !isUnlocked ? "???" : definition.name }
    public var fraction: Double {
        guard let value else { return 0 }
        return min(1, value / max(definition.threshold, 1e-9))
    }
}
