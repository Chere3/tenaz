import Foundation

public enum TypingFlag: Hashable, Sendable {
    /// More than 8 characters appeared in one edit and not from an input method.
    case largeInsertion(characters: Int)
    /// A burst above 150 WPM without a single backspace.
    case fastTyping(wpm: Int)
}
