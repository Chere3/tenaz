import Foundation
import GRDB
import Testing
@testable import TenazCore

/// Exposure control (dataset plan §6) and writing kinds (§7, §8).
struct ExposureTests {
    static let now = Date(timeIntervalSince1970: 1_793_000_000)
    static let day: TimeInterval = 86_400

    static func life(_ id: String, kind: String? = nil, group: String? = nil, text: String? = nil) -> ExamItem {
        var fields = ["\"id\": \"\(id)\"", "\"type\": \"lifeParagraph\"", "\"cefr\": \"B2\"", "\"prompt\": \"Question \(id)?\"",
                      "\"mustUse\": [\"follow up on\"]", "\"minWords\": 40"]
        if let kind { fields.append("\"kind\": \"\(kind)\"") }
        if let group { fields.append("\"group\": \"\(group)\"") }
        if let text { fields.append("\"text\": \"\(text)\"") }
        return try! ExamFixtures.item("{\(fields.joined(separator: ", "))}")
    }

    static func shown(_ id: String, _ surface: ExposureSurface = .gate, kind: String? = nil, daysAgo: Double) -> ExposureRecord {
        ExposureRecord(itemId: id, surface: surface, kind: kind, at: now.addingTimeInterval(-daysAgo * day))
    }

    // MARK: Model and validator

    @Test func newFieldsDecodeAndRoundTrip() throws {
        let item = try ExamFixtures.item("""
            {"id": "lp-x", "type": "lifeParagraph", "cefr": "B2", "prompt": "Summarise the update.", "kind": "summary",
             "text": "The vendor moved the delivery to Friday.", "reference": ["Delivery moves to Friday."],
             "source": "dolly", "sourceId": "42", "license": "CC BY-SA 3.0", "tier": "permissive", "group": "dolly:42",
             "origin": "verbatim", "topics": ["workplace"]}
            """)
        #expect(item.kind == "summary" && item.writingKind == .summary && item.reference == ["Delivery moves to Friday."])
        #expect(item.source == "dolly" && item.sourceId == "42" && item.license == "CC BY-SA 3.0" && item.tier == "permissive")
        #expect(item.group == "dolly:42" && item.origin == "verbatim" && item.topics == ["workplace"])
        let again = try JSONDecoder().decode(ExamItem.self, from: JSONEncoder().encode(item))
        #expect(again == item)
        let vocab = try JSONDecoder().decode(VocabEntry.self, from: Data("""
            {"id": "v", "headword": "h", "pos": "noun", "cefr": "B2", "es": "e", "definition": "d", "example": "an h here",
             "exampleEs": "x", "cloze": "an ____ here", "answer": "h", "distractors": ["a", "b", "c"], "collocations": [],
             "note": "", "tags": [], "source": "bsl", "license": "CC BY-SA 4.0"}
            """.utf8))
        #expect(vocab.source == "bsl" && vocab.license == "CC BY-SA 4.0")
    }

