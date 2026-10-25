import Foundation
import TenazCore

/// Real bundled words dressed as a batch, for snapshots and as the smoke's fallback when nothing
/// is due. Nothing here touches the database.
enum IntrusionSamples {
    static let headwords = ["reliable", "leverage", "follow up"]
    static let types: [CardType] = [.recognition, .cloze, .recall]

    static func overlayItems(_ content: ContentLibrary, now: Date = Date()) -> [SessionItem] {
        let book = PromptBook(vocab: content.vocab)
        var out: [SessionItem] = []
        for (word, type) in zip(headwords, types) {
            guard let entry = content.vocab.first(where: { $0.headword == word }) else { continue }
            let note = NoteRecord(id: entry.id, kind: .word, display: entry.headword, lemma: entry.headword, glossEs: entry.es,
                                  exampleEn: entry.example, exampleEs: entry.exampleEs, cefr: entry.cefr, tags: entry.tags,
                                  mustKnow: false, source: "sample", sourceRef: entry.id)
            let card = CardRecord(noteId: entry.id, type: type, desiredRetention: 0.9, now: now)
            if let prompt = book.prompt(for: card, note: note) { out.append(SessionItem(card: card, note: note, prompt: prompt)) }
        }
        return out
    }

    static func gatePrompt(_ content: ContentLibrary) -> GatePrompt {
        let question = content.items.first { $0.id == "life-paragraphs-001" }?.prompt
            ?? "What is the first thing you did today, and how did it set the mood for the rest of your day?"
        return GatePrompt(id: "life-paragraphs-001", question: question, chunk: "follow up on")
    }

    /// A `story` gate (snapshot `gate-story`): the opener as the item's text, the instruction line, the kind's placeholder.
    static let gateStoryPrompt = GatePrompt(
        id: "sample-story", question: "What happens next?", chunk: "turn out", kind: .story,
        text: "At 8:55 the dashboard went red for the whole planning team. Five minutes before the weekly call, "
            + "my manager sent one message: \"Can you explain this to the directors?\"")

    static let gateParagraph = "This morning I have to follow up on the bug that broke our login page yesterday. "
        + "After that I will review two pull requests, and then I want to practice my English before lunch with the team."
}
