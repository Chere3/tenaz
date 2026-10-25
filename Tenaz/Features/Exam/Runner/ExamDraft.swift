import TenazCore

/// What the learner has typed or picked for the task on screen, before it is handed to the session.
struct ExamDraft: Equatable {
    /// One pick per question (single-question items use the first).
    var choices: [Int?] = []
    /// The question shown for multi-question items (reading, listening, interview).
    var questionIndex = 0
    /// Complete the Words: typed letters per gap.
    var gaps: [String] = []
    /// Build a Sentence: chunk indices in the order tapped.
    var order: [Int] = []
    /// Writing, Listen & Repeat.
    var text = ""
    /// Interview: one answer per question.
    var texts: [String] = []
    /// Times the audio was played (max 2).
    var plays = 0

    static func fresh(for task: ExamTask) -> ExamDraft {
        var d = ExamDraft()
        switch task.content {
        case .vocab:
            d.choices = [nil]
        case let .item(item):
            switch item.type {
            case .readDaily, .readAcademic, .listenConversation, .listenAnnouncement, .listenTalk:
                d.choices = Array(repeating: nil, count: item.questions?.count ?? 0)
            case .listenResponse, .grammarMC:
                d.choices = [nil]
            case .completeWords:
                d.gaps = Array(repeating: "", count: CompleteWordsParser.gaps(item.passage ?? "").count)
            case .interview:
                d.texts = Array(repeating: "", count: item.interviewQuestions?.count ?? 0)
            case .buildSentence, .writeEmail, .writeDiscussion, .lifeParagraph, .listenRepeat:
                break
            }
        }
        return d
    }

    /// Nothing given at all: the task counts as skipped.
    var isEmpty: Bool {
        choices.allSatisfy { $0 == nil } && gaps.allSatisfy(\.isEmpty) && order.isEmpty
            && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && texts.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func answer(for task: ExamTask) -> ExamAnswer? {
        guard !isEmpty else { return nil }
        switch task.content {
        case .vocab:
            return .choices(choices)
        case let .item(item):
            switch item.type {
            case .readDaily, .readAcademic, .listenConversation, .listenAnnouncement, .listenTalk, .listenResponse, .grammarMC:
                return .choices(choices)
            case .completeWords:
                return .gaps(gaps.map { $0.trimmingCharacters(in: .whitespaces) })
            case .buildSentence:
                let chunks = item.chunks ?? []
                return .text(order.compactMap { chunks.indices.contains($0) ? chunks[$0] : nil }.joined(separator: " "))
            case .writeEmail, .writeDiscussion, .lifeParagraph, .listenRepeat:
                return .text(text)
            case .interview:
                return .texts(texts)
            }
        }
    }
}
