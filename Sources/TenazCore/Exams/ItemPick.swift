/// One line of a section's content: which items, how many, at which CEFR levels.
/// Exactly one of `ids`, `types` or `vocab` is used, in that order.
public struct ItemPick: Codable, Hashable, Sendable {
    /// Explicit bank item ids (e.g. the placement "tell me about yourself" task).
    public var ids: [String]?
    public var types: [ExamItem.Kind]?
    /// Vocabulary cards as 4-option clozes.
    public var vocab: Bool?
    /// How many to draw (ignored in adaptive sections, where every match joins the pool).
    public var count: Int
    /// Preferred CEFR labels; if too few match, the closest levels fill in.
    public var levels: [String]?

    public init(ids: [String]? = nil, types: [ExamItem.Kind]? = nil, vocab: Bool? = nil, count: Int, levels: [String]? = nil) {
        self.ids = ids
        self.types = types
        self.vocab = vocab
        self.count = count
        self.levels = levels
    }
}
