import TenazCore

/// The spoken lines of a task, and the same content as plain text for the transcript fallback.
enum ExamScript {
    static func lines(for task: ExamTask, question: Int = 0) -> [SpeechLine] {
        task.item.map { lines(for: $0, question: question) } ?? []
    }

    /// What `speak()` gets for one item (an interview speaks one question per call).
    /// `scripts/tts/cast.py` `spoken_groups` mirrors this to pre-render the neural audio.
    static func lines(for item: ExamItem, question: Int = 0) -> [SpeechLine] {
        switch item.type {
        case .listenResponse:
            return item.prompt.map { [SpeechLine(text: $0, voice: item.voice)] } ?? []
        case .listenConversation, .listenAnnouncement, .listenTalk:
            switch item.script {
            case let .dialogue(lines): return lines.map { SpeechLine(text: $0.line, voice: $0.voice, speaker: $0.speaker) }
            case let .monologue(text): return [SpeechLine(text: text, voice: item.voice)]
            case nil: return []
            }
        case .listenRepeat:
            return item.sentence.map { [SpeechLine(text: $0, voice: item.voice)] } ?? []
        case .interview:
            let qs = item.interviewQuestions ?? []
            return qs.indices.contains(question) ? [SpeechLine(text: qs[question], voice: "female")] : []
        default:
            return []
        }
    }

    /// "A: line" per dialogue line, or the monologue.
    static func transcript(for task: ExamTask) -> [(speaker: String?, text: String)] {
        guard let item = task.item else { return [] }
        switch item.type {
        case .listenResponse, .listenRepeat:
            return [(nil, item.prompt ?? item.sentence ?? "")]
        default:
            switch item.script {
            case let .dialogue(lines): return lines.map { ($0.speaker, $0.line) }
            case let .monologue(text): return [(nil, text)]
            case nil: return []
            }
        }
    }
}
