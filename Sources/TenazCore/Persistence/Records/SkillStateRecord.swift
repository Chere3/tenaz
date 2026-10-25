import Foundation
import GRDB

/// The stored posterior for one skill (`skill_state`).
public struct SkillStateRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "skill_state"
    public var skill: String
    public var posterior: Data
    public var thetaHat: Double
    public var sd: Double
    public var updatedAt: Int64

    public init(skill: ExamSkill, estimator: AbilityEstimator, updatedAt: Int64) {
        self.skill = skill.rawValue
        posterior = estimator.blob
        thetaHat = estimator.mean
        sd = estimator.sd
        self.updatedAt = updatedAt
    }

    public var estimator: AbilityEstimator? { AbilityEstimator(blob: posterior) }
}
