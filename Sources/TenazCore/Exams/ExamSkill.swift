/// The five estimated skills (PLAN F7). Only the four TOEFL sections make up the overall band;
/// `grammar` (Grammar & Vocabulary, Aptis-style) is tracked on its own.
public enum ExamSkill: String, Codable, CaseIterable, Sendable {
    case reading, listening, writing, speaking, grammar

    /// The four sections averaged into the overall band.
    public static let sections: [ExamSkill] = [.reading, .listening, .writing, .speaking]

    /// The skill an item belongs to when its section does not say otherwise.
    public static func natural(for item: ExamItem) -> ExamSkill {
        if let raw = item.skill, let skill = ExamSkill(rawValue: raw) { return skill }
        switch item.type {
        case .completeWords, .readDaily, .readAcademic: return .reading
        case .listenResponse, .listenConversation, .listenAnnouncement, .listenTalk: return .listening
        case .writeEmail, .writeDiscussion, .lifeParagraph: return .writing
        case .listenRepeat, .interview: return .speaking
        case .buildSentence, .grammarMC: return .grammar
        }
    }

    public var label: String {
        switch self {
        case .reading: "Reading"
        case .listening: "Listening"
        case .writing: "Writing"
        case .speaking: "Speaking"
        case .grammar: "Grammar & Vocabulary"
        }
    }
}
