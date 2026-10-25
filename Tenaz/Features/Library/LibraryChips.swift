import SwiftUI
import TenazCore

/// Level and lane (or kind) as one line of plain text.
struct LibraryChips: View {
    let item: CatalogItem
    var compact = false

    private var kindText: String {
        if item.kind == .book {
            return compact ? "Lane \(item.lane.rawValue)" : (item.lane == .a ? "Lane A · easy flow" : "Lane B · stretch")
        }
        return item.kind == .podcast ? "Podcast" : "Video"
    }

    var body: some View {
        Text("\(item.levelText) · \(kindText)")
            .font(Typography.label)
            .foregroundStyle(Tokens.brand)
            .lineLimit(1)
    }
}

extension CatalogItem {
    var kindGlyph: String {
        switch kind {
        case .book: "book.closed.fill"
        case .podcast: "headphones"
        case .video: "play.rectangle.fill"
        }
    }
}
