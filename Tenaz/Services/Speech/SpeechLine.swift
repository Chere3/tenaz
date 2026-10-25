/// One thing to say aloud: the text and who says it (voice gender and speaker id from the item).
struct SpeechLine: Equatable, Sendable {
    var text: String
    /// "female" / "male" from Content/FORMAT.md; nil = any.
    var voice: String?
    /// "A" / "B" in conversations, so two speakers of the same gender still sound different.
    var speaker: String?
}
