import SwiftUI
import TenazCore

/// A recommended book. `prominent` = the primary pick with the screen's one ink pill; otherwise a
/// calm list row with a text button.
struct RecommendationCard: View {
    let recommendation: Recommendation
    var prominent = false
    var start: () -> Void = {}

    @State private var hovering = false

    private var item: CatalogItem { recommendation.item }

    var body: some View {
        if prominent { hero } else { row }
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: Tokens.Space.xxl) {
            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                Text("Your next book")
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
                Text(item.title)
                    .font(Typography.display(52, weight: 900))
                    .foregroundStyle(Tokens.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.creator).font(Typography.title).foregroundStyle(Tokens.ink)
                LibraryChips(item: item)
                Text(item.why)
                    .font(Typography.body)
                    .foregroundStyle(Tokens.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(recommendation.why)
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: start) {
                    HStack(spacing: Tokens.Space.s) {
                        Text("Start with 5 minutes")
                        KeyCap("Return")
                    }
                }
                .buttonStyle(.fat)
                .keyboardShortcut(.defaultAction)
                .frame(maxWidth: 420)
                .padding(.top, Tokens.Space.s)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var row: some View {
        HStack(alignment: .center, spacing: Tokens.Space.l) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(Typography.title)
                    .foregroundStyle(Tokens.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(item.creator) · \(item.levelText) · \(item.lane == .a ? "easy flow" : "stretch")")
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
                    .lineLimit(1)
            }
            Spacer(minLength: Tokens.Space.m)
            Button("Start", systemImage: "play.fill", action: start)
                .buttonStyle(.ink)
                .fixedSize()
                .opacity(hovering ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .padding(.vertical, Tokens.Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { ProgressRule() }
    }
}

/// The book the learner is reading: time logged, pages, days left, and the ink pill "log today".
struct ContinueCard: View {
    let book: InProgressBook
    var log: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Space.xxl) {
            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                Text("Keep reading")
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
                Text(book.item.title)
                    .font(Typography.display(52, weight: 900))
                    .foregroundStyle(Tokens.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                Text(book.item.creator).font(Typography.title).foregroundStyle(Tokens.ink)
                LibraryChips(item: book.item)
                HStack(spacing: Tokens.Space.xl) {
                    stat("\(book.minutes)", "minutes")
                    stat("\(book.sessions)", book.sessions == 1 ? "session" : "sessions")
                    stat("\(book.pagesRead)", "pages")
                    stat("~\(book.daysLeft)", "days to go")
                }
                .padding(.vertical, Tokens.Space.s)
                Button(action: log) {
                    HStack(spacing: Tokens.Space.s) {
                        Text("Log today's reading")
                        KeyCap("Return")
                    }
                }
                .buttonStyle(.fat)
                .keyboardShortcut(.defaultAction)
                .frame(maxWidth: 420)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(Typography.display(34)).foregroundStyle(Tokens.ink)
            Text(label).font(Typography.label).foregroundStyle(Tokens.brand)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A podcast or channel to listen to this week.
struct ListenRow: View {
    let recommendation: Recommendation

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Space.m) {
            Image(systemName: recommendation.item.kindGlyph)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Tokens.ink)
                .frame(width: 24)
                .padding(.top, 3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(recommendation.item.title)
                    .font(Typography.title)
                    .foregroundStyle(Tokens.ink)
                    .lineLimit(1)
                Text(recommendation.item.why)
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
                    .lineLimit(1)
                Text("\(recommendation.item.levelText) · \(recommendation.item.minutes ?? 0) min an episode")
                    .font(Typography.caption)
                    .foregroundStyle(Tokens.brand)
            }
            Spacer(minLength: 0)
            if let link = recommendation.item.url.flatMap(URL.init(string:)) {
                Link(destination: link) { Image(systemName: "arrow.up.right").font(.system(size: 16, weight: .bold)) }
                    .foregroundStyle(Tokens.ink)
                    .accessibilityLabel("Open \(recommendation.item.title)")
            }
        }
        .padding(.vertical, Tokens.Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { ProgressRule() }
    }
}
