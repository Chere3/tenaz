import Foundation

/// Research 08 §6.3: `score = 0.35 fit + 0.25 interest + 0.15 novelty + 0.15 goal + 0.10 momentum
/// - penalties`. Pure and deterministic: ties break by id, so the cold start never changes.
public enum Recommender {
    public static let fitWeight = 0.35
    public static let interestWeight = 0.25
    public static let noveltyWeight = 0.15
    public static let goalWeight = 0.15
    public static let momentumWeight = 0.10

    /// Topics that serve the work goal (workplace meetings); TECH counts half (the learner's field).
    public static let goalTopics: Set<String> = ["WORK", "MEETINGS"]
    /// Finish within 2-3 weeks is ideal; beyond 6 weeks the item is penalised.
    public static let idealDays = 21.0
    public static let tooLongDays = 42.0
    /// Lane B (and audio) should sit this far above the reader's level; lane A text right at it.
    public static let laneBStretch = 0.5
    public static let listeningStretch = 0.25

    public static func score(_ item: CatalogItem, profile: ReaderProfile, catalog: [CatalogItem]) -> Recommendation {
        let byId = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let days = daysToFinish(item, profile: profile)

        let fit: Double
        if let coverage = profile.coverage[item.id] {
            let target = item.lane == .a ? 0.98 : 0.95
            fit = clamp(1 - abs(coverage - target) / 0.08)
        } else {
            var ideal = item.lane == .a ? 0 : laneBStretch
            if item.kind != .book { ideal += listeningStretch }
            fit = clamp(1 - abs(item.level.scaleValue - profile.level - ideal))
        }

        let weights = item.topics.map { profile.interests[$0] ?? 0 }
        let interest = weights.isEmpty ? 0 : clamp(weights.reduce(0, +) / Double(weights.count))

        let recent = profile.history.suffix(3).compactMap { byId[$0.itemId] }
        let seenBefore = recent.contains { $0.creator == item.creator || $0.topics.first == item.topics.first }
        let novelty = seenBefore ? 0.3 : 1

        let goal: Double = item.topics.contains(where: goalTopics.contains) ? 1 : (item.topics.contains("TECH") ? 0.5 : 0)

        let momentum = Double(days) <= idealDays ? 1 : clamp(1 - (Double(days) - idealDays) / idealDays)

        var penalty = 0.0
        let abandonedCreators = Set(profile.history.filter { $0.status == .abandoned }.compactMap { byId[$0.itemId]?.creator })
        if abandonedCreators.contains(item.creator) { penalty += 0.3 }
        if item.kind == .book, Double(days) > tooLongDays { penalty += 0.3 }
        if item.kind == .book, item.lane == .b, laneBBookInProgress(profile, byId: byId) { penalty += 1 }

        let parts = Recommendation.Parts(fit: fit, interest: interest, novelty: novelty, goal: goal, momentum: momentum, penalty: penalty)
        let total = fitWeight * fit + interestWeight * interest + noveltyWeight * novelty + goalWeight * goal
            + momentumWeight * momentum - penalty
        return Recommendation(item: item, score: total, parts: parts, daysToFinish: days,
                              why: why(item, parts: parts, days: days, profile: profile))
    }

    /// Every item the learner has not started, best first (score desc, then id).
    public static func rank(_ items: [CatalogItem], profile: ReaderProfile, catalog: [CatalogItem]? = nil) -> [Recommendation] {
        let all = catalog ?? items
        let touched = Set(profile.history.map(\.itemId))
        return items.filter { !touched.contains($0.id) }
            .map { score($0, profile: profile, catalog: all) }
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.item.id < $1.item.id }
    }

    /// One primary and two alternates of one kind. Books follow the two-lane plan: the alternates
    /// include the best of the other lane, and never another lane B book while one is in progress.
    public static func pick(_ catalog: [CatalogItem], profile: ReaderProfile, kind: CatalogItem.Kind = .book) -> RecommendationSet? {
        let byId = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var pool = rank(catalog.filter { $0.kind == kind }, profile: profile, catalog: catalog)
        if kind == .book, laneBBookInProgress(profile, byId: byId) { pool = pool.filter { $0.item.lane == .a } }
        guard let primary = pool.first else { return nil }
        var alternates: [Recommendation] = []
        if kind == .book, let other = pool.dropFirst().first(where: { $0.item.lane != primary.item.lane }) {
            alternates.append(other)
        }
        for r in pool.dropFirst() where alternates.count < 2 && !alternates.contains(where: { $0.id == r.id }) {
            alternates.append(r)
        }
        alternates.sort { $0.score != $1.score ? $0.score > $1.score : $0.item.id < $1.item.id }
        return RecommendationSet(primary: primary, alternates: alternates)
    }

    /// Books: words / (wpm × minutes a day). Audio and video: one episode at the listening budget.
    public static func daysToFinish(_ item: CatalogItem, profile: ReaderProfile) -> Int {
        switch item.kind {
        case .book:
            let perDay = max(1, profile.wordsPerMinute * profile.readingMinutesPerDay)
            return max(1, Int((Double(item.words ?? 0) / perDay).rounded(.up)))
        case .podcast, .video:
            return max(1, Int((Double(item.minutes ?? 0) / max(1, profile.listeningMinutesPerDay)).rounded(.up)))
        }
    }

    static func laneBBookInProgress(_ profile: ReaderProfile, byId: [String: CatalogItem]) -> Bool {
        profile.history.contains { entry in
            entry.status == .inProgress && byId[entry.itemId].map { $0.kind == .book && $0.lane == .b } == true
        }
    }

    // MARK: - Why line

    static let topicNames: [String: String] = [
        "TECH": "tech", "AI": "AI", "STARTUP": "startups", "PSY": "psychology", "NEURO": "the brain",
        "SF": "sci-fi", "GAMES": "games", "SCI": "science", "BIO": "real lives", "WORK": "work",
        "MEETINGS": "meetings", "ENGLISH": "English", "MYSTERY": "mystery", "FANTASY": "fantasy", "NEWS": "news",
    ]

    static func why(_ item: CatalogItem, parts: Recommendation.Parts, days: Int, profile: ReaderProfile) -> String {
        let level: String
        if let coverage = profile.coverage[item.id] {
            level = "You know about \(Int((coverage * 100).rounded()))% of the words"
        } else if parts.fit >= 0.75 {
            level = item.lane == .a ? "Easy reading at your level" : "A good stretch for you"
        } else if parts.fit >= 0.4 {
            level = "A little hard for now"
        } else {
            level = "Save it for later"
        }
        let topics = item.topics
            .sorted { (profile.interests[$0] ?? 0, $1) > (profile.interests[$1] ?? 0, $0) }
            .prefix(2)
            .map { topicNames[$0] ?? $0.lowercased() }
            .joined(separator: " and ")
        let time: String = switch item.kind {
        case .book: "about \(days) \(days == 1 ? "day" : "days")"
        case .podcast, .video: "\(item.minutes ?? 0) min an episode"
        }
        return [level, topics, time].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    static func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
}
