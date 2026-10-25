import SwiftUI
import TenazCore

/// Today's Brain bite as a calm row: topic and minutes, the title in Fraunces, the first lines, and
/// "Read it" (B) as a text button.
struct BrainBiteCard: View {
    let card: KnowledgeCard
    var readCount = 0
    var open: () -> Void = {}

    private var teaser: String {
        let sentences = card.body.split(separator: ".", omittingEmptySubsequences: true)
        return sentences.prefix(2).joined(separator: ".") + "."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            Label("Today's Brain bite · \(KnowledgeTopic.name(card.topic)) · \(card.readingMinutes) min",
                  systemImage: KnowledgeTopic.glyph(card.topic))
                .font(Typography.label)
                .foregroundStyle(Tokens.brand)
            Text(card.title)
                .font(Typography.title)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(teaser)
                .font(Typography.body)
                .foregroundStyle(Tokens.ink)
                .lineSpacing(4)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Tokens.Space.m) {
                Button(action: open) {
                    HStack(spacing: 6) {
                        Label("Read it", systemImage: "book.pages.fill")
                        KeyCap("B")
                    }
                }
                .buttonStyle(.ink)
                .keyboardShortcut("b", modifiers: [])
                Text("\(readCount) read so far").font(Typography.label).foregroundStyle(Tokens.brand)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// Display names and glyphs for Brain bite topics.
enum KnowledgeTopic {
    static func name(_ topic: String) -> String {
        switch topic {
        case "TECH": "Tech"
        case "AI": "AI"
        case "PSY": "Psychology"
        case "NEURO": "Brain"
        case "STARTUP": "Startups"
        default: topic.capitalized
        }
    }

    static func glyph(_ topic: String) -> String {
        switch topic {
        case "TECH": "cpu"
        case "AI": "sparkles"
        case "PSY": "person.fill.questionmark"
        case "NEURO": "brain"
        case "STARTUP": "chart.line.uptrend.xyaxis"
        default: "lightbulb.fill"
        }
    }
}