    @Test func missingKindIsTheTypeDefault() throws {
        #expect(Self.life("a").writingKind == .personal)
        let email = try ExamFixtures.item(#"{"id": "e", "type": "writeEmail", "cefr": "B2", "situation": "s", "tasks": ["t"]}"#)
        #expect(email.writingKind == .request)
        let post = try ExamFixtures.item(#"{"id": "d", "type": "writeDiscussion", "cefr": "B2", "professor": "p"}"#)
        #expect(post.writingKind == .opinion)
        let talk = try ExamFixtures.item(#"{"id": "i", "type": "interview", "cefr": "B2", "topic": "t", "questions": ["q"]}"#)
        #expect(talk.writingKind == .interview)
        #expect(try ExamFixtures.item(#"{"id": "g", "type": "grammarMC", "cefr": "B2"}"#).writingKind == nil)
    }

    @Test func validatorChecksKinds() throws {
        #expect(ContentValidator.problems(in: Self.life("a", kind: "advice")).isEmpty)
        #expect(!ContentValidator.problems(in: Self.life("a", kind: "limerick")).isEmpty)
        // A kind of another type is rejected too.
        #expect(!ContentValidator.problems(in: Self.life("a", kind: "complaint")).isEmpty)
        for kind in ["summary", "rewrite", "correct", "translate", "chart"] {
            #expect(ContentValidator.problems(in: Self.life("a", kind: kind)).contains { $0.contains("needs text") })
            #expect(ContentValidator.problems(in: Self.life("a", kind: kind, text: "Some text.")).isEmpty)
        }
        let email = try ExamFixtures.item(#"{"id": "e", "type": "writeEmail", "cefr": "B2", "situation": "s", "tasks": ["t"], "kind": "recap"}"#)
        #expect(ContentValidator.problems(in: email).isEmpty)
        let badPost = try ExamFixtures.item(#"{"id": "d", "type": "writeDiscussion", "cefr": "B2", "professor": "p", "kind": "story"}"#)
        #expect(!ContentValidator.problems(in: badPost).isEmpty)
    }

    @Test func rubricIncludesKindTextAndReference() throws {
        let item = try ExamFixtures.item("""
            {"id": "lp-r", "type": "lifeParagraph", "cefr": "B2", "prompt": "Make this message polite.", "kind": "rewrite",
             "text": "Send me the file now.", "reference": ["Could you send me the file when you have a moment?"], "minWords": 40}
            """)
        let task = GradingRubric.taskPrompt(for: item)
        #expect(task.contains("Kind: rewrite") && task.contains(WritingKind.rewrite.criterion))
        #expect(task.contains("Send me the file now.") && task.contains("Could you send me the file"))
        #expect(task.contains("do not require identical wording"))
        // Every kind has its own criterion line.
        #expect(Set(WritingKind.allCases.map(\.criterion)).count == WritingKind.allCases.count)
        #expect(GradingRubric.taskPrompt(for: Self.life("p")).contains("Kind: personal"))
    }

    // MARK: Picker

    @Test func writingNeverRepeatsUntilNinetyPercentUsed() {
        let pool = (0 ..< 20).map { Self.life("p\($0)") }
        var history: [ExposureRecord] = []
        var rng = SeededRandom(seed: 1)
        var seen: [String] = []
        // 18 of 20 = 90 %: each of the first 18 picks is new.
        for i in 0 ..< 18 {
            let picker = ExposurePicker(surface: i.isMultiple(of: 2) ? .gate : .write, library: pool, history: history, now: Self.now)
            let item = try! #require(picker.pick(pool, rng: &rng))
            #expect(!seen.contains(item.id))
            seen.append(item.id)
            history.append(ExposureRecord(item: item, surface: i.isMultiple(of: 2) ? .gate : .write, at: Self.now.addingTimeInterval(Double(i))))
        }
        // From here the least recently shown come back first: the 2 never shown, then the oldest.
        let picker = ExposurePicker(surface: .gate, library: pool, history: history, now: Self.now.addingTimeInterval(100))
        var r = SeededRandom(seed: 9)
        let next = picker.pick(pool, rng: &r)!
        #expect(!seen.contains(next.id))
    }

    @Test func groupMatesCountAsShownEvenFromBackfilledRows() {
        let a = Self.life("a", group: "story:1")
        let b = Self.life("b", group: "story:1")
        let c = Self.life("c")
        // A backfilled row has no groupId: the group comes from the library.
        let history = [Self.shown("a", .write, daysAgo: 3)]
        let picker = ExposurePicker(surface: .gate, library: [a, b, c], history: history, now: Self.now)
        #expect(picker.lastShown(b) != nil)
        for seed in 1 ... 20 {
            var rng = SeededRandom(seed: UInt64(seed))
            #expect(picker.pick([a, b, c], rng: &rng)?.id == "c")
        }
    }

    @Test func kindRotationAvoidsTheLastTwoKinds() {
        let pool = [Self.life("p1"), Self.life("p2"), Self.life("a1", kind: "advice"), Self.life("s1", kind: "story")]
        // Last two writing prompts (any surface): personal on the gate, advice on Write.
        let history = [Self.shown("x", .gate, kind: "personal", daysAgo: 2), Self.shown("y", .write, kind: "advice", daysAgo: 1)]
        let picker = ExposurePicker(surface: .write, library: pool, history: history, now: Self.now)
        #expect(picker.recentKinds == [.advice, .personal])
        for seed in 1 ... 20 {
            var rng = SeededRandom(seed: UInt64(seed))
            #expect(picker.pick(pool, rng: &rng)?.id == "s1")
        }
    }

    @Test func kindRotationRelaxesForAnAllPersonalPool() {
        let pool = (0 ..< 5).map { Self.life("p\($0)") }
        let history = [Self.shown("p0", daysAgo: 2), Self.shown("p1", .write, daysAgo: 1)]
        let picker = ExposurePicker(surface: .gate, library: pool, history: history, now: Self.now)
        #expect(picker.recentKinds == [.personal, .personal])
        var rng = SeededRandom(seed: 4)
        let item = picker.pick(pool, rng: &rng)
        #expect(item != nil && !["p0", "p1"].contains(item!.id))
    }

    @Test func seededPicksAreDeterministicAndVary() {
        let pool = (0 ..< 30).map { Self.life("p\($0)") }
        let picker = ExposurePicker(surface: .gate, library: pool, history: [], now: Self.now)
        var r1 = SeededRandom(seed: 11)
        var r2 = SeededRandom(seed: 11)
        #expect(picker.pick(pool, rng: &r1) == picker.pick(pool, rng: &r2))
        let ids = Set((1 ... 20).map { seed -> String in
            var rng = SeededRandom(seed: UInt64(seed))
            return picker.pick(pool, rng: &rng)!.id
        })
        #expect(ids.count > 5)
    }

    @Test func examExclusionIsGroupAwareAndExpiresAfter180Days() {
        let a = Self.life("a", group: "g")
        let b = Self.life("b", group: "g")
        let c = Self.life("c")
        let d = Self.life("d")
        let history = [Self.shown("a", .exam, daysAgo: 30), Self.shown("c", .gate, daysAgo: 179), Self.shown("d", .exam, daysAgo: 181)]
        let picker = ExposurePicker(surface: .exam, library: [a, b, c, d], history: history, now: Self.now)
        #expect(picker.excludedIds([a, b, c, d]) == ["a", "b", "c"])
        var rng = SeededRandom(seed: 2)
        #expect(picker.pick([a, b, c, d], rng: &rng)?.id == "d")
        // Everything shown recently: the least recently shown comes back.
        let all = [Self.shown("a", .exam, daysAgo: 10), Self.shown("c", .exam, daysAgo: 20)]
        let full = ExposurePicker(surface: .exam, library: [a, c], history: all, now: Self.now)
        #expect(full.pick([a, c], rng: &rng)?.id == "c")
    }

    // MARK: Gate

    @Test func gatePicksPerUnlockAndStaysStickyWhilePending() throws {
        let items = try ContentLibrary.load(from: ContentTests.contentRoot).items
        var history: [ExposureRecord] = []
        var shown: [String] = []
        var rng = SeededRandom(seed: 5)
        for unlock in 0 ..< 3 {
            let at = Self.now.addingTimeInterval(Double(unlock) * 3 * 3600)
            let p = GatePrompt.pick(items: items, history: history, pendingId: nil, now: at, forgottenWords: [], rng: &rng)
            #expect(!shown.contains(p.id))
            shown.append(p.id)
            history.append(ExposureRecord(itemId: p.id, surface: .gate, kind: p.kind.rawValue, at: at))
        }
        // Same day, three unlocks, three different prompts. A gate that closed early comes back.
        let again = GatePrompt.pick(items: items, history: history, pendingId: shown[2], now: Self.now, forgottenWords: [], rng: &rng)
        #expect(again.id == shown[2])
    }

    @Test func gateOnlyShowsGateKinds() {
        let items = [Self.life("s", kind: "summary", text: "A text."), Self.life("t", kind: "translate", text: "Hola."),
                     Self.life("st", kind: "story", text: "The lights went out.")]
        var rng = SeededRandom(seed: 3)
        let p = GatePrompt.pick(items: items, history: [], pendingId: "s", now: Self.now, forgottenWords: [], rng: &rng)
        #expect(p.id == "st" && p.kind == .story && p.text == "The lights went out.")
        #expect(p.gradingPrompt.contains("Kind: story") && p.gradingPrompt.contains("Use “follow up on”"))
        #expect(!p.gradingPrompt.contains("Minimum words"))
    }

    // MARK: Store and backfill

    @Test func storeRecordsAndReads() throws {
        let store = ExposureStore(database: try .inMemory())
        try store.record(Self.life("b", group: "g"), surface: .write, at: Self.now)
        try store.record(Self.life("a"), surface: .gate, at: Self.now.addingTimeInterval(-60))
        let rows = try store.all()
        #expect(rows.map(\.itemId) == ["a", "b"])
        #expect(rows[1].groupId == "g" && rows[1].kind == "personal" && rows[1].surface == "write")
    }

    @Test func migrationBackfillsFromAnswers() throws {
        let queue = try DatabaseQueue()
        try Migrations.migrator().migrate(queue, upTo: "v1_intrusions")
        try queue.write { db in
            try db.execute(sql: """
                INSERT INTO exam_attempt (id, kind, blueprintId, seed, startedAt, status) VALUES ('a1', 'daily', 'daily', 1, 1000, 'done');
                INSERT INTO exam_response (attemptId, itemId, sectionId, skill, scoreSource) VALUES ('a1', 'read-daily-001', 's', 'reading', 'objective');
                INSERT INTO exam_response (attemptId, itemId, sectionId, skill, scoreSource) VALUES ('a1', 'vocab:b2-leverage-v', 's', 'grammar', 'objective');
                INSERT INTO writing_entry (ts, surface, promptId, prompt, text, wordCount, gradeStatus) VALUES (2000, 'gate', 'life-paragraphs-003', 'q', 't', 30, 'pending');
                INSERT INTO writing_entry (ts, surface, promptId, prompt, text, wordCount, gradeStatus) VALUES (3000, 'write', 'life-paragraphs-004', 'q', 't', 30, 'pending');
                INSERT INTO writing_entry (ts, surface, promptId, prompt, text, wordCount, gradeStatus) VALUES (4000, 'exam', 'read-daily-001', 'q', 't', 30, 'pending');
                """)
        }
        let db = try TenazDatabase(writer: queue)
        let rows = try ExposureStore(database: db).all()
        #expect(rows.map(\.itemId) == ["read-daily-001", "life-paragraphs-003", "life-paragraphs-004"])
        #expect(rows.map(\.surface) == ["exam", "gate", "write"])
        #expect(rows.map(\.ts) == [1000, 2000, 3000])
        #expect(rows[1].kind == "personal" && rows[0].kind == nil)
    }
}
