import Foundation
import Testing
@testable import TenazCore

struct ExamScoringTests {
    @Test func estimatorMovesUpWithCorrectHardAnswers() {
        var est = AbilityEstimator()
        let start = est.mean
        for _ in 0..<10 { est.update(correct: true, difficulty: 1.5) }
        #expect(est.mean > start + 0.5)
        #expect(est.sd < 1.0)
    }

    @Test func estimatorMovesDownWithWrongEasyAnswers() {
        var est = AbilityEstimator()
        for _ in 0..<10 { est.update(correct: false, difficulty: -1.5, guessing: 0.25) }
        #expect(est.mean < -0.3)
    }

    @Test func bandMapping() {
        #expect(AbilityEstimator.band(for: -0.3) == 3.5)
        #expect(AbilityEstimator.band(for: 0.0) == 4.0)
        #expect(AbilityEstimator.band(for: 1.2) == 5.0)
        #expect(AbilityEstimator.cefr(forBand: 3.5) == .b1Plus)
        #expect(AbilityEstimator.cefr(forBand: 4.0) == .b2)
        #expect(AbilityEstimator().level == .b1Plus)
    }

    @Test func gapScoringAcceptsMissingPartOrWholeWord() {
        let gaps = CompleteWordsParser.gaps("New tech{{nology}} changes how we wo{{rk}}.")
        #expect(ObjectiveScorer.scoreGaps(gaps, answers: ["nology", "WORK"]) == [true, true])
        #expect(ObjectiveScorer.scoreGaps(gaps, answers: ["nologies"]) == [false, false])
    }

    @Test func wordErrorRate() {
        #expect(ObjectiveScorer.wordErrorRate(target: "I want you to connect it", transcript: "I want you to connect it.") == 0)
        #expect(abs(ObjectiveScorer.wordErrorRate(target: "a b c d", transcript: "a x c") - 0.5) < 0.001)
        #expect(ObjectiveScorer.repeatScore(wer: 0.15) == 3)
    }

    @Test func claudeArgumentsAreSlimAndKeyless() {
        let cli = ClaudeCLI()
        let args = cli.arguments(prompt: "p", system: "s", schema: "{}")
        #expect(args.contains("--no-session-persistence"))
        #expect(args.contains("--strict-mcp-config"))
        let env = ClaudeCLI.environment(from: ["ANTHROPIC_API_KEY": "x", "HOME": "/Users/example"])
        #expect(env["ANTHROPIC_API_KEY"] == nil)
        #expect(env["HOME"] == "/Users/example")
    }

    @Test func decodesStructuredOutput() throws {
        struct G: Decodable, Sendable { var score: Int }
        let ok = Data(#"{"is_error":false,"structured_output":{"score":4}}"#.utf8)
        #expect(try ClaudeCLI.decodeStructured(G.self, from: ok).score == 4)
        let limited = Data(#"{"is_error":true,"result":"Claude AI usage limit reached"}"#.utf8)
        #expect(throws: ClaudeCLIError.self) { try ClaudeCLI.decodeStructured(G.self, from: limited) }
    }
}
