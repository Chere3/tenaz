import Foundation
import Testing
@testable import TenazCore

/// The real bundled bank and blueprints, plus helpers shared by the exam suites.
enum ExamFixtures {
    static let library: ContentLibrary = {
        let loaded = (try? ContentLibrary.load(from: ContentTests.contentRoot)) ?? ContentLibrary(vocab: [], items: [])
        return ContentValidator.cleaned(loaded).0
    }()

    static func blueprint(_ kind: ExamKind) throws -> ExamBlueprint {
        let catalog = try BlueprintCatalog.load(from: ContentTests.contentRoot)
        guard let blueprint = catalog.blueprint(for: kind) else { throw ContentError.decode(file: "blueprints", underlying: "no \(kind)") }
        return blueprint
    }

    static func priors() -> [ExamSkill: AbilityEstimator] {
        Dictionary(uniqueKeysWithValues: ExamSkill.allCases.map { ($0, AbilityEstimator()) })
    }

    static func session(_ kind: ExamKind, clock: TestClock, seed: UInt64 = 7, includeOptional: Bool = false) throws -> ExamSession {
        ExamSession(blueprint: try blueprint(kind), library: library, priors: priors(), seed: seed,
                    includeOptional: includeOptional, clock: clock)
    }

    static func item(_ json: String) throws -> ExamItem {
        try JSONDecoder().decode(ExamItem.self, from: Data(json.utf8))
    }

    /// A grade with the given writing scores (task, organization, grammar, lexis).
    static func writingGrade(_ scores: [Int], errors: [GradeError] = []) -> GradeResult {
        let names = GradingRubric.criteria(for: .writing).map(\.name)
        return GradeResult(
            criteria: zip(names, scores).map { GradeCriterion(name: $0, score: $1, evidenceQuotes: [], cefr: "B2") },
            errors: errors, feedbackLine: "ok")
    }

    /// A one-section blueprint holding a single Write an Email task.
    static func emailOnly(_ kind: ExamKind) -> ExamBlueprint {
        ExamBlueprint(id: "test-\(kind.rawValue)", kind: kind, title: "Test", sections: [
            SectionSpec(id: "email", title: "Write an Email", skill: .writing, minutes: 10,
                        picks: [ItemPick(types: [.writeEmail], count: 1, levels: ["B2"])]),
        ])
    }

    /// Submits an email-only attempt with some text, saves it, and returns the queued job ids.
    static func submittedEmail(_ kind: ExamKind, store: ExamStore, clock: TestClock) throws -> (ExamSession, [Int64]) {
        var session = ExamSession(blueprint: emailOnly(kind), library: library, priors: priors(), seed: 3, clock: clock)
        try store.begin(session)
        clock.advance(by: 300)
        session.answer(.text("Dear Ana, I am working here since 2024 and the plan depends of the budget. Best, Sam"))
        let submitted = session.submit()
        let outcome = try #require(submitted)
        return (session, try store.save(session, outcome: outcome))
    }
}
