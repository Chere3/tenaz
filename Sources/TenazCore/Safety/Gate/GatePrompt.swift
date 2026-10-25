import Foundation

/// What the gate shows: a question about the learner's life and the one chunk they must use.
public struct GatePrompt: Equatable, Sendable {
    public var id: String
    public var question: String
    public var chunk: String
    /// Why this chunk: "you missed it twice today" or "today's chunk".
    public var chunkIsForgottenWord: Bool
    public var kind: WritingKind
    /// The item's `text` (a story opener, two options to compare), shown above the sheet.
    public var text: String?
    /// The question plus the item's kind lines for Claude (`GradingRubric.kindLines`); empty for the fallback.
    public var taskPrompt: String

    public init(id: String, question: String, chunk: String, chunkIsForgottenWord: Bool = false,
                kind: WritingKind = .personal, text: String? = nil, taskPrompt: String = "") {
        self.id = id
        self.question = question
        self.chunk = chunk
        self.chunkIsForgottenWord = chunkIsForgottenWord
        self.kind = kind
        self.text = text
        self.taskPrompt = taskPrompt
    }

    /// The `lifeParagraph` items the gate may show: a short answer in their own words (no summaries,
    /// corrections or translations), never the placement's own items.
    public static func pool(_ items: [ExamItem]) -> [ExamItem] {
        items.filter { item in
            item.type == .lifeParagraph && !(item.prompt ?? "").isEmpty && !item.id.hasPrefix("placement")
                && item.writingKind?.fitsGate == true
        }
    }

    /// Picks the prompt for one unlock and its chunk: a word failed twice today if there is one, else
    /// the first `mustUse` entry that is a real chunk (instructions such as "use the present perfect"
    /// are skipped), else "follow up on".
    /// - Parameters:
    ///   - pendingId: the prompt of a gate that closed before it was completed or skipped; it comes back.
    ///   - history: every exposure row (see `ExposurePicker`).
    public static func pick(items: [ExamItem], history: [ExposureRecord], pendingId: String?, now: Date,
                            forgottenWords: [String], rng: inout SeededRandom) -> GatePrompt {
        let pool = pool(items)
        let picker = ExposurePicker(surface: .gate, library: items, history: history, now: now)
        guard let item = pool.first(where: { $0.id == pendingId }) ?? picker.pick(pool, rng: &rng),
              let question = item.prompt else {
            return GatePrompt(id: "gate-fallback", question: "What is your plan for today, and what could go wrong?",
                              chunk: forgottenWords.first ?? "follow up on", chunkIsForgottenWord: !forgottenWords.isEmpty)
        }
        let lexical = (item.mustUse ?? []).first { entry in
            let e = entry.lowercased()
            return !e.hasPrefix("use ") && !e.contains("tense") && e.split(separator: " ").count <= 4
        }
        let kind = item.writingKind ?? .personal
        let text = item.text.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        // The question and the kind lines, without "Minimum words": the gate asks for 25-40 words.
        let task = "\(question)\n\(GradingRubric.kindLines(for: item))"
        if let forgotten = forgottenWords.first {
            return GatePrompt(id: item.id, question: question, chunk: forgotten, chunkIsForgottenWord: true,
                              kind: kind, text: text, taskPrompt: task)
        }
        return GatePrompt(id: item.id, question: question, chunk: lexical ?? "follow up on", kind: kind, text: text, taskPrompt: task)
    }

    /// The task text stored with the paragraph for Claude to grade.
    public var gradingPrompt: String {
        taskPrompt.isEmpty ? "\(question) Use “\(chunk)”." : "\(taskPrompt)\nUse “\(chunk)”."
    }
}
