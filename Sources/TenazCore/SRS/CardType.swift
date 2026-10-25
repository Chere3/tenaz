import Foundation

/// The six independently scheduled card types a note can produce (PLAN F3).
public enum CardType: String, Codable, CaseIterable, Sendable {
    /// Recognition: English chunk, pick the Spanish gloss (4 options).
    case recognition = "R"
    /// Cloze: sentence with a blank, typed.
    case cloze = "C"
    /// Recall: Spanish cue, type the English chunk.
    case recall = "L"
    /// Collocation: the word inside a fixed partner phrase, typed.
    case collocation = "K"
    /// Production: write a sentence using the chunk, graded by the Claude rubric.
    case production = "P"
    /// Spelling/sound: hear it, type or say it.
    case spelling = "S"
}
