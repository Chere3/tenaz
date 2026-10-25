import TenazCore

/// How a task is shown; one item view per case.
enum ExamTaskKind: Equatable {
    case vocab, grammar, completeWords, reading, listenResponse, listening, buildSentence, writing, listenRepeat, interview

    init(_ task: ExamTask) {
        guard let item = task.item else {
            self = .vocab
            return
        }
        switch item.type {
        case .grammarMC: self = .grammar
        case .completeWords: self = .completeWords
        case .readDaily, .readAcademic: self = .reading
        case .listenResponse: self = .listenResponse
        case .listenConversation, .listenAnnouncement, .listenTalk: self = .listening
        case .buildSentence: self = .buildSentence
        case .writeEmail, .writeDiscussion, .lifeParagraph: self = .writing
        case .listenRepeat: self = .listenRepeat
        case .interview: self = .interview
        }
    }

    /// Multi-line answers submit with Command-Return, so Return can start a new line.
    var usesLongText: Bool { self == .writing || self == .interview }

    /// Number keys 1-4 pick an option.
    var hasOptions: Bool { [.vocab, .grammar, .reading, .listenResponse, .listening].contains(self) }

    /// What the task asks, in a few words, above the item.
    var instruction: String {
        switch self {
        case .vocab: "Pick the word that fits."
        case .grammar: "Pick the best option."
        case .completeWords: "Finish each word. Tab moves to the next gap."
        case .reading: "Read, then answer."
        case .listenResponse: "Listen, then pick the best reply."
        case .listening: "Listen, then answer."
        case .buildSentence: "Put the pieces in order."
        case .writing: "Write your answer."
        case .listenRepeat: "Listen, then say the same sentence."
        case .interview: "Answer the question."
        }
    }
}
