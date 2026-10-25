/// What the learner gave for one task. Unanswered tasks have no answer at all.
public enum ExamAnswer: Codable, Hashable, Sendable {
    /// One chosen option index per question (nil = left blank). Single-question items use one element.
    case choices([Int?])
    /// Complete the Words: the typed letters per gap.
    case gaps([String])
    /// Build a Sentence (the assembled sentence), writing, Listen & Repeat transcript.
    case text(String)
    /// Take an Interview: one answer per question (transcript or typed fallback).
    case texts([String])

    /// All the free text in the answer, for writing/speaking grading.
    public var freeText: String {
        switch self {
        case let .text(s): s
        case let .texts(list): list.joined(separator: "\n\n")
        case .choices, .gaps: ""
        }
    }
}
