import SwiftUI
import TenazCore

/// The Library (PLAN F11): one hero (the book to keep reading, or the one to start), then calm lists:
/// today's Brain bite, what to read next, what to listen to, and the reading log.
struct LibraryScreen: View {
    let model: LibraryModel
    var start: (CatalogItem) -> Void = { _ in }
    var log: (CatalogItem) -> Void = { _ in }
    var openBrainBite: (KnowledgeCard) -> Void = { _ in }

    var body: some View {
        ProgressPage(spacing: Tokens.Space.l) {
            ProgressHeader(eyebrow: "Read & listen", title: "Library", subtitle: "\(model.minutesThisWeek) min read & heard this week")
            if let book = model.inProgress.first {
                ContinueCard(book: book) { log(book.item) }
            } else if let primary = model.reading?.primary {
                RecommendationCard(recommendation: primary, prominent: true) { start(primary.item) }
            }
            if let bite = model.brainBite {
                VStack(alignment: .leading, spacing: 0) {
                    ProgressRule().padding(.bottom, Tokens.Space.m)
                    BrainBiteCard(card: bite, readCount: model.brainBitesRead) { openBrainBite(bite) }
                        .frame(maxWidth: 720, alignment: .leading)
                }
            }
            if let set = model.reading {
                VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                    ProgressSectionLabel(model.inProgress.isEmpty ? "Or try" : "Next up", detail: "Levels are estimates")
                    VStack(spacing: 0) {
                        ForEach(model.inProgress.isEmpty ? set.alternates : set.all) { r in
                            RecommendationCard(recommendation: r) { start(r.item) }
                        }
                    }
                }
            }
            HStack(alignment: .top, spacing: Tokens.Space.xxl) {
                VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                    ProgressSectionLabel("Listen this week")
                    ForEach(model.listening) { ListenRow(recommendation: $0) }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                    ProgressSectionLabel("Reading log")
                    if model.recent.isEmpty {
                        Text("Nothing logged yet. Five minutes counts.")
                            .font(Typography.label)
                            .foregroundStyle(Tokens.brand)
                    }
                    ForEach(model.recent) { line in
                        HStack(spacing: Tokens.Space.xs) {
                            Image(systemName: line.glyph)
                                .foregroundStyle(Tokens.brand)
                                .font(.system(size: 13, weight: .bold))
                                .frame(width: 20)
                            if let understood = line.understood {
                                Image(systemName: understood >= ReadingCheck.minimumComprehension ? "checkmark.circle.fill" : "circle.dashed")
                                    .foregroundStyle(understood >= ReadingCheck.minimumComprehension ? Tokens.correct : Tokens.brand)
                                    .font(.system(size: 12, weight: .bold))
                                    .accessibilityLabel(understood >= ReadingCheck.minimumComprehension ? "Understood" : "Partly understood")
                            }
                            Text(line.title).font(Typography.labelBold).foregroundStyle(Tokens.ink).lineLimit(1)
                            Spacer(minLength: Tokens.Space.xs)
                            Text("\(line.minutes) min").font(Typography.numeric(13)).foregroundStyle(Tokens.ink)
                            Text(line.when).font(Typography.caption).foregroundStyle(Tokens.brand).frame(width: 72, alignment: .trailing)
                        }
                        .padding(.vertical, Tokens.Space.s)
                        .overlay(alignment: .bottom) { ProgressRule() }
                        .accessibilityElement(children: .combine)
                    }
                }
                .frame(width: 400, alignment: .topLeading)
            }
        }
    }
}
