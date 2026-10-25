import Foundation

/// Public band promotion, one 0.5 step at a time (PLAN F7, [04 §6.5]). All of:
/// 1. the two most recent Monthly Mocks are both verified (CLEAN or confirmed WARNING);
/// 2. on each, P(overall theta > target threshold) ≥ 0.80 (normal approximation);
/// 3. on each, no section band more than one band below the target;
/// 4. the anchor drift check is green;
/// 5. a Weekly Mock dated between the two monthlies agrees with the latest monthly:
///    |weekly overall theta − latest monthly overall theta| ≤ 0.4.
/// No demotion: a bad mock never lowers the public band.
public enum PromotionRules {
    public static let requiredProbability = 0.80
    public static let weeklyAgreement = 0.4

    /// Band b starts at theta b − 4 (band = 4 + theta, floored to 0.5).
    public static func threshold(forBand band: Double) -> Double { band - 4.0 }

    /// P(X > threshold) for X ~ N(mean, sd).
    public static func probabilityAbove(_ threshold: Double, mean: Double, sd: Double) -> Double {
        guard sd > 0 else { return mean > threshold ? 1 : 0 }
        return 0.5 * erfc((threshold - mean) / (sd * 2.0.squareRoot()))
    }

    public static func evaluate(current: Double, monthlies: [MonthlyEvidence], weeklies: [WeeklyEvidence],
                                anchorDriftOK: Bool) -> PromotionDecision {
        let target = min(6, current + 0.5)
        guard target > current else { return .hold(reasons: ["already at the top band"]) }
        var reasons: [String] = []
        let recent = monthlies.sorted { $0.endedAt > $1.endedAt }.prefix(2)
        if recent.count < 2 { reasons.append("needs two Monthly Mocks (has \(recent.count))") }
        for m in recent {
            if !m.verified { reasons.append("monthly \(m.attemptId) is not verified") }
            let p = probabilityAbove(threshold(forBand: target), mean: m.overallMean, sd: m.overallSD)
            if p < requiredProbability { reasons.append(String(format: "monthly %@: P(≥ %.1f) = %.2f < 0.80", m.attemptId, target, p)) }
            for skill in ExamSkill.sections {
                let band = m.sectionBands[skill] ?? 0
                if band < target - 1.0 { reasons.append("monthly \(m.attemptId): \(skill.rawValue) \(band) is more than one band below \(target)") }
            }
        }
        if !anchorDriftOK { reasons.append("anchor drift check is not green") }
        if recent.count == 2 {
            let latest = recent[recent.startIndex], previous = recent[recent.startIndex + 1]
            let agrees = weeklies.contains { w in
                w.endedAt >= previous.endedAt && w.endedAt <= latest.endedAt
                    && abs(w.overallMean - latest.overallMean) <= weeklyAgreement
            }
            if !agrees { reasons.append("no Weekly Mock between the two monthlies agrees within 0.4") }
        }
        return reasons.isEmpty ? .promote(from: current, to: target) : .hold(reasons: reasons)
    }
}
