import Foundation
import Testing
@testable import TenazCore

/// Load control for today's set (PLAN F3).
struct QueueTests {
    typealias F = QueueFixture

    func build(_ cards: [CardRecord], _ notes: [NoteRecord], today: DailyCounts = DailyCounts(), limits: QueueLimits = .standard) -> [CardRecord] {
        ReviewQueue.build(cards: cards, notes: F.notes(notes), today: today, day: F.day, now: F.now, limits: limits)
    }

    /// 20 untouched notes, each with R/C/L/P cards.
    func freshDeck(_ count: Int = 20) -> ([CardRecord], [NoteRecord]) {
        let notes = (0..<count).map { F.note(String(format: "n%02d", $0)) }
        let cards = notes.flatMap { n in [CardType.recognition, .cloze, .recall, .production].map { F.newCard(n.id, $0) } }
        return (cards, notes)
    }

    @Test func introducesAtMostFiveNotesADay() {
        let (cards, notes) = freshDeck()
        let set = build(cards, notes)
        #expect(set.count == 5)
        #expect(set.allSatisfy { $0.type == .recognition }, "a word note starts with its R card")
        #expect(Set(set.map(\.noteId)).count == 5)
    }

    @Test func learnThisNextPicksAreIntroducedFirst() {
        let (cards, notes) = freshDeck()
        let set = ReviewQueue.build(cards: cards, notes: F.notes(notes), today: DailyCounts(), day: F.day, now: F.now,
                                    picked: ["n17", "n12"])
        #expect(set.count == 5, "a pick never adds to the new-note budget")
        #expect(Set(set.prefix(2).map(\.noteId)) == ["n12", "n17"])
        // With the budget spent, a pick waits for tomorrow like any other new note.
        let spent = ReviewQueue.build(cards: cards, notes: F.notes(notes), today: DailyCounts(newIntroduced: 5, answered: 5), day: F.day,
                                      now: F.now, picked: ["n17"])
        #expect(spent.isEmpty)
    }

    @Test func reviewStoreHonorsDeckPicks() throws {
        let db = try TenazDatabase.inMemory()
        let vocab = Array(ContentValidator.cleaned(try ContentLibrary.load(from: ContentTests.contentRoot)).0.vocab.prefix(40))
        try ContentImporter.importVocab(vocab, into: db, now: F.now)
        let store = ReviewStore(database: db)
        let before = Set(try store.todaySet(now: F.now).map(\.card.noteId))
        let wanted = try #require(vocab.map(\.id).last { !before.contains($0) })
        try LibraryStore(database: db).pick(noteId: wanted, source: "knowledge:test", now: F.now)
        let after = try store.todaySet(now: F.now)
        #expect(after.count == 5)
        #expect(after.first?.card.noteId == wanted)
    }

    @Test func budgetCountsNotesAlreadyIntroducedToday() {
        let (cards, notes) = freshDeck()
        #expect(build(cards, notes, today: DailyCounts(newIntroduced: 3, answered: 3)).count == 2)
        #expect(build(cards, notes, today: DailyCounts(newIntroduced: 5, answered: 9)).isEmpty)
    }

    @Test func primaryCardDependsOnNoteKind() {
        let notes = [F.note("chunk", kind: .chunk), F.note("pattern", kind: .pattern), F.note("word")]
        let cards = notes.flatMap { n in [CardType.recognition, .cloze, .recall].map { F.newCard(n.id, $0) } }
        let types = Dictionary(uniqueKeysWithValues: build(cards, notes).map { ($0.noteId, $0.type) })
        #expect(types == ["chunk": .recall, "pattern": .cloze, "word": .recognition])
    }

    @Test func siblingsUnlockAtThreeDaysWithoutSpendingBudget() {
        // 8 due reviews on other notes, so siblings have room (1 per 4 reviews).
        var notes = (0..<8).map { F.note("due\($0)") }
        var cards = notes.map { F.reviewCard($0.id, .recognition) }
        notes.append(F.note("young"))
        notes.append(F.note("grown"))
        cards += [F.reviewCard("young", .recognition, stability: 2.9, dueOffset: 3600), F.newCard("young", .cloze)]
        cards += [F.reviewCard("grown", .recognition, stability: 3.0, dueOffset: 3600), F.newCard("grown", .cloze)]
        let set = build(cards, notes, today: DailyCounts(newIntroduced: 5, answered: 5))
        #expect(set.contains { $0.id == "grown:C" }, "unlocked sibling, even with the note budget spent")
        #expect(!set.contains { $0.id == "young:C" }, "primary below 3 d keeps siblings locked")
    }

