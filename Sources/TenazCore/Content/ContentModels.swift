import Foundation

/// One vocabulary card as written in `Content/vocab/*.json` (see Content/FORMAT.md).
public struct VocabEntry: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var headword: String
    public var pos: String
    public var cefr: String
    public var es: String
    public var definition: String
    public var example: String
    public var exampleEs: String
    public var cloze: String
    public var answer: String
    public var distractors: [String]
    public var collocations: [String]
    public var note: String
    public var tags: [String]
    // Provenance (optional; see Content/FORMAT.md and Content/licenses.json)
    public var source: String?
    public var license: String?

    public var level: CEFRLevel { CEFRLevel(label: cefr) ?? .b2 }
}

public struct ChoiceQuestion: Codable, Hashable, Sendable {
    public var q: String
    public var options: [String]
    public var answer: Int
    public var explanation: String?
}

public struct ScriptLine: Codable, Hashable, Sendable {
    public var speaker: String
    public var voice: String?
    public var line: String
}

/// A listening script is either a list of dialogue lines or one monologue string.
public enum ListeningScript: Codable, Hashable, Sendable {
    case dialogue([ScriptLine])
    case monologue(String)

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .monologue(s) } else { self = .dialogue(try c.decode([ScriptLine].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case let .dialogue(lines): try c.encode(lines)
        case let .monologue(s): try c.encode(s)
        }
    }
}

/// Every exam item type from Content/FORMAT.md, decoded into one flat struct so the bank is simple to query.
public struct ExamItem: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case completeWords, readDaily, readAcademic
        case listenResponse, listenConversation, listenAnnouncement, listenTalk
        case buildSentence, grammarMC
        case writeEmail, writeDiscussion, lifeParagraph
        case listenRepeat, interview
    }

    public var id: String
    public var type: Kind
    public var cefr: String
    public var skill: String?
    // Reading / listening
    public var title: String?
    public var text: String?
    public var passage: String?
    public var prompt: String?
    public var voice: String?
    public var script: ListeningScript?
    public var questions: [ChoiceQuestion]?
    // Single-question items
    public var sentence: String?
    public var options: [String]?
    public var answer: AnswerValue?
    public var explanation: String?
    public var pattern: String?
    // Build a sentence
    public var context: String?
    public var chunks: [String]?
    public var accepted: [String]?
    // Writing
    public var situation: String?
    public var tasks: [String]?
    public var professor: String?
    public var studentA: String?
    public var studentB: String?
    public var mustUse: [String]?
    public var minWords: Int?
    // Speaking
    public var topic: String?
    public var interviewQuestions: [String]?
    // Writing kind (see `WritingKind`) and model answers for kinds graded against one
    public var kind: String?
    public var reference: [String]?
    // Provenance (optional; see Content/FORMAT.md and Content/licenses.json)
    public var source: String?
    public var sourceId: String?
    public var license: String?
    public var tier: String?
    /// Items sharing one underlying text: exposure control treats the group as one item.
    public var group: String?
    public var origin: String?
    public var topics: [String]?

    public var level: CEFRLevel { CEFRLevel(label: cefr) ?? .b2 }

    enum CodingKeys: String, CodingKey {
        case id, type, cefr, skill, title, text, passage, prompt, voice, script, questions
        case sentence, options, answer, explanation, pattern, context, chunks, accepted
        case situation, tasks, professor, studentA, studentB, mustUse, minWords, topic
        case kind, reference, source, sourceId, license, tier, group, origin, topics
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        type = try c.decode(Kind.self, forKey: .type)
        cefr = try c.decode(String.self, forKey: .cefr)
        skill = try c.decodeIfPresent(String.self, forKey: .skill)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        text = try c.decodeIfPresent(String.self, forKey: .text)
        passage = try c.decodeIfPresent(String.self, forKey: .passage)
        prompt = try c.decodeIfPresent(String.self, forKey: .prompt)
        voice = try c.decodeIfPresent(String.self, forKey: .voice)
        script = try c.decodeIfPresent(ListeningScript.self, forKey: .script)
        // `questions` is choice questions for reading/listening, plain strings for interviews.
        if type == .interview {
            interviewQuestions = try c.decodeIfPresent([String].self, forKey: .questions)
            questions = nil
        } else {
            questions = try c.decodeIfPresent([ChoiceQuestion].self, forKey: .questions)
        }
        sentence = try c.decodeIfPresent(String.self, forKey: .sentence)
        options = try c.decodeIfPresent([String].self, forKey: .options)
        answer = try c.decodeIfPresent(AnswerValue.self, forKey: .answer)
        explanation = try c.decodeIfPresent(String.self, forKey: .explanation)
        pattern = try c.decodeIfPresent(String.self, forKey: .pattern)
        context = try c.decodeIfPresent(String.self, forKey: .context)
        chunks = try c.decodeIfPresent([String].self, forKey: .chunks)
        accepted = try c.decodeIfPresent([String].self, forKey: .accepted)
        situation = try c.decodeIfPresent(String.self, forKey: .situation)
        tasks = try c.decodeIfPresent([String].self, forKey: .tasks)
        professor = try c.decodeIfPresent(String.self, forKey: .professor)
        studentA = try c.decodeIfPresent(String.self, forKey: .studentA)
        studentB = try c.decodeIfPresent(String.self, forKey: .studentB)
        mustUse = try c.decodeIfPresent([String].self, forKey: .mustUse)
        minWords = try c.decodeIfPresent(Int.self, forKey: .minWords)
        topic = try c.decodeIfPresent(String.self, forKey: .topic)
        kind = try c.decodeIfPresent(String.self, forKey: .kind)
        reference = try c.decodeIfPresent([String].self, forKey: .reference)
        source = try c.decodeIfPresent(String.self, forKey: .source)
        sourceId = try c.decodeIfPresent(String.self, forKey: .sourceId)
        license = try c.decodeIfPresent(String.self, forKey: .license)
        tier = try c.decodeIfPresent(String.self, forKey: .tier)
        group = try c.decodeIfPresent(String.self, forKey: .group)
        origin = try c.decodeIfPresent(String.self, forKey: .origin)
        topics = try c.decodeIfPresent([String].self, forKey: .topics)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(type, forKey: .type)
        try c.encode(cefr, forKey: .cefr)
        try c.encodeIfPresent(skill, forKey: .skill)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(text, forKey: .text)
        try c.encodeIfPresent(passage, forKey: .passage)
        try c.encodeIfPresent(prompt, forKey: .prompt)
        try c.encodeIfPresent(voice, forKey: .voice)
        try c.encodeIfPresent(script, forKey: .script)
        if type == .interview { try c.encodeIfPresent(interviewQuestions, forKey: .questions) } else { try c.encodeIfPresent(questions, forKey: .questions) }
        try c.encodeIfPresent(sentence, forKey: .sentence)
        try c.encodeIfPresent(options, forKey: .options)
        try c.encodeIfPresent(answer, forKey: .answer)
        try c.encodeIfPresent(explanation, forKey: .explanation)
        try c.encodeIfPresent(pattern, forKey: .pattern)
        try c.encodeIfPresent(context, forKey: .context)
        try c.encodeIfPresent(chunks, forKey: .chunks)
        try c.encodeIfPresent(accepted, forKey: .accepted)
        try c.encodeIfPresent(situation, forKey: .situation)
        try c.encodeIfPresent(tasks, forKey: .tasks)
        try c.encodeIfPresent(professor, forKey: .professor)
        try c.encodeIfPresent(studentA, forKey: .studentA)
        try c.encodeIfPresent(studentB, forKey: .studentB)
        try c.encodeIfPresent(mustUse, forKey: .mustUse)
        try c.encodeIfPresent(minWords, forKey: .minWords)
        try c.encodeIfPresent(topic, forKey: .topic)
        try c.encodeIfPresent(kind, forKey: .kind)
        try c.encodeIfPresent(reference, forKey: .reference)
        try c.encodeIfPresent(source, forKey: .source)
        try c.encodeIfPresent(sourceId, forKey: .sourceId)
        try c.encodeIfPresent(license, forKey: .license)
        try c.encodeIfPresent(tier, forKey: .tier)
        try c.encodeIfPresent(group, forKey: .group)
        try c.encodeIfPresent(origin, forKey: .origin)
        try c.encodeIfPresent(topics, forKey: .topics)
    }
}

