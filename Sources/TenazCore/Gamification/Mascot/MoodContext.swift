/// Everything the mood depends on. The app fills the context parts (quiet hours, meeting, due
/// counts from the scheduler); the engine fills the meters and its own flags.
public struct MoodContext: Equatable, Sendable {
    public var vitality = MascotMeters.start
    public var spirit = MascotMeters.start
    public var dueCount = 0
    /// Hours the oldest due review has been overdue.
    public var oldestOverdueHours = 0.0
    public var inSession = false
    /// Night, quiet hours or a meeting signal: Tena sleeps and never interrupts.
    public var asleep = false
    public var repairInProgress = false
    /// Just healed (repair task finished recently).
    public var justHealed = false
    /// Perfect session, new best, evolution.
    public var celebrating = false
    /// A new word or feature was just discovered.
    public var discovering = false

    public init(vitality: Int = MascotMeters.start, spirit: Int = MascotMeters.start, dueCount: Int = 0,
                oldestOverdueHours: Double = 0, inSession: Bool = false, asleep: Bool = false,
                repairInProgress: Bool = false, justHealed: Bool = false, celebrating: Bool = false,
                discovering: Bool = false) {
        self.vitality = vitality
        self.spirit = spirit
        self.dueCount = dueCount
        self.oldestOverdueHours = oldestOverdueHours
        self.inSession = inSession
        self.asleep = asleep
        self.repairInProgress = repairInProgress
        self.justHealed = justHealed
        self.celebrating = celebrating
        self.discovering = discovering
    }
}