    @Test func productionWaitsForSevenDayClozeOrRecall() {
        let notes = (0..<8).map { F.note("due\($0)") } + [F.note("a"), F.note("b")]
        var cards = (0..<8).map { F.reviewCard("due\($0)", .recognition) }
        cards += [F.reviewCard("a", .recognition, stability: 30, dueOffset: 9999), F.reviewCard("a", .cloze, stability: 6.9, dueOffset: 9999), F.newCard("a", .production)]
        cards += [F.reviewCard("b", .recognition, stability: 30, dueOffset: 9999), F.reviewCard("b", .recall, stability: 7, dueOffset: 9999), F.newCard("b", .production)]
        let ids = build(cards, notes).map(\.id)
        #expect(ids.contains("b:P"))
        #expect(!ids.contains("a:P"))
    }

    @Test func newCardsInterleaveOnePerFourReviews() {
        let (fresh, freshNotes) = freshDeck(5)
        let dueNotes = (0..<12).map { F.note("due\($0)", tag: "t\($0 % 4)") }
        let due = dueNotes.enumerated().map { F.reviewCard($1.id, [.cloze, .recall, .recognition][$0 % 3], dueOffset: -Double(1000 - $0)) }
        let set = build(fresh + due, freshNotes + dueNotes)
        #expect(set.count == 17)
        // Before any spare new cards go last, each new card follows at least 4 reviews.
        let firstNew = set.firstIndex { $0.state == .new }!
        #expect(firstNew >= 4)
        let prefix = set.prefix(15)
        #expect(prefix.filter { $0.state == .new }.count <= 3)
    }

    @Test func dailyCapLimitsTheSet() {
        let notes = (0..<150).map { F.note("d\($0)") }
        let cards = notes.map { F.reviewCard($0.id, .cloze) }
        #expect(build(cards, notes).count == 120)
        #expect(build(cards, notes, today: DailyCounts(newIntroduced: 0, answered: 100)).count == 20)
        #expect(build(cards, notes, today: DailyCounts(newIntroduced: 0, answered: 130)).isEmpty)
    }

    @Test func noNewCardsWhileMoreThanEightyDue() {
        let (fresh, freshNotes) = freshDeck(5)
        let dueNotes = (0..<81).map { F.note("d\($0)") }
        let set = build(fresh + dueNotes.map { F.reviewCard($0.id, .cloze) }, freshNotes + dueNotes)
        #expect(set.count == 81)
        #expect(!set.contains { $0.state == .new })
    }

    @Test func buriedAndSuspendedCardsAreLeftOut() {
        var buried = F.reviewCard("x", .cloze)
        buried.buriedUntilDay = F.day
        var tomorrow = F.reviewCard("y", .cloze)
        tomorrow.buriedUntilDay = F.day - 1
        var suspended = F.note("z")
        suspended.suspended = true
        let set = build([buried, tomorrow, F.reviewCard("z", .cloze)], [F.note("x"), F.note("y"), suspended])
        #expect(set.map(\.id) == ["y:C"])
    }

    @Test func oneCardPerNote() {
        let cards = [F.reviewCard("x", .cloze), F.reviewCard("x", .recall), F.reviewCard("x", .recognition)]
        #expect(build(cards, [F.note("x")]).count == 1)
    }

    @Test func learningStepsComeBeforeReviews() {
        var learning = F.reviewCard("l", .recall, dueOffset: -10)
        learning.state = .relearning
        learning.step = 0
        let set = build([F.reviewCard("r", .cloze, dueOffset: -5000), learning], [F.note("l"), F.note("r")])
        #expect(set.map(\.id) == ["l:L", "r:C"])
    }

    @Test func neverMoreThanThreeOfOneTypeInARow() {
        let notes = (0..<12).map { F.note("n\($0)", tag: "t\($0 % 5)") }
        // Due order puts 8 cloze cards first, then 4 recall.
        let cards = notes.enumerated().map { i, n in F.reviewCard(n.id, i < 8 ? .cloze : .recall, dueOffset: -Double(1000 - i)) }
        let types = build(cards, notes).map(\.type)
        #expect(types.count == 12)
        for i in 3..<types.count {
            #expect(Set(types[(i - 3)...i]).count > 1, "4 \(types[i]) in a row at \(i)")
        }
    }
}
