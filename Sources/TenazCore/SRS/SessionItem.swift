import Foundation

/// One card in a review session, with its note and what it shows.
public struct SessionItem: Equatable, Sendable {
    public var card: CardRecord
    public var note: NoteRecord
    public var prompt: CardPrompt

    public init(card: CardRecord, note: NoteRecord, prompt: CardPrompt) {
        self.card = card
        self.note = note
        self.prompt = prompt
    }
}
