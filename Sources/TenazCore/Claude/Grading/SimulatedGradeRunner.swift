/// Grades like a rater who sees a learner of known ability: criterion scores whose mean maps to
/// `theta` through the fixed rubric table. Only for simulations (`placement-sim`), never the app.
public struct SimulatedGradeRunner: GradeRunner {
    public var theta: Double
    public var model: String { "simulated" }

    public init(theta: Double) { self.theta = theta }

    /// The continuous 0-5 score whose rubric theta equals `theta`.
    public static func score(for theta: Double) -> Double {
        let table = AbilityEstimator.rubricTheta
        if theta <= table[0] { return 0 }
        for s in 0..<5 where theta <= table[s + 1] {
            return Double(s) + (theta - table[s]) / (table[s + 1] - table[s])
        }
        return 5
    }

    public func grade(_ request: GradeRequest) async throws -> GradeResult {
        let names = GradingRubric.criteria(for: request.kind).map(\.name)
        let target = Self.score(for: theta)
        let low = Int(target.rounded(.down))
        // Spread whole-number criterion scores so their mean is as close to the target as possible.
        let ups = Int(((target - Double(low)) * Double(names.count)).rounded())
        let criteria = names.enumerated().map { i, name in
            let score = min(5, low + (i < ups ? 1 : 0))
            return GradeCriterion(name: name, score: score, evidenceQuotes: [],
                                  cefr: AbilityEstimator.cefr(forBand: AbilityEstimator.band(for: theta)).label)
        }
        return GradeResult(criteria: criteria, errors: [], feedbackLine: "Simulated grade.")
    }
}
