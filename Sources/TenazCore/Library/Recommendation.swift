/// One scored catalog item with the parts of its score, a one-line "why" and the finish estimate.
public struct Recommendation: Equatable, Identifiable, Sendable {
    public struct Parts: Equatable, Sendable {
        public var fit: Double
        public var interest: Double
        public var novelty: Double
        public var goal: Double
        public var momentum: Double
        public var penalty: Double
    }

    public var item: CatalogItem
    public var score: Double
    public var parts: Parts
    /// Books: days to finish at the learner's pace. Audio and video: days for one episode.
    public var daysToFinish: Int
    /// Built from the score parts, e.g. "Easy reading at your level · tech and work · about 4 days".
    public var why: String

    public var id: String { item.id }
}

/// What the Library shows (research 08 §6.5): one primary pick and two alternates.
public struct RecommendationSet: Equatable, Sendable {
    public var primary: Recommendation
    public var alternates: [Recommendation]

    public var all: [Recommendation] { [primary] + alternates }
}
