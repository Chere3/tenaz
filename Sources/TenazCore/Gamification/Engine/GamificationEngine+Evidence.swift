import GRDB

extension GamificationEngine {
    /// The stage evidence stored so far (empty before anyone wrote it).
    public func stageEvidence() throws -> StageEvidence {
        try database.reader.read { try Self.meta($0, Self.evidenceKey) } ?? StageEvidence()
    }

    /// Read-modify-write of the stored evidence in one transaction, so one area (exams setting
    /// `placementDone`) never wipes another's fields (onboarding, private band). Prefer this over
    /// `updateStageEvidence(_:)`, which replaces the whole value.
    @discardableResult
    public func mergeStageEvidence(_ change: (inout StageEvidence) -> Void) throws -> GamificationEffects {
        try database.writer.write { db in
            var evidence: StageEvidence = try Self.meta(db, Self.evidenceKey) ?? StageEvidence()
            change(&evidence)
            try Self.setMeta(db, Self.evidenceKey, evidence)
            return try self.apply(nil, db)
        }
    }
}
