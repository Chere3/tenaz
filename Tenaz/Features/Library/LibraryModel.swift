import Foundation
import TenazCore

/// A book the learner is reading now, with what they have logged.
struct InProgressBook: Equatable, Identifiable {
    var item: CatalogItem
    var minutes: Int
    var sessions: Int
    var pagesRead: Int
    /// Days left at their pace, from the estimated length minus the pages logged.
    var daysLeft: Int
    var id: String { item.id }
}

/// One line of the reading log as shown.
struct ReadingLogLine: Equatable, Identifiable {
    var id: Int64
    var title: String
    var minutes: Int
    var when: String
    var understood: Double?
    var glyph: String
}

/// What the Library screen shows (PLAN F11): a book to keep reading or start, two alternates, two
/// things to listen to, today's Brain bite and the recent log.
struct LibraryModel: Equatable {
    var inProgress: [InProgressBook] = []
    var reading: RecommendationSet?
    var listening: [Recommendation] = []
    var brainBite: KnowledgeCard?
    var brainBitesRead = 0
    var recent: [ReadingLogLine] = []
    var minutesThisWeek = 0
    var profile = ReaderProfile.coldStart

    /// `band` is the learner's current exam band (`ExamStore.currentBand`); nil keeps the B1+ cold start.
    static func build(content: LibraryContent, store: LibraryStore, now: Date, band: Double? = nil,
                      calendar: Calendar = .current) throws -> LibraryModel {
        let today = DayBoundary.day(for: now, calendar: calendar)
        let profile = try band.map { try store.profile(level: AbilityEstimator.cefr(forBand: $0).scaleValue) } ?? store.profile()
        let logs = try store.recentLogs(limit: 200)
        let rows = try store.items()
        var m = LibraryModel()
        m.profile = profile
        m.inProgress = rows.filter { $0.status == .inProgress }.compactMap { row in
            guard let item = content.item(row.itemId), item.kind == .book else { return nil }
            let mine = logs.filter { $0.itemId == item.id }
            let pages = mine.compactMap(\.pages).reduce(0, +)
            let wordsLeft = max(0, (item.words ?? 0) - pages * ReadingCheck.wordsPerPage)
            let perDay = max(1, profile.wordsPerMinute * profile.readingMinutesPerDay)
            return InProgressBook(item: item, minutes: mine.map(\.minutes).reduce(0, +), sessions: mine.count,
                                  pagesRead: pages, daysLeft: max(1, Int((Double(wordsLeft) / perDay).rounded(.up))))
        }
        m.reading = Recommender.pick(content.catalog, profile: profile, kind: .book)
        m.listening = [CatalogItem.Kind.podcast, .video].compactMap { Recommender.pick(content.catalog, profile: profile, kind: $0)?.primary }
        let read = try store.readKnowledgeIds()
        m.brainBitesRead = read.count
        m.brainBite = KnowledgeCard.brainBite(content.knowledge, read: read, day: today)
        m.minutesThisWeek = try store.minutesLast7(today: today)
        let titles = Dictionary(content.catalog.map { ($0.id, $0.title) }, uniquingKeysWith: { a, _ in a })
            .merging(content.knowledge.map { (ReadingLogRecord.knowledgePrefix + $0.id, "Brain bite: \($0.title)") }, uniquingKeysWith: { a, _ in a })
        m.recent = logs.prefix(4).map { log in
            ReadingLogLine(id: log.id ?? 0, title: titles[log.itemId] ?? log.itemId, minutes: log.minutes,
                           when: Self.relative(log.day, today: today), understood: log.comprehension,
                           glyph: log.knowledgeCardId != nil ? "brain" : (content.item(log.itemId)?.kindGlyph ?? "book.fill"))
        }
        return m
    }

    static func relative(_ day: Int, today: Int) -> String {
        switch LearningDays.distance(from: day, to: today) {
        case 0: "Today"
        case 1: "Yesterday"
        case let n: "\(n) days ago"
        }
    }
}
