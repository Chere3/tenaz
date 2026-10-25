import Foundation

/// The catalog and the Brain bites, loaded from a `Content` folder, plus a validator the app runs at
/// load time and the tests run on the bundled files.
public struct LibraryContent: Sendable {
    public var catalog: [CatalogItem]
    public var knowledge: [KnowledgeCard]

    public init(catalog: [CatalogItem], knowledge: [KnowledgeCard]) {
        self.catalog = catalog
        self.knowledge = knowledge
    }

    public static func load(from root: URL) throws -> LibraryContent {
        LibraryContent(catalog: try CatalogItem.loadAll(from: root.appendingPathComponent("catalog.json")),
                       knowledge: try KnowledgeCard.loadAll(from: root.appendingPathComponent("knowledge.json")))
    }

    public func item(_ id: String) -> CatalogItem? { catalog.first { $0.id == id } }

    /// Every rule from PLAN F11: unique ids, valid levels, a length per kind, 120-200 word cards
    /// whose 3 targets exist in the deck and appear in the text, and a go-deeper item that exists.
    public func problems(vocab: [VocabEntry]) -> [String] {
        var p: [String] = []
        let vocabById = Dictionary(vocab.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var seen = Set<String>()
        for item in catalog {
            if !seen.insert(item.id).inserted { p.append("\(item.id): duplicate id") }
            if CEFRLevel(label: item.cefr) == nil { p.append("\(item.id): bad cefr \(item.cefr)") }
            if item.topics.isEmpty { p.append("\(item.id): no topics") }
            if item.why.isEmpty { p.append("\(item.id): no why") }
            switch item.kind {
            case .book: if (item.words ?? 0) <= 0 { p.append("\(item.id): book needs words") }
            case .podcast, .video: if (item.minutes ?? 0) <= 0 { p.append("\(item.id): needs minutes") }
            }
        }
        let catalogIds = Set(catalog.map(\.id))
        for card in knowledge {
            if !seen.insert(card.id).inserted { p.append("\(card.id): duplicate id") }
            if !KnowledgeCard.wordRange.contains(card.wordCount) { p.append("\(card.id): \(card.wordCount) words") }
            if !KnowledgeCard.topics.contains(card.topic) { p.append("\(card.id): bad topic \(card.topic)") }
            if CEFRLevel(label: card.cefr) == nil { p.append("\(card.id): bad cefr") }
            if card.source != "tenaz-original" { p.append("\(card.id): source must be tenaz-original") }
            if card.targetNoteIds.count != 3 { p.append("\(card.id): needs 3 targets") }
            for id in card.targetNoteIds {
                guard let entry = vocabById[id] else { p.append("\(card.id): unknown target \(id)"); continue }
                if !WordForms.text(card.body, mentions: entry.headword) { p.append("\(card.id): body lacks \(entry.headword)") }
            }
            if !catalogIds.contains(card.goDeeper) { p.append("\(card.id): unknown goDeeper \(card.goDeeper)") }
            if card.question.isEmpty { p.append("\(card.id): no question") }
        }
        return p
    }
}
