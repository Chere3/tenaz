/// Decides Tena's next stage. Stages never regress and advance one at a time: reaching a stage
/// restarts the time floor.
public enum StageEvaluator {
    public static func nextStage(current: Int, evidence e: StageEvidence, config: StageConfig) -> Int {
        guard let next = config.stages.first(where: { $0.stage == current + 1 }) else { return current }
        let floorOK = e.qualifiedDaysSinceStage >= (next.floor.qualifiedDays ?? 0)
            && e.daysSinceStage >= (next.floor.days ?? 0)
        guard floorOK, meets(next.requires, e) else { return current }
        return max(current, next.stage)
    }

    /// Tena holds a stage the placement did not confirm: show "catching up", never take it away.
    public static func isCatchingUp(stage: Int, evidence e: StageEvidence, config: StageConfig) -> Bool {
        guard e.placementDone, let band = e.placementBand else { return false }
        return config.stages.contains { s in
            guard let below = s.catchingUpBelowPlacementBand else { return false }
            return stage >= s.stage && band < below
        }
    }

    static func meets(_ r: StageConfig.Requirements, _ e: StageEvidence) -> Bool {
        func atLeast(_ value: Double?, _ needed: Double?) -> Bool {
            guard let needed else { return true }
            guard let value else { return false }
            return value >= needed
        }
        if r.onboardingDone == true, !e.onboardingDone { return false }
        if r.levelParagraphDone == true, !e.levelParagraphDone { return false }
        if r.placementDone == true, !e.placementDone { return false }
        if r.placementBandAtLeast != nil, !e.placementDone { return false }
        guard atLeast(e.placementBand, r.placementBandAtLeast),
              atLeast(e.privateBand, r.privateBandAtLeast),
              atLeast(e.publicBand, r.publicBandAtLeast),
              atLeast(e.writingMedian, r.writingMedianAtLeast),
              atLeast(e.bestRolePlay, r.rolePlayAtLeast),
              e.reviewsDone >= (r.reviewsDone ?? 0),
              e.masteredNotes >= (r.mastered ?? 0) else { return false }
        if let mocks = r.monthlyMocksAtBand {
            let band = r.publicBandAtLeast ?? 0
            if e.verifiedMonthlyBands.filter({ $0 >= band }).count < mocks { return false }
        }
        return true
    }
}
