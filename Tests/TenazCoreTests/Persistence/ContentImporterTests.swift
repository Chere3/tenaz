import Foundation
import Testing
@testable import TenazCore

/// Bundled vocabulary → notes and cards, and the error-pattern deck.
struct ContentImporterTests {
    func clean() throws -> [VocabEntry] {
        ContentValidator.cleaned(try ContentLibrary.load(from: ContentTests.contentRoot)).0.vocab
    }

    @Test func importsEveryNoteOnceAndIsIdempotent() throws {
        let vocab = try clean()
        let db = try TenazDatabase.inMemory()
        let first = try ContentImporter.importVocab(vocab, into: db, now: QueueFixture.now)
        #expect(first.notesAdded == vocab.count)
        #expect(first.notesAdded > 150)
        #expect(first.cardsAdded >= vocab.count * 4, "R/C/L/P for most notes")
        let second = try ContentImporter.importVocab(vocab, into: db, now: QueueFixture.now)
        #expect(second == ImportReport())
        let (notes, cards) = try db.reader.read { db in (try NoteRecord.fetchCount(db), try CardRecord.fetchCount(db)) }
        #expect(notes == first.notesAdded)
        #expect(cards == first.cardsAdded)
    }

    @Test func classifiesNotesAndRetention() throws {
        let vocab = try clean()
        let notes = vocab.map(ContentImporter.note(for:))
        #expect(notes.filter { $0.kind == .pattern }.count >= 12)
        #expect(notes.contains { $0.kind == .falseFriend })
        #expect(notes.contains { $0.kind == .chunk })
        let meeting = try #require(vocab.first { $0.tags.contains("meetings") })
        #expect(ContentImporter.note(for: meeting).mustKnow)
        #expect(ContentImporter.cards(for: meeting, now: QueueFixture.now).allSatisfy { $0.desiredRetention == 0.93 })
        let plain = try #require(vocab.first { ContentImporter.mustKnowTags.isDisjoint(with: $0.tags) })
        #expect(ContentImporter.cards(for: plain, now: QueueFixture.now).allSatisfy { $0.desiredRetention == 0.90 })
    }

    @Test func cardTypesPerNote() throws {
        let vocab = try clean()
        let pattern = try #require(vocab.first { $0.id == "error-pattern-monitor" })
        let types = ContentImporter.cards(for: pattern, now: QueueFixture.now).map(\.type)
        #expect(types.first == .cloze)
        #expect(types.contains(.production))
        #expect(!types.contains(.recognition))
        let word = try #require(vocab.first { ContentImporter.kind(for: $0) == .word })
        #expect(Set(ContentImporter.cards(for: word, now: QueueFixture.now).map(\.type)).isSuperset(of: [.recognition, .cloze, .recall, .production]))
    }

    /// The 12 Spanish-L1 error patterns, each with the learner's own wrong form as a distractor.
    @Test func errorPatternDeckIsValid() throws {
        let url = ContentTests.contentRoot.appendingPathComponent("vocab/error-patterns.json")
        let entries = try JSONDecoder().decode([VocabEntry].self, from: Data(contentsOf: url))
        #expect(entries.count == 12)
        for e in entries {
            #expect(ContentValidator.problems(in: e).isEmpty, "\(e.id): \(ContentValidator.problems(in: e))")
            #expect(e.tags.contains("error-pattern"))
            #expect(e.note.hasPrefix("You said") || e.note.contains("not an English word"), "\(e.id) names the learner's wrong form")
        }
        let wrongForms = ["keeping", "in", "to make you to", "made", "be very cheater", "monitorize", "in this time", "that of", "which kind of", "very, very, very", "start", "has"]
        for wrong in wrongForms {
            #expect(entries.contains { $0.distractors.contains(wrong) }, "missing distractor \(wrong)")
        }
    }

    @Test func everyImportedCardHasAPrompt() throws {
        let vocab = try clean()
        let book = PromptBook(vocab: vocab)
        for entry in vocab {
            let note = ContentImporter.note(for: entry)
            for card in ContentImporter.cards(for: entry, now: QueueFixture.now) {
                let prompt = try #require(book.prompt(for: card, note: note))
                if card.type == .recognition {
                    #expect(prompt.options.count == 4, "\(card.id)")
                    #expect(prompt.options[prompt.correctOption!] == entry.es)
                }
                if card.type == .cloze || card.type == .collocation {
                    #expect(prompt.text.contains("____"), "\(card.id)")
                }
            }
        }
    }
}
