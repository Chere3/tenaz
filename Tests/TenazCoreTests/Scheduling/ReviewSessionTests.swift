import Foundation
import Testing
@testable import TenazCore

/// The review state machine and its persistence (PLAN M3 `ReviewSessionTests`).
struct ReviewSessionTests {
    typealias F = QueueFixture

    func item(_ noteId: String, expected: String = "monitor") -> SessionItem {
        let prompt = CardPrompt(type: .cloze, text: "The app will ____ it.", hint: nil, options: [], correctOption: nil, expected: expected, accepted: [])
        return SessionItem(card: F.newCard(noteId, .cloze), note: F.note(noteId), prompt: prompt)
    }

    @Test func wrongAnswerSchedulesOneMinute() throws {
        var session = ReviewSession(items: [item("a"), item("b")], surface: .session)
        #expect(session.next(now: F.now)?.card.id == "a:C")
        let outcome = try session.submit(.typed("monitorize"), durationMs: 4000, inputMode: .typed, at: F.now)
        #expect(outcome.rating == .again)
        #expect(outcome.match == .wrong)
        #expect(outcome.after.state == .learning)
        #expect(outcome.after.dueDate == F.now.addingTimeInterval(60))
        #expect(outcome.comesBackAt == F.now.addingTimeInterval(60))
        #expect(session.nextReturn == F.now.addingTimeInterval(60))

        // The missed card waits its minute: b comes first, then nothing until a is due.
        #expect(session.next(now: F.now.addingTimeInterval(5))?.card.id == "b:C")
        _ = try session.submit(.typed("monitor"), durationMs: 2000, inputMode: .typed, at: F.now.addingTimeInterval(5))
        #expect(session.next(now: F.now.addingTimeInterval(30)) == nil)
        #expect(!session.isFinished)
        let next = session.next(now: F.now.addingTimeInterval(61))
        let back = try #require(next)
        #expect(back.card.id == "a:C")
        #expect(back.card.state == .learning)
    }

    @Test func rightAnswerOnANewCardMovesToTheTenMinuteStep() throws {
        var session = ReviewSession(items: [item("a")], surface: .overlay)
        _ = session.next(now: F.now)
        let outcome = try session.submit(.typed("Monitor"), durationMs: 3000, inputMode: .typed, at: F.now)
        #expect(outcome.rating == .good)
        #expect(outcome.after.step == 1)
        #expect(outcome.comesBackAt == F.now.addingTimeInterval(600))
    }

    @Test func graduatedCardLeavesTheSession() throws {
        var session = ReviewSession(items: [SessionItem(card: F.reviewCard("a", .cloze), note: F.note("a"), prompt: item("a").prompt)], surface: .session)
        _ = session.next(now: F.now)
        let outcome = try session.submit(.typed("monitor"), durationMs: 3000, inputMode: .typed, at: F.now)
        #expect(outcome.after.state == .review)
        #expect(outcome.comesBackAt == nil)
        #expect(session.isFinished)
    }

    @Test func submitWithoutACardOrWithTheWrongAnswerKindThrows() {
        var session = ReviewSession(items: [item("a")], surface: .session)
        #expect(throws: ReviewSessionError.noCurrentCard) { try session.submit(.typed("x"), durationMs: 1, inputMode: .typed, at: F.now) }
        _ = session.next(now: F.now)
        #expect(throws: ReviewSessionError.answerDoesNotFitCard) { try session.submit(.choice(0), durationMs: 1, inputMode: .choice, at: F.now) }
        #expect(session.current != nil, "the card stays on screen after a rejected answer")
    }

    @Test func emitsAnEventPerAnswer() throws {
        let box = EventBox()
        var session = ReviewSession(items: [item("a")], surface: .gate, onEvent: { box.append($0) })
        _ = session.next(now: F.now)
        let outcome = try session.submit(.typed("monitr"), durationMs: 2500, inputMode: .typed, at: F.now)
        #expect(box.events == [outcome.event])
        #expect(outcome.event.rating == .hard)
        #expect(outcome.event.correct)
        #expect(outcome.event.wasNew)
        #expect(outcome.event.surface == .gate)
    }

    @Test func logsEveryAnswer() throws {
        let db = try TenazDatabase.inMemory()
        let vocab = Array(ContentValidator.cleaned(try ContentLibrary.load(from: ContentTests.contentRoot)).0.vocab.prefix(40))
        try ContentImporter.importVocab(vocab, into: db, now: F.now)
        let store = ReviewStore(database: db)
        var session = try store.startSession(book: PromptBook(vocab: vocab), surface: .session, now: F.now)
        #expect(session.queue.count == 5, "day one: five new notes")

        var now = F.now
        var answers = 0
        while answers < 8, let item = session.next(now: now) ?? session.nextReturn.flatMap({ now = $0; return session.next(now: now) }) {
            let answer: ReviewAnswer = item.prompt.type == .recognition ? .choice(answers.isMultiple(of: 3) ? (item.prompt.correctOption! + 1) % 4 : item.prompt.correctOption!) : .typed(item.prompt.expected ?? "")
            try store.record(try session.submit(answer, durationMs: 3000, inputMode: answer == .typed(item.prompt.expected ?? "") ? .typed : .choice, at: now))
            answers += 1
            now += 1
        }
        #expect(answers == 8)
        let (logs, counts) = try (db.reader.read { try ReviewLogRecord.fetchCount($0) }, store.dailyCounts(now: now))
        #expect(logs == 8)
        #expect(counts == DailyCounts(newIntroduced: 5, answered: 8))

        // Siblings of every reviewed note are buried for today, so a new set has only due step cards.
        let buried = try db.reader.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM card WHERE buriedUntilDay = ?", arguments: [F.day]) ?? 0 }
        #expect(buried > 0)
        let again = try store.todaySet(now: now.addingTimeInterval(3600))
        #expect(again.allSatisfy { $0.card.state != .new }, "budget spent and siblings buried")
    }
}

/// Collects events from the `@Sendable` hook.
final class EventBox: @unchecked Sendable {
    // Invariant: all access goes through `lock`.
    private let lock = NSLock()
    private var stored: [ReviewEvent] = []
    func append(_ e: ReviewEvent) { lock.lock(); stored.append(e); lock.unlock() }
    var events: [ReviewEvent] { lock.lock(); defer { lock.unlock() }; return stored }
}
