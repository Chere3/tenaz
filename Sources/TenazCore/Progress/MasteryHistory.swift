/// Rebuilds "mastered notes per day" from `review_log`, so the weekly review can draw growth without
/// a history table. A note counts on its primary card (L recall if it has one, else C cloze, else
/// any): FSRS stability ≥ 21 d after its latest review and its last 3 recalls correct (PLAN F8).
public enum MasteryHistory {
    public struct Review: Equatable, Sendable {
        public var cardId: String
        public var ts: Int64
        public var rating: Int
        public var stability: Double?

        public init(cardId: String, ts: Int64, rating: Int, stability: Double?) {
            self.cardId = cardId
            self.ts = ts
            self.rating = rating
            self.stability = stability
        }
    }

    /// One primary card id per note.
    public static func primaryCards(_ cards: [(id: String, noteId: String, type: CardType)]) -> Set<String> {
        let rank: [CardType: Int] = [.recall: 0, .cloze: 1]
        var best: [String: (rank: Int, id: String)] = [:]
        for c in cards {
            let r = rank[c.type] ?? 2
            if let current = best[c.noteId], (current.rank, current.id) <= (r, c.id) { continue }
            best[c.noteId] = (r, c.id)
        }
        return Set(best.values.map(\.id))
    }

    /// Mastered count at each moment in `dayEnds` (ascending).
    public static func series(primary: Set<String>, reviews: [Review], dayEnds: [Int64], config: StageConfig) -> [Int] {
        let ordered = reviews.filter { primary.contains($0.cardId) }.sorted { ($0.ts, $0.cardId) < ($1.ts, $1.cardId) }
        var stability: [String: Double] = [:]
        var streak: [String: Int] = [:]
        var mastered = Set<String>()
        var out: [Int] = []
        var i = 0
        for end in dayEnds {
            while i < ordered.count, ordered[i].ts < end {
                let r = ordered[i]
                stability[r.cardId] = r.stability ?? 0
                streak[r.cardId] = r.rating > Rating.again.rawValue ? (streak[r.cardId] ?? 0) + 1 : 0
                if config.isMastered(stabilityDays: stability[r.cardId] ?? 0, lastRecallsCorrect: streak[r.cardId] ?? 0) {
                    mastered.insert(r.cardId)
                } else {
                    mastered.remove(r.cardId)
                }
                i += 1
            }
            out.append(mastered.count)
        }
        return out
    }
}