/// `answer` is an option index for choice items and a sentence for buildSentence.
public enum AnswerValue: Codable, Hashable, Sendable {
    case index(Int)
    case text(String)

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) { self = .index(i) } else { self = .text(try c.decode(String.self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case let .index(i): try c.encode(i)
        case let .text(s): try c.encode(s)
        }
    }

    public var index: Int? { if case let .index(i) = self { i } else { nil } }
    public var text: String? { if case let .text(s) = self { s } else { nil } }
}

/// Loads all content JSON files from a folder laid out like `Content/`.
public struct ContentLibrary: Sendable {
    public var vocab: [VocabEntry]
    public var items: [ExamItem]

    public init(vocab: [VocabEntry], items: [ExamItem]) {
        self.vocab = vocab
        self.items = items
    }

    public static func load(from root: URL) throws -> ContentLibrary {
        let decoder = JSONDecoder()
        func files(_ sub: String) -> [URL] {
            let dir = root.appendingPathComponent(sub)
            let urls = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            return urls.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        }
        var vocab: [VocabEntry] = []
        for url in files("vocab") {
            do { vocab += try decoder.decode([VocabEntry].self, from: Data(contentsOf: url)) } catch {
                throw ContentError.decode(file: url.lastPathComponent, underlying: String(describing: error))
            }
        }
        var items: [ExamItem] = []
        for url in files("items") {
            do { items += try decoder.decode([ExamItem].self, from: Data(contentsOf: url)) } catch {
                throw ContentError.decode(file: url.lastPathComponent, underlying: String(describing: error))
            }
        }
        return ContentLibrary(vocab: vocab, items: items)
    }

    public func items(of kind: ExamItem.Kind) -> [ExamItem] { items.filter { $0.type == kind } }
}

public enum ContentError: Error, CustomStringConvertible {
    case decode(file: String, underlying: String)
    public var description: String {
        switch self {
        case let .decode(file, underlying): "Could not read \(file): \(underlying)"
        }
    }
}
