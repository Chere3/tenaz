import Foundation
import Observation
import TenazCore

/// Reads the learner's Contract from the gamification engine and requests changes. Tightening takes
/// effect at the next 04:00, loosening 24 h later (F10); pending loosenings can be cancelled.
@Observable
final class ContractModel {
    private let engine: GamificationEngine?
    private(set) var contract = Contract.empty
    private(set) var mercyLeft = PenaltyPolicy.mercyTokensPerMonth
    private(set) var vitality = 80
    private(set) var recoveryMode = false
    private(set) var suggestedToDisable: [String] = []
    private(set) var weekStats: [PenaltyRuleKind: PenaltyExperimentLog.Stats] = [:]
    private(set) var loaded = false

    init(engine: GamificationEngine?) {
        self.engine = engine
    }

    var nowMs: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

    func load() {
        guard let engine, let s = try? engine.state() else { return }
        contract = s.contract
        mercyLeft = s.mercyLeft
        vitality = s.mascot.vitality
        recoveryMode = s.recoveryMode
        suggestedToDisable = s.suggestedToDisable
        let events = (try? engine.database.reader.read { try PenaltyEventRecord.fetchAll($0) }) ?? []
        let today = DayBoundary.day(for: Date())
        let week = LearningDays.adding(-6, to: today)...today
        weekStats = Dictionary(uniqueKeysWithValues: PenaltyRuleKind.allCases.map { ($0, PenaltyExperimentLog.stats(events, rule: $0.rawValue, days: week)) })
        loaded = true
    }

    func isOn(_ kind: PenaltyRuleKind) -> Bool { contract.isActive(kind, at: nowMs) }

    func chosenOn(_ kind: PenaltyRuleKind) -> Date? {
        guard isOn(kind), let r = contract.inForce(kind, at: nowMs) else { return nil }
        return Date(timeIntervalSince1970: Double(r.createdAt) / 1000)
    }

    func pending(_ kind: PenaltyRuleKind) -> PenaltyRuleRecord? {
        contract.pending(at: nowMs).last { $0.kind == kind }
    }

    var allPending: [PenaltyRuleRecord] { contract.pending(at: nowMs) }

    func request(_ kind: PenaltyRuleKind, on: Bool) {
        _ = try? engine?.requestRuleChange(kind, enabled: on)
        load()
    }

    func cancel(_ change: PenaltyRuleRecord) {
        guard let id = change.id else { return }
        try? engine?.cancelPendingChange(id: id)
        load()
    }
}
