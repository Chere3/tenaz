/// What a writing (or interview) prompt asks the learner to do (dataset plan §7). Stored as the optional
/// `kind` string on an item; a missing `kind` is the type's default (personal / request / opinion / interview).
public enum WritingKind: String, CaseIterable, Sendable {
    // lifeParagraph
    case personal, advice, story, compare, describe, summary, rewrite, correct, translate, chart
    // writeEmail
    case request, complaint, update, reply, recap
    // writeDiscussion
    case opinion, proscons
    // interview
    case interview

    /// The kinds an item type may carry; empty for non-writing types (their `kind` is not checked).
    public static func allowed(for type: ExamItem.Kind) -> [WritingKind] {
        switch type {
        case .lifeParagraph: [.personal, .advice, .story, .compare, .describe, .summary, .rewrite, .correct, .translate, .chart]
        case .writeEmail: [.request, .complaint, .update, .reply, .recap]
        case .writeDiscussion: [.opinion, .proscons]
        case .interview: [.interview]
        default: []
        }
    }

    public static func defaultKind(for type: ExamItem.Kind) -> WritingKind? { allowed(for: type).first }

    /// Kinds that work on the text in `text` (the item must carry it).
    public var needsText: Bool { [.summary, .rewrite, .correct, .translate, .chart].contains(self) }

    /// Kinds that fit the chunk-based unlock gate (2-3 sentences of their own words).
    public var fitsGate: Bool { [.personal, .advice, .story, .compare, .describe].contains(self) }

    /// The instruction line shown with the prompt; nil for a plain question about their life.
    public var instruction: String? {
        switch self {
        case .advice: "Give your advice and one reason"
        case .story: "Continue the story"
        case .compare: "Compare both options, then choose one"
        case .describe: "Describe it step by step"
        case .summary: "Summarise this in 2-3 sentences"
        case .rewrite: "Rewrite this for your manager"
        case .correct: "Fix the mistakes"
        case .translate: "Translate into natural English"
        case .chart: "Describe the trend and one comparison"
        default: nil
        }
    }

    /// The input placeholder; nil keeps the surface's own default.
    public var placeholder: String? {
        switch self {
        case .advice: "I would suggest… because…"
        case .story: "Then…"
        case .compare: "The first option is better for… but…"
        case .describe: "First, … Then, …"
        case .summary: "The main point is that…"
        case .rewrite: "Hi, could you…"
        case .correct: "Type the corrected text…"
        case .translate: "Type your English version…"
        case .chart: "Overall, … rose from … to …"
        default: nil
        }
    }

    /// One rubric line for Claude (dataset plan §8.3).
    public var criterion: String {
        switch self {
        case .personal: "answers the question with relevant detail from their own life or work"
        case .advice: "gives clear, practical advice with at least one reason"
        case .story: "continues the story coherently from the opener, in a consistent tense"
        case .compare: "compares both options on the same points and reaches a conclusion"
        case .describe: "describes the process or place clearly and in a logical order"
        case .summary: "covers the main point of the text in their own words, without minor details"
        case .rewrite: "keeps the meaning of the text and changes the register as asked"
        case .correct: "fixes all the errors in the text without changing its meaning"
        case .translate: "is an accurate and natural English version of the Spanish text"
        case .chart: "reports the overall trend and at least one comparison with correct figures"
        case .request: "makes the request clearly and politely and covers every bullet"
        case .complaint: "states the problem and the wanted remedy firmly but politely"
        case .update: "gives the status, what changed and the next steps"
        case .reply: "answers every point of the incoming message"
        case .recap: "turns every note into a clear follow-up with owners and dates"
        case .opinion: "takes a clear position, supports it and adds to the discussion"
        case .proscons: "covers both advantages and disadvantages and weighs them"
        case .interview: "answers each question and develops it with reasons and examples"
        }
    }
}

extension ExamItem {
    /// The item's writing kind: its `kind`, else the type's default. Nil for non-writing types and
    /// for a `kind` the type does not allow (the validator rejects those).
    public var writingKind: WritingKind? {
        let allowed = WritingKind.allowed(for: type)
        guard let kind else { return allowed.first }
        return WritingKind(rawValue: kind).flatMap { allowed.contains($0) ? $0 : nil }
    }
}
