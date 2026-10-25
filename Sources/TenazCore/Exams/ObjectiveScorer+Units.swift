/// Turns one task + answer into scored units. Unanswered parts count as wrong (as in TOEFL).
/// Claude-graded tasks return no units here; they are scored after submit.
extension ObjectiveScorer {
    /// Ten gaps from one passage are not ten independent observations; each counts half.
    static let gapWeight = 0.5

    public static func units(for task: ExamTask, answer: ExamAnswer?) -> [ScoredUnit] {
        func unit(_ correct: Bool, guessing: Double, weight: Double = 1) -> ScoredUnit {
            ScoredUnit(taskId: task.id, skill: task.skill, difficulty: task.difficulty, guessing: guessing,
                       weight: weight, outcome: .binary(correct))
        }
        func choices() -> [Int?] { if case let .choices(c) = answer { c } else { [] } }
        func text() -> String { if case let .text(s) = answer { s } else { "" } }

        switch task.content {
        case let .vocab(_, options, correct):
            return [unit(choices().first.flatMap { $0 } == correct, guessing: 1 / Double(options.count))]
        case let .item(item):
            switch item.type {
            case .completeWords:
                let gaps = CompleteWordsParser.gaps(item.passage ?? "")
                let typed: [String] = if case let .gaps(g) = answer { g } else { [] }
                return scoreGaps(gaps, answers: typed).map { unit($0, guessing: 0, weight: gapWeight) }
            case .readDaily, .readAcademic, .listenConversation, .listenAnnouncement, .listenTalk:
                let picked = choices()
                return (item.questions ?? []).enumerated().map { i, q in
                    let given = i < picked.count ? picked[i] : nil
                    return unit(given == q.answer, guessing: 1 / Double(max(q.options.count, 1)))
                }
            case .listenResponse, .grammarMC:
                let options = item.options ?? []
                return [unit(choices().first.flatMap { $0 } == item.answer?.index, guessing: 1 / Double(max(options.count, 1)))]
            case .buildSentence:
                return [unit(scoreBuildSentence(item, attempt: text()), guessing: 0)]
            case .listenRepeat:
                let score = repeatScore(wer: wordErrorRate(target: item.sentence ?? "", transcript: text()))
                return [ScoredUnit(taskId: task.id, skill: task.skill, difficulty: task.difficulty, guessing: 0,
                                   weight: 1, outcome: .rubric(Double(score)))]
            case .writeEmail, .writeDiscussion, .lifeParagraph, .interview:
                return []
            }
        }
    }
}
