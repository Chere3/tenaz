/// Picks one mood from the context by a fixed priority. Asleep wins over everything (it is the
/// "never interrupts" state); then healing states, then celebrations, then needs, then baseline.
public enum MoodResolver {
    public static let hungryAtDue = 10
    public static let naggingAfterOverdueHours = 24.0
    public static let happyVitality = 70
    public static let happySpirit = 60

    public static func mood(_ c: MoodContext) -> MascotMood {
        if c.asleep { return .asleep }
        if c.repairInProgress { return .regenerating }
        if MascotMeters.isSick(vitality: c.vitality) { return .sick }
        if c.justHealed { return .proud }
        if c.celebrating { return .ecstatic }
        if c.discovering { return .curious }
        if c.inSession { return .focused }
        if c.dueCount > 0, c.oldestOverdueHours > naggingAfterOverdueHours { return .nagging }
        if c.dueCount >= hungryAtDue { return .hungry }
        if c.spirit < MascotMeters.sadBelow { return .sad }
        if c.vitality >= happyVitality, c.spirit >= happySpirit { return .happy }
        return .neutral
    }
}
