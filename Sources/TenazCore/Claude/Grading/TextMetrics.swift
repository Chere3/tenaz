import Foundation

/// Local surface metrics sent to Claude with every response (PLAN F6, [04 §3.1]).
public struct TextMetrics: Codable, Hashable, Sendable {
    public var wordCount: Int
    public var typeTokenRatio: Double
    public var meanSentenceLength: Double
    public var connectors: [String]
    /// Share of content words (4+ letters) that repeat.
    public var repeatedWordRate: Double

    static let connectorList = [
        "however", "although", "because", "therefore", "moreover", "meanwhile", "instead", "otherwise",
        "for example", "for instance", "in addition", "on the other hand", "as a result", "even though",
        "first", "then", "finally", "also", "but", "so", "while", "unless", "since", "whereas",
    ]

    public init(text: String) {
        let words = text.lowercased().split { !$0.isLetter && $0 != "'" }.map(String.init)
        wordCount = words.count
        typeTokenRatio = words.isEmpty ? 0 : Double(Set(words).count) / Double(words.count)
        let sentences = text.split { ".!?".contains($0) }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        meanSentenceLength = sentences.isEmpty ? 0 : Double(words.count) / Double(sentences.count)
        let joined = " " + words.joined(separator: " ") + " "
        connectors = Self.connectorList.filter { joined.contains(" \($0) ") }
        let content = words.filter { $0.count >= 4 }
        repeatedWordRate = content.isEmpty ? 0 : Double(content.count - Set(content).count) / Double(content.count)
    }
}
