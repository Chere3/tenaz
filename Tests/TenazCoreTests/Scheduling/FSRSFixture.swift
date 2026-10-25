import Foundation
import Testing
@testable import TenazCore

/// Decodes the py-fsrs fixtures written by `scripts/fsrs-fixtures.py`.
struct FSRSFixture: Decodable {
    struct Review: Decodable {
        var rating: Int
        var at: Double
        var state: String
        var step: Int?
        var stability: Double
        var difficulty: Double
        var due: Double
    }

    struct Sequence: Decodable {
        var name: String
        var desiredRetention: Double
        var learningSteps: [Double]
        var relearningSteps: [Double]
        var start: Double
        var reviews: [Review]

        var scheduler: StepScheduler {
            StepScheduler(desiredRetention: desiredRetention, steps: LearningSteps(learning: learningSteps, relearning: relearningSteps))
        }
    }

    var sequences: [Sequence]
    var roundCases: [[Double]]?

    static func load(_ name: String) throws -> FSRSFixture {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(FSRSFixture.self, from: Data(contentsOf: url))
    }
}
