import Foundation
import Testing
@testable import TenazCore

struct LibraryContentTests {
    @Test func catalogAndKnowledgeAreValid() throws {
        let library = try LibraryContent.load(from: ContentTests.contentRoot)
        let vocab = try ContentLibrary.load(from: ContentTests.contentRoot).vocab
        #expect(library.problems(vocab: vocab) == [])
        let books = library.catalog.filter { $0.kind == .book }
        #expect(books.count >= 37, "all titles from research 08 §2")
        #expect(library.catalog.filter { $0.kind == .podcast }.count >= 15)
        #expect(library.catalog.filter { $0.kind == .video }.count >= 10)
        #expect(Set(books.map(\.lane)) == [.a, .b])
        #expect(library.knowledge.count >= 30)
        for topic in KnowledgeCard.topics {
            #expect(library.knowledge.filter { $0.topic == topic }.count >= 5, "\(topic)")
        }
    }

    @Test func meetingPhrasesAreValidVocab() throws {
        let vocab = try ContentLibrary.load(from: ContentTests.contentRoot).vocab
        let phrases = vocab.filter { $0.id.hasPrefix("meeting-phrases-") }
        #expect(phrases.count >= 50)
        for p in phrases {
            #expect(ContentValidator.problems(in: p) == [], "\(p.id)")
            #expect(p.tags.contains("meetings"))
        }
        let ids = vocab.map(\.id)
        #expect(Set(ids).count == ids.count, "ids are unique across vocab files")
    }

    @Test func validatorCatchesBadCards() throws {
        var library = try LibraryContent.load(from: ContentTests.contentRoot)
        let vocab = try ContentLibrary.load(from: ContentTests.contentRoot).vocab
        library.knowledge[0].targetNoteIds[0] = "no-such-note"
        library.knowledge[1].body = "Too short."
        library.knowledge[2].goDeeper = "nowhere"
        let problems = library.problems(vocab: vocab)
        #expect(problems.contains { $0.contains("unknown target") })
        #expect(problems.contains { $0.contains("words") })
        #expect(problems.contains { $0.contains("goDeeper") })
    }

    @Test func wordFormsAndGlossIndex() throws {
        #expect(WordForms.text("We refactored it", mentions: "refactor"))
        #expect(WordForms.text("She studies daily", mentions: "study"))
        #expect(WordForms.text("predicting words", mentions: "predict"))
        #expect(!WordForms.text("a prediction", mentions: "predict"))
        #expect(WordForms.tokens("It's a well-known, (fast) API.") == ["it's", "a", "well-known", "fast", "api"])
        let vocab = try ContentLibrary.load(from: ContentTests.contentRoot).vocab
        let index = GlossIndex(vocab: vocab)
        #expect(index.entry(for: "Bottlenecks", preferring: ["tech-english-bottleneck"])?.id == "tech-english-bottleneck")
        #expect(index.entry(for: "zzzz") == nil)
    }

    @Test func brainBiteRotatesThroughUnread() throws {
        let cards = try LibraryContent.load(from: ContentTests.contentRoot).knowledge
        let first = try #require(KnowledgeCard.brainBite(cards, read: [], day: 20261102))
        #expect(KnowledgeCard.brainBite(cards, read: [], day: 20261102) == first)
        let next = try #require(KnowledgeCard.brainBite(cards, read: [first.id], day: 20261102))
        #expect(next.id != first.id)
        #expect(KnowledgeCard.brainBite(cards, read: Set(cards.map(\.id)), day: 20261102) != nil)
    }
}
