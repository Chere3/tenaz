/// What the recommender knows about the learner (research 08 §6.1). The cold start is deterministic:
/// level B1+ and a default set of interests.
public struct ReaderProfile: Equatable, Sendable {
    /// CEFR on the numeric scale (`CEFRLevel.scaleValue`): B1+ = 3.5.
    public var level: Double
    /// Interest weight per catalog topic, 0...1. Missing topics count as 0.
    public var interests: [String: Double]
    public var wordsPerMinute: Double
    public var readingMinutesPerDay: Double
    public var listeningMinutesPerDay: Double
    /// Oldest first.
    public var history: [ReadingHistoryEntry]
    /// Measured coverage (0...1) per item id, once the coverage tool has a text the learner owns.
    public var coverage: [String: Double]

    /// Default interests (tech, AI, startups, psychology, neuroscience, sci-fi, Minecraft/Discord
    /// communities as GAMES), plus the work goal and lighter genres.
    public static let defaultInterests: [String: Double] = [
        "TECH": 1.0, "AI": 0.9, "STARTUP": 0.8, "PSY": 0.7, "NEURO": 0.7, "SF": 0.6, "GAMES": 0.6,
        "SCI": 0.5, "BIO": 0.5, "WORK": 0.5, "MEETINGS": 0.5, "ENGLISH": 0.4, "MYSTERY": 0.3,
        "FANTASY": 0.3, "NEWS": 0.2,
    ]
    /// Research 08 §1.2: 15 minutes a day; a B1+ adult reads graded text at roughly 170 wpm.
    public static let defaultWordsPerMinute = 170.0
    public static let defaultMinutesPerDay = 15.0

    public init(level: Double = CEFRLevel.b1Plus.scaleValue, interests: [String: Double] = Self.defaultInterests,
                wordsPerMinute: Double = Self.defaultWordsPerMinute, readingMinutesPerDay: Double = Self.defaultMinutesPerDay,
                listeningMinutesPerDay: Double = Self.defaultMinutesPerDay, history: [ReadingHistoryEntry] = [],
                coverage: [String: Double] = [:]) {
        self.level = level
        self.interests = interests
        self.wordsPerMinute = wordsPerMinute
        self.readingMinutesPerDay = readingMinutesPerDay
        self.listeningMinutesPerDay = listeningMinutesPerDay
        self.history = history
        self.coverage = coverage
    }

    public static let coldStart = ReaderProfile()
}
