import SwiftUI

/// The one secondary line on Today: "Also today: one sentence · quick check", each phrase a link.
struct HomeAlsoToday: View {
    let summary: TodaySummary
    let actions: HomeActions

    private struct Item: Identifiable {
        let id: String
        let title: String
        let help: String
        let action: () -> Void
    }

    private var items: [Item] {
        var items: [Item] = []
        if summary.stage == .egg {
            items.append(Item(id: "hatch", title: "hatch Tena", help: "Hatch Tena", action: actions.hatch))
        }
        let wrote = summary.productionsToday >= summary.minimumProductions
        items.append(Item(id: "write", title: wrote ? "another sentence" : "one sentence",
                          help: summary.write?.prompt ?? "Write a sentence about your day", action: actions.write))
        if summary.placementTaken {
            items.append(Item(id: "check", title: "quick check",
                              help: "Daily check, about \(summary.dailyCheckMinutes) minutes", action: actions.dailyCheck))
        }
        return items
    }

    var body: some View {
        // Drops the "Also today:" lead-in before it would clip in a narrow window.
        ViewThatFits(in: .horizontal) {
            line(lead: "Also today: ")
            line(lead: "")
        }
        .font(.system(size: 17, weight: .medium, design: .rounded))
        .foregroundStyle(Tokens.ink)
    }

    private func line(lead: String) -> some View {
        HStack(spacing: 0) {
            if !lead.isEmpty { Text(lead) }
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Text(" · ") }
                InlineLink(item.title, help: item.help, action: item.action)
            }
        }
        .lineLimit(1)
        .fixedSize()
    }
}

/// A phrase inside a sentence that is also a button: ink, underlined, no padding or fill, so it sits
/// on the text baseline. `.buttonStyle(.ink)` is for standalone actions and pads too much for this.
private struct InlineLink: View {
    let title: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    init(_ title: String, help: String, action: @escaping () -> Void) {
        self.title = title
        self.help = help
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .underline(true, color: Tokens.ink.opacity(hovering ? 1 : 0.45))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}
