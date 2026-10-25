import Foundation

/// Bayesian ability estimate on a logit grid (Rasch / 1PL with a guessing floor), as specified in
/// docs/research/04-exams-cefr.md §4.2. One estimator per skill.
public struct AbilityEstimator: Codable, Equatable, Sendable {
    public static let grid: [Double] = stride(from: -4.0, through: 4.0, by: 0.1).map { ($0 * 10).rounded() / 10 }
    public var posterior: [Double]

    /// Prior N(mean, sd). The learner starts at B1+ (about -0.3).
    public init(priorMean: Double = -0.3, priorSD: Double = 1.0) {
        let p = Self.grid.map { exp(-0.5 * pow(($0 - priorMean) / priorSD, 2)) }
        let sum = p.reduce(0, +)
        posterior = p.map { $0 / sum }
    }

    /// Item difficulty prior from its CEFR tag.
    public static func difficulty(for level: CEFRLevel) -> Double {
        switch level {
        case .a1: -2.5
        case .a2: -1.5
        case .b1: -0.5
        case .b1Plus: 0.0
        case .b2: 0.5
        case .b2Plus: 1.0
        case .c1: 1.5
        case .c2: 2.5
        }
    }

    public static func probabilityCorrect(theta: Double, difficulty b: Double, guessing c: Double) -> Double {
        c + (1 - c) / (1 + exp(-(theta - b)))
    }

    /// Updates with one scored response. `weight` < 1 softens low-stakes evidence (daily checks).
    public mutating func update(correct: Bool, difficulty b: Double, guessing c: Double = 0, weight: Double = 1) {
        var next = zip(Self.grid, posterior).map { theta, prior -> Double in
            let p = Self.probabilityCorrect(theta: theta, difficulty: b, guessing: c)
            return prior * pow(correct ? p : 1 - p, weight)
        }
        let sum = next.reduce(0, +)
        guard sum > 0 else { return }
        next = next.map { $0 / sum }
        posterior = next
    }

    public var mean: Double { zip(Self.grid, posterior).map(*).reduce(0, +) }

    public var sd: Double {
        let m = mean
        return sqrt(zip(Self.grid, posterior).map { pow($0 - m, 2) * $1 }.reduce(0, +))
    }

    /// P(theta > threshold).
    public func probabilityAbove(_ threshold: Double) -> Double {
        zip(Self.grid, posterior).filter { $0.0 > threshold }.map(\.1).reduce(0, +)
    }

    /// TOEFL-style 1-6 band (0.5 steps). Tenaz thresholds: B1/B2 at 0.0, B2/C1 at 1.0, logit spacing 1 per level.
    public static func band(for theta: Double) -> Double {
        // theta -1 -> 3.0 (B1 start), 0 -> 4.0 (B2 start), 1 -> 5.0 (C1 start).
        let raw = 4.0 + theta
        return min(6, max(1, (raw * 2).rounded(.down) / 2))
    }

    public var band: Double { Self.band(for: mean) }
    public var bandRange: ClosedRange<Double> { Self.band(for: mean - sd)...Self.band(for: mean + sd) }

    public static func cefr(forBand band: Double) -> CEFRLevel {
        switch band {
        case ..<2: .a1
        case ..<3: .a2
        case ..<3.5: .b1
        case ..<4: .b1Plus
        case ..<4.5: .b2
        case ..<5: .b2Plus
        case ..<6: .c1
        default: .c2
        }
    }

    public var level: CEFRLevel { Self.cefr(forBand: band) }
}

/// Deterministic local scoring of objective items.
public enum ObjectiveScorer {
    static func normalize(_ s: String) -> String {
        s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "’", with: "'")
            .filter { $0.isLetter || $0.isNumber || $0 == "'" || $0 == " " }
            .split(separator: " ").joined(separator: " ")
    }

    /// Complete the Words: one point per gap, exact (case-insensitive) hidden letters.
    public static func scoreGaps(_ gaps: [WordGap], answers: [String]) -> [Bool] {
        gaps.enumerated().map { i, gap in
            guard i < answers.count else { return false }
            let typed = normalize(answers[i])
            // Accept either just the missing letters or the whole word.
            return typed == normalize(gap.hidden) || typed == normalize(gap.visible + gap.hidden)
        }
    }

    public static func scoreBuildSentence(_ item: ExamItem, attempt: String) -> Bool {
        let candidates = ([item.answer?.text].compactMap { $0 }) + (item.accepted ?? [])
        return candidates.contains { normalize($0) == normalize(attempt) }
    }

    /// Word error rate between a target sentence and an ASR transcript.
    public static func wordErrorRate(target: String, transcript: String) -> Double {
        let a = normalize(target).split(separator: " ").map(String.init)
        let b = normalize(transcript).split(separator: " ").map(String.init)
        guard !a.isEmpty else { return b.isEmpty ? 0 : 1 }
        var prev = Array(0...b.count)
        for i in 1...a.count {
            var cur = [i] + Array(repeating: 0, count: b.count)
            for j in stride(from: 1, through: b.count, by: 1) {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            prev = cur
        }
        return Double(prev[b.count]) / Double(a.count)
    }

    /// Listen and Repeat 0-5 from WER (thresholds from research §4.3, to calibrate).
    public static func repeatScore(wer: Double) -> Int {
        switch wer {
        case ...0.0001: 5
        case ...0.10: 4
        case ...0.20: 3
        case ...0.35: 2
        case ...0.50: 1
        default: 0
        }
    }
}
