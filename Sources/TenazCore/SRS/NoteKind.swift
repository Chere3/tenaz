import Foundation

/// What a note is: a single word, a multi-word chunk, one of the learner's error patterns, or a false friend.
public enum NoteKind: String, Codable, Sendable {
    case word, chunk, pattern, falseFriend
}
