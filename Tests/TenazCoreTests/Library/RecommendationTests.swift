import Foundation
import Testing
@testable import TenazCore

struct RecommendationTests {
    static let library = try! LibraryContent.load(from: ContentTests.contentRoot)
    var catalog: [CatalogItem] { Self.library.catalog }

    @Test func monotonicInterest() throws {
        for topic in ["TECH", "PSY", "SF", "GAMES", "MEETINGS"] {
            var base = ReaderProfile.coldStart
            base.interests[topic] = 0.5
            var more = base
            more.interests[topic] = 0.7
            for item in catalog {
                let before = Recommender.score(item, profile: base, catalog: catalog).score
                let after = Recommender.score(item, profile: more, catalog: catalog).score
                if item.topics.contains(topic) {
                    #expect(after > before, "\(item.id) should rise with \(topic)")
                } else {
                    #expect(after == before, "\(item.id) should not change with \(topic)")
                }
            }
        }
    }

    @Test func oneLaneBAtATime() throws {
        let laneB = try #require(catalog.first { $0.kind == .book && $0.lane == .b })
        let profile = ReaderProfile(history: [ReadingHistoryEntry(itemId: laneB.id, status: .inProgress)])
        let set = try #require(Recommender.pick(catalog, profile: profile))
        #expect(set.all.count == 3)
        #expect(set.all.allSatisfy { $0.item.lane == .a }, "\(set.all.map(\.id))")
        #expect(!set.all.contains { $0.id == laneB.id })
        // Every other lane B book carries the -1 penalty in the raw ranking too.
        for r in Recommender.rank(catalog.filter { $0.kind == .book }, profile: profile) where r.item.lane == .b {
            #expect(r.parts.penalty >= 1)
        }
        // Without it, the alternates follow the two-lane plan: the other lane is represented.
        let cold = try #require(Recommender.pick(catalog, profile: .coldStart))
        #expect(Set(cold.all.map(\.item.lane)) == [.a, .b])
    }

    @Test func coldStartDeterministic() throws {
        let a = try #require(Recommender.pick(catalog, profile: .coldStart))
        let b = try #require(Recommender.pick(catalog.reversed(), profile: .coldStart))
        #expect(a == b)
        #expect(a.primary.id == "book-who-moved-my-cheese")
        #expect(a.alternates.map(\.id) == ["book-lean-startup", "book-deep-work"])
        #expect(a.primary.why == "Easy reading at your level · psychology and work · about 3 days")
        let listen = try #require(Recommender.pick(catalog, profile: .coldStart, kind: .podcast))
        #expect(listen.all.count == 3)
    }

    @Test func historyChangesNoveltyAndExcludesStartedItems() throws {
        let profile = ReaderProfile(history: [ReadingHistoryEntry(itemId: "book-the-martian", status: .finished)])
        let ranked = Recommender.rank(catalog, profile: profile)
        #expect(!ranked.contains { $0.id == "book-the-martian" })
        let sameAuthor = try #require(ranked.first { $0.id == "book-project-hail-mary" })
        #expect(sameAuthor.parts.novelty == 0.3)
        let abandoned = ReaderProfile(history: [ReadingHistoryEntry(itemId: "book-the-martian", status: .abandoned)])
        let penalised = try #require(Recommender.rank(catalog, profile: abandoned).first { $0.id == "book-project-hail-mary" })
        #expect(penalised.parts.penalty >= 0.3)
    }

    @Test func daysToFinishUsesPace() throws {
        let book = try #require(catalog.first { $0.id == "book-phoenix-project" })
        #expect(Recommender.daysToFinish(book, profile: .coldStart) == 48) // 120,000 / (170 × 15)
        var fast = ReaderProfile.coldStart
        fast.wordsPerMinute = 250
        fast.readingMinutesPerDay = 30
        #expect(Recommender.daysToFinish(book, profile: fast) == 16)
    }

    @Test func coverageReplacesBandDistance() throws {
        let book = try #require(catalog.first { $0.lane == .a && $0.kind == .book })
        var p = ReaderProfile.coldStart
        p.coverage[book.id] = 0.98
        #expect(Recommender.score(book, profile: p, catalog: catalog).parts.fit == 1)
        p.coverage[book.id] = 0.90
        #expect(abs(Recommender.score(book, profile: p, catalog: catalog).parts.fit) < 1e-9)
    }
}
