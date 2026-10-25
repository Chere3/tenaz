/// The word overlay's batch (F1): up to 3 auto-scorable cards (recognition, cloze, recall,
/// collocation), never production (that needs Claude) or spelling (needs audio).
public enum OverlayBatch {
    public static let size = 3
    public static let types: Set<CardType> = [.recognition, .cloze, .recall, .collocation]

    public static func pick(_ items: [SessionItem], size: Int = OverlayBatch.size) -> [SessionItem] {
        Array(items.filter { types.contains($0.card.type) }.prefix(size))
    }
}
