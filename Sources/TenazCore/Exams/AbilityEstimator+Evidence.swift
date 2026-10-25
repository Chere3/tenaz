import Foundation

/// Evidence types beyond a single right/wrong answer, plus storage helpers.
extension AbilityEstimator {
    /// Fixed table from a 0-5 rubric score (Claude criteria median, or Listen & Repeat from WER)
    /// to the theta it is evidence for. 3 ≈ B1/B2 border, 4 ≈ B2 high, 5 ≈ C1 (band = 4 + theta).
    static let rubricTheta: [Double] = [-3.0, -2.0, -1.0, -0.25, 0.75, 1.75]
    /// How noisy one rubric score is as evidence (logits).
    static let rubricSD = 0.7

    public static func theta(forRubric score: Double) -> Double {
        let s = min(5, max(0, score))
        let lo = Int(s.rounded(.down))
        guard lo < 5 else { return rubricTheta[5] }
        let f = s - Double(lo)
        return rubricTheta[lo] * (1 - f) + rubricTheta[lo + 1] * f
    }

    /// Gaussian likelihood around the theta the rubric score points to.
    public mutating func update(rubric score: Double, weight: Double = 1) {
        let center = Self.theta(forRubric: score)
        var next = zip(Self.grid, posterior).map { theta, prior in
            prior * pow(exp(-0.5 * pow((theta - center) / Self.rubricSD, 2)), weight)
        }
        let sum = next.reduce(0, +)
        guard sum > 0 else { return }
        next = next.map { $0 / sum }
        posterior = next
    }

    /// Applies one scored unit at the attempt's weight times the unit's own weight.
    public mutating func apply(_ unit: ScoredUnit, weight: Double) {
        switch unit.outcome {
        case let .binary(correct):
            update(correct: correct, difficulty: unit.difficulty, guessing: unit.guessing, weight: weight * unit.weight)
        case let .rubric(score):
            update(rubric: score, weight: weight * unit.weight)
        }
    }

    /// Equal mixture of several posteriors (prior for a section that mixes skills).
    public static func mixture(_ estimators: [AbilityEstimator]) -> AbilityEstimator {
        var result = AbilityEstimator()
        guard !estimators.isEmpty else { return result }
        let n = Double(estimators.count)
        result.posterior = grid.indices.map { i in estimators.map { $0.posterior[i] }.reduce(0, +) / n }
        return result
    }

    /// 81 little-endian doubles for `skill_state.posterior`.
    public var blob: Data {
        var data = Data(capacity: posterior.count * 8)
        for value in posterior { withUnsafeBytes(of: value.bitPattern.littleEndian) { data.append(contentsOf: $0) } }
        return data
    }

    public init?(blob: Data) {
        let bytes = [UInt8](blob)
        guard bytes.count == Self.grid.count * 8 else { return nil }
        self.init()
        posterior = (0..<Self.grid.count).map { i in
            var bits: UInt64 = 0
            for b in 0..<8 { bits |= UInt64(bytes[i * 8 + b]) << (8 * UInt64(b)) }
            return Double(bitPattern: bits)
        }
    }
}
