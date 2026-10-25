import TenazCore

/// Today's short writing prompt (a `lifeParagraph` item of any kind, picked by `ExposurePicker`).
struct TodayWritePrompt: Equatable {
    var id: String
    var prompt: String
    var mustUse: [String]
    var minWords: Int
    var kind: WritingKind = .personal
    /// The text to work on (summary, rewrite, correct, translate, chart; a story opener).
    var text: String?
    var group: String?
    /// What Claude grades against (`GradingRubric.taskPrompt`); empty falls back to `prompt`.
    var taskPrompt = ""

    init(id: String, prompt: String, mustUse: [String], minWords: Int, kind: WritingKind = .personal,
         text: String? = nil, group: String? = nil, taskPrompt: String = "") {
        self.id = id
        self.prompt = prompt
        self.mustUse = mustUse
        self.minWords = minWords
        self.kind = kind
        self.text = text
        self.group = group
        self.taskPrompt = taskPrompt
    }

    init(_ item: ExamItem) {
        let text = item.text.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        self.init(id: item.id, prompt: item.prompt ?? "", mustUse: item.mustUse ?? [], minWords: item.minWords ?? 40,
                  kind: item.writingKind ?? .personal, text: text, group: item.group, taskPrompt: GradingRubric.taskPrompt(for: item))
    }

    /// The kind's instruction, unless the prompt already says it ("Rewrite this…" under "Rewrite this for your manager").
    var instruction: String? { kind.instructionLine(under: prompt) }
}

extension WritingKind {
    /// The instruction line to show under `prompt`, or nil when there is none or the prompt starts with the same verb.
    func instructionLine(under prompt: String) -> String? {
        guard let instruction else { return nil }
        // Five letters, so "Summarize" matches "Summarise".
        let verb = { (s: String) in s.split(separator: " ").first.map { String($0.lowercased().prefix(5)) } }
        return verb(instruction) == verb(prompt) ? nil : instruction
    }
}
