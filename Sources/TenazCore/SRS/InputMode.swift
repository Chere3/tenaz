import Foundation

/// How the answer was given (`review_log.inputMode`).
public enum InputMode: String, Codable, Sendable {
    case typed, choice, spoken, rubric
}
