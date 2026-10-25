import Foundation
import Testing
@testable import TenazCore

/// Typed-answer matching and the grade mapping per card type (PLAN F3).
struct AnswerMatcherTests {
    @Test func normalizationIgnoresCaseSpacingAndPunctuation() {
        #expect(AnswerMatcher.match("  Right  NOW! ", expected: "right now") == .exact)
        #expect(AnswerMatcher.match("don’t", expected: "don't") == .exact)
    }

    @Test func acceptedVariantIsFullyRight() {
        #expect(AnswerMatcher.match("leveraged", expected: "leverage", accepted: ["leveraged"]) == .accepted)
        #expect(Grader.typed(.accepted) == .good)
    }

    @Test func oneSlipOnALongWordIsANearMiss() {
        #expect(AnswerMatcher.match("monitr", expected: "monitor") == .nearMiss)
        #expect(AnswerMatcher.match("extremly high", expected: "extremely high") == .nearMiss)
        #expect(Grader.typed(.nearMiss) == .hard)
    }

    @Test func oneSlipOnAShortWordIsWrong() {
        #expect(AnswerMatcher.match("mak", expected: "make") == .wrong)
        #expect(AnswerMatcher.match("in", expected: "on") == .wrong)
    }

    @Test func twoSlipsOrDifferentWordsAreWrong() {
        #expect(AnswerMatcher.match("monitorize", expected: "monitor") == .wrong)
        #expect(AnswerMatcher.match("right", expected: "right now") == .wrong)
        #expect(AnswerMatcher.match("", expected: "right now") == .wrong)
        #expect(Grader.typed(.wrong) == .again)
    }

    @Test func levenshteinBasics() {
        #expect(AnswerMatcher.levenshtein("kitten", "sitting") == 3)
        #expect(AnswerMatcher.levenshtein("", "abc") == 3)
        #expect(AnswerMatcher.levenshtein("same", "same") == 0)
    }

    @Test func recognitionGradesByTime() {
        #expect(Grader.recognition(correct: true, durationMs: 5999) == .good)
        #expect(Grader.recognition(correct: true, durationMs: 6000) == .hard)
        #expect(Grader.recognition(correct: true, durationMs: 15000) == .hard)
        #expect(Grader.recognition(correct: false, durationMs: 1000) == .again)
    }

    @Test func ratingNeedsAnAnswerThatFitsTheCard() {
        let r = CardPrompt(type: .recognition, text: "x", hint: nil, options: ["a", "b", "c", "d"], correctOption: 2, expected: nil, accepted: [])
        #expect(Grader.rating(for: r, answer: .choice(2), durationMs: 1000) == .good)
        #expect(Grader.rating(for: r, answer: .choice(1), durationMs: 1000) == .again)
        #expect(Grader.rating(for: r, answer: .typed("c"), durationMs: 1000) == nil)
        let c = CardPrompt(type: .cloze, text: "x ____", hint: nil, options: [], correctOption: nil, expected: "monitor", accepted: [])
        #expect(Grader.rating(for: c, answer: .typed("Monitor"), durationMs: 1000) == .good)
        #expect(Grader.rating(for: c, answer: .typed("monitr"), durationMs: 1000) == .hard)
        let p = CardPrompt(type: .production, text: "x", hint: nil, options: [], correctOption: nil, expected: nil, accepted: [])
        #expect(Grader.rating(for: p, answer: .graded(.hard), durationMs: 1000) == .hard)
        #expect(Grader.rating(for: p, answer: .typed("a sentence"), durationMs: 1000) == nil)
    }
}
