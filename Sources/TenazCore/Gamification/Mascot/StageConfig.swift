import Foundation

/// `Content/config/stages.json`: Tena's growth gates as tunable data (PLAN F8, section 2 row 7).
public struct StageConfig: Codable, Equatable, Sendable {
    public struct Mastered: Codable, Equatable, Sendable {
        public var minStabilityDays: Double
        public var lastCorrectRecalls: Int
    }

    /// Every field is optional; a missing field is not required. All present fields must hold.
    public struct Requirements: Codable, Equatable, Sendable {
        public var onboardingDone: Bool?
        /// Reviews answered in total ("first set of reviews done").
        public var reviewsDone: Int?
        public var levelParagraphDone: Bool?
        public var placementDone: Bool?
        public var placementBandAtLeast: Double?
        public var privateBandAtLeast: Double?
        public var publicBandAtLeast: Double?
        public var mastered: Int?
        public var writingMedianAtLeast: Double?
        public var rolePlayAtLeast: Double?
        /// Verified monthly mocks at or above `publicBandAtLeast`.
        public var monthlyMocksAtBand: Int?
    }

    /// Time floor since the previous stage was reached: qualified days from that day on (inclusive),
    /// and calendar days.
    public struct Floor: Codable, Equatable, Sendable {
        public var qualifiedDays: Int?
        public var days: Int?
    }

    public struct Stage: Codable, Equatable, Sendable {
        public var stage: Int
        public var name: String
        public var requires: Requirements
        public var floor: Floor
        /// Stage 3 is granted from the prior; if the week-1 placement later comes out below this
        /// band, Tena keeps the stage (stages never regress) and shows "catching up".
        public var catchingUpBelowPlacementBand: Double?
    }

    public var version: Int
    public var mastered: Mastered
    /// One visible micro-growth step every this many mastered notes (size, gill, belly spot, cycled).
    public var microGrowthEvery: Int
    /// Weeks since install at which a cosmetic unlocks (novelty schedule, R15).
    public var cosmeticWeeks: [Int]
    public var stages: [Stage]

    public static func load(from url: URL) throws -> StageConfig {
        try JSONDecoder().decode(StageConfig.self, from: Data(contentsOf: url))
    }

    public func name(of stage: Int) -> String { stages.first { $0.stage == stage }?.name ?? "Stage \(stage)" }

    public var maxStage: Int { stages.map(\.stage).max() ?? 0 }

    /// "Mastered" = FSRS stability ≥ 21 d and the last 3 recalls correct.
    public func isMastered(stabilityDays: Double, lastRecallsCorrect: Int) -> Bool {
        stabilityDays >= mastered.minStabilityDays && lastRecallsCorrect >= mastered.lastCorrectRecalls
    }
}
