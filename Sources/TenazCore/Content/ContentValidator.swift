import Foundation

/// A gap in a "Complete the Words" passage: the visible start of the word and the hidden rest.
public struct WordGap: Hashable, Sendable {
    public var visible: String
    public var hidden: String
}

public enum PassageSegment: Hashable, Sendable {
    case text(String)
    case gap(WordGap)
}

public enum CompleteWordsParser {
    /// Splits `tech{{nology}} is` into text and gaps. The visible part is the run of letters
    /// right before `{{`.
    public static func parse(_ passage: String) -> [PassageSegment] {
        var segments: [PassageSegment] = []
        var rest = Substring(passage)
        while let open = rest.range(of: "{{"), let close = rest.range(of: "}}", range: open.upperBound..<rest.endIndex) {
            let before = rest[rest.startIndex..<open.lowerBound]
            let visibleStart = before.lastIndex(where: { !$0.isLetter }).map { before.index(after: $0) } ?? before.startIndex
            let plain = String(before[before.startIndex..<visibleStart])
            if !plain.isEmpty { segments.append(.text(plain)) }
            segments.append(.gap(WordGap(visible: String(before[visibleStart...]), hidden: String(rest[open.upperBound..<close.lowerBound]))))
            rest = rest[close.upperBound...]
        }
        if !rest.isEmpty { segments.append(.text(String(rest))) }
        return segments
    }

    public static func gaps(_ passage: String) -> [WordGap] {
        parse(passage).compactMap { if case let .gap(g) = $0 { g } else { nil } }
    }
}

/// Checks the rules in Content/FORMAT.md. The app drops invalid entries at load time; tests fail on them.
public enum ContentValidator {
    public static func problems(in entry: VocabEntry) -> [String] {
        var p: [String] = []
        if entry.cloze.components(separatedBy: "____").count != 2 { p.append("cloze must contain ____ exactly once") }
        if entry.cloze.replacingOccurrences(of: "____", with: entry.answer) != entry.example { p.append("cloze + answer != example") }
        if entry.distractors.count != 3 { p.append("needs 3 distractors") }
        let lowered = Set(entry.distractors.map { $0.lowercased() })
        if lowered.count != entry.distractors.count || lowered.contains(entry.answer.lowercased()) { p.append("distractors must be distinct and differ from answer") }
        if CEFRLevel(label: entry.cefr) == nil { p.append("bad cefr \(entry.cefr)") }
        return p
    }

    public static func problems(in item: ExamItem) -> [String] {
        var p: [String] = []
        if CEFRLevel(label: item.cefr) == nil { p.append("bad cefr \(item.cefr)") }
        func checkChoice(_ options: [String]?, _ answer: Int?) {
            guard let options, let answer else { p.append("missing options/answer"); return }
            if options.count != 4 { p.append("needs 4 options") }
            if !(0..<options.count).contains(answer) { p.append("answer index out of range") }
        }
        func checkQuestions() {
            guard let qs = item.questions, !qs.isEmpty else { p.append("missing questions"); return }
            for q in qs { checkChoice(q.options, q.answer) }
        }
        switch item.type {
        case .completeWords:
            let gaps = CompleteWordsParser.gaps(item.passage ?? "")
            if gaps.count < 6 { p.append("completeWords needs gaps (has \(gaps.count))") }
            if gaps.contains(where: { $0.visible.isEmpty || $0.hidden.isEmpty }) { p.append("empty gap part") }
        case .readDaily, .readAcademic:
            if (item.text ?? "").isEmpty { p.append("missing text") }
            checkQuestions()
        case .listenConversation, .listenAnnouncement, .listenTalk:
            if item.script == nil { p.append("missing script") }
            checkQuestions()
        case .listenResponse:
            if (item.prompt ?? "").isEmpty { p.append("missing prompt") }
            checkChoice(item.options, item.answer?.index)
        case .grammarMC:
            if !(item.sentence ?? "").contains("____") { p.append("sentence needs ____") }
            checkChoice(item.options, item.answer?.index)
        case .buildSentence:
            guard let chunks = item.chunks, let answer = item.answer?.text else { p.append("missing chunks/answer"); break }
            let normalized = { (s: String) in s.lowercased().filter { $0.isLetter || $0.isNumber } }
            if normalized(chunks.joined()).sorted() != normalized(answer).sorted() { p.append("chunks don't spell the answer") }
        case .writeEmail:
            if (item.situation ?? "").isEmpty || (item.tasks ?? []).isEmpty { p.append("missing situation/tasks") }
        case .writeDiscussion:
            if (item.professor ?? "").isEmpty { p.append("missing professor post") }
        case .lifeParagraph:
            if (item.prompt ?? "").isEmpty { p.append("missing prompt") }
        case .listenRepeat:
            if (item.sentence ?? "").isEmpty { p.append("missing sentence") }
        case .interview:
            if (item.interviewQuestions ?? []).isEmpty { p.append("missing interview questions") }
        }
        // Writing kinds (dataset plan §7): only the writing types are checked.
        let allowed = WritingKind.allowed(for: item.type)
        if !allowed.isEmpty, let kind = item.kind {
            if let known = WritingKind(rawValue: kind), allowed.contains(known) {
                if known.needsText, (item.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    p.append("kind \(kind) needs text")
                }
            } else {
                p.append("unknown kind \(kind) for \(item.type.rawValue)")
            }
        }
        return p
    }

    /// Returns a library with invalid or duplicate entries removed, plus the problems found.
    public static func cleaned(_ library: ContentLibrary) -> (ContentLibrary, [String]) {
        var report: [String] = []
        var seen = Set<String>()
        let vocab = library.vocab.filter { e in
            let p = problems(in: e)
            if !p.isEmpty { report.append("\(e.id): \(p.joined(separator: "; "))"); return false }
            return seen.insert(e.id).inserted
        }
        let items = library.items.filter { i in
            let p = problems(in: i)
            if !p.isEmpty { report.append("\(i.id): \(p.joined(separator: "; "))"); return false }
            return seen.insert(i.id).inserted
        }
        return (ContentLibrary(vocab: vocab, items: items), report)
    }
}
