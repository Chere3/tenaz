/// Combines grading runs: the median per criterion (monthly mocks run three times, PLAN F6).
public enum GradeAggregator {
    public static func median(_ values: [Double]) -> Double {
        let s = values.sorted()
        guard !s.isEmpty else { return 0 }
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }

    /// Median score per criterion across runs.
    public static func medians(_ runs: [GradeResult]) -> [String: Double] {
        var byName: [String: [Double]] = [:]
        for run in runs { for c in run.criteria { byName[c.name, default: []].append(Double(c.score)) } }
        return byName.mapValues(median)
    }

    /// The task's 0-5 score: the mean of the criterion medians.
    public static func overall(_ runs: [GradeResult]) -> Double {
        let m = medians(runs)
        guard !m.isEmpty else { return 0 }
        return m.values.reduce(0, +) / Double(m.count)
    }

    /// Runs disagree by more than a point on some criterion: flag low confidence.
    public static func lowConfidence(_ runs: [GradeResult]) -> Bool {
        var byName: [String: [Int]] = [:]
        for run in runs { for c in run.criteria { byName[c.name, default: []].append(c.score) } }
        return byName.values.contains { ($0.max() ?? 0) - ($0.min() ?? 0) > 1 }
    }
}
