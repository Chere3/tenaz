/// Visible growth between stages (PLAN F8). Every input only grows, so it never regresses:
/// a step per `microGrowthEvery` mastered notes (high-water mark), a gill frond per qualified week
/// (5 of 7 days), and a cosmetic at the weeks in `cosmeticWeeks`.
public struct MicroGrowth: Equatable, Sendable {
    /// The renderer cycles size (+2%), gill length and a new belly spot through these steps.
    public var steps: Int
    public var gillFronds: Int
    /// How many of the scheduled cosmetic weeks have been reached.
    public var cosmeticMilestones: Int

    public init(steps: Int, gillFronds: Int, cosmeticMilestones: Int) {
        self.steps = steps
        self.gillFronds = gillFronds
        self.cosmeticMilestones = cosmeticMilestones
    }

    public static func steps(masteredHighWater: Int, every: Int) -> Int {
        every > 0 ? max(masteredHighWater, 0) / every : 0
    }

    public static func compute(masteredHighWater: Int, qualifiedWeeks: Int, daysSinceInstall: Int,
                               config: StageConfig) -> MicroGrowth {
        MicroGrowth(steps: steps(masteredHighWater: masteredHighWater, every: config.microGrowthEvery),
                    gillFronds: qualifiedWeeks,
                    cosmeticMilestones: config.cosmeticWeeks.filter { daysSinceInstall >= $0 * 7 }.count)
    }
}
