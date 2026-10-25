/// What has been proven so far. The app (or other areas) fills the learning and exam parts;
/// the engine fills the time floors from its own records.
public struct StageEvidence: Codable, Equatable, Sendable {
    /// The starting-level prior (B1+, theta -0.3) as a band: the app seeds `privateBand`
    /// with it on day 1 so stage 3 is provisional from the first qualified day.
    public static let englishLevelPriorBand = 3.5

    public var onboardingDone = false
    public var levelParagraphDone = false
    public var placementDone = false
    public var placementBand: Double?
    /// Private Daily Check estimate (TOEFL-style band).
    public var privateBand: Double?
    /// Public band, moved only by verified Monthly Mocks.
    public var publicBand: Double?
    public var masteredNotes = 0
    public var writingMedian: Double?
    public var bestRolePlay: Double?
    /// Bands of verified (CLEAN or confirmed WARNING) monthly mocks.
    public var verifiedMonthlyBands: [Double] = []
    /// Filled by the engine: reviews answered in total.
    public var reviewsDone = 0
    /// Filled by the engine: qualified days from the day the current stage was reached (inclusive).
    public var qualifiedDaysSinceStage = 0
    /// Filled by the engine: calendar days since the current stage was reached.
    public var daysSinceStage = 0

    public init(onboardingDone: Bool = false, levelParagraphDone: Bool = false, placementDone: Bool = false,
                placementBand: Double? = nil, privateBand: Double? = nil, publicBand: Double? = nil,
                masteredNotes: Int = 0, writingMedian: Double? = nil, bestRolePlay: Double? = nil,
                verifiedMonthlyBands: [Double] = [], qualifiedDaysSinceStage: Int = 0, daysSinceStage: Int = 0) {
        self.onboardingDone = onboardingDone
        self.levelParagraphDone = levelParagraphDone
        self.placementDone = placementDone
        self.placementBand = placementBand
        self.privateBand = privateBand
        self.publicBand = publicBand
        self.masteredNotes = masteredNotes
        self.writingMedian = writingMedian
        self.bestRolePlay = bestRolePlay
        self.verifiedMonthlyBands = verifiedMonthlyBands
        self.qualifiedDaysSinceStage = qualifiedDaysSinceStage
        self.daysSinceStage = daysSinceStage
    }
}
