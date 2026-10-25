import SwiftUI

/// Today, drawn from a `TodaySummary` as one Full Bleed screen: the flood says the state, Tena stands
/// big and cropped on the left, and the right holds one hero number, the one ink pill, an "Also today"
/// line and three plain stats. Pure (no environment), so snapshots render it with sample data.
struct HomeBoard: View {
    let summary: TodaySummary
    var actions = HomeActions()
    var now: Date = .now

    var body: some View {
        GeometryReader { proxy in
            let layout = HomeLayout(window: proxy.size, ink: TenaInk.bounds(stage: summary.stage, mood: mood))
            ZStack(alignment: .topLeading) {
                HomeTena(summary: summary, mood: mood, layout: layout, hatch: actions.hatch)
                VStack(alignment: .leading, spacing: 0) {
                    HomeLead(summary: summary, heroSize: proxy.size.height > 900 && !layout.stacked ? 200 : 160, action: actions.primary)
                    HomeAlsoToday(summary: summary, actions: actions)
                        .padding(.top, Tokens.Space.l)
                    HomeStats(summary: summary, showLevel: actions.level)
                        .padding(.top, 36)
                }
                .frame(width: layout.columnWidth, alignment: .leading)
                .padding(.top, layout.stacked ? HomeLayout.margin - 24 : 0)
                .frame(height: proxy.size.height, alignment: layout.stacked ? .top : .center)
                .offset(x: layout.columnLeading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .clipped()
        .flood(flood)
    }

    private var flood: Flood { Self.flood(summary, now: now) }
    private var mood: TenaMood { Self.mood(summary, flood: flood) }

    /// Mint once the day is done, oxblood late in the evening with the streak still unearned, else yellow.
    /// Also drives the Dock icon (`DockIcon`).
    static func flood(_ summary: TodaySummary, now: Date) -> Flood {
        if summary.primary == .allDone { return .good }
        let lateEvening = Calendar.current.component(.hour, from: now) >= 20
        if lateEvening, !summary.qualifiedToday, summary.streakDays > 0 { return .risk }
        return .turn
    }

    /// Tena's mood follows the flood: a streak at risk never shows a cheerful face.
    static func mood(_ summary: TodaySummary, flood: Flood) -> TenaMood {
        guard flood == .risk else { return summary.mood }
        switch summary.mood {
        case .happy, .ecstatic, .proud, .curious, .neutral, .focused: return .nagging
        default: return summary.mood
        }
    }
}

/// Where Tena sits and where the text column starts, from the window size and her measured ink.
/// She is cropped by the bottom edge (the lowest sixth of her) and her left gill tips by the left edge.
/// Side by side when the window is wide; in a tall window she grows under the text instead.
struct HomeLayout {
    static let margin: CGFloat = 56
    /// The text block's height (hero to stats), measured from the snapshots.
    private static let blockHeight: CGFloat = 500

    let size: CGFloat
    let offset: CGSize
    let columnLeading: CGFloat
    let columnWidth: CGFloat
    let stacked: Bool

    init(window: CGSize, ink: CGRect) {
        let shown = CGSize(width: ink.width * 0.95, height: ink.height * 0.84)
        let wideLeading = min(max(window.width * 0.44, window.width - 620), window.width * 0.52)
        let side = (wideLeading - Tokens.Space.l) / shown.width
        let room = window.height - Self.margin - Self.blockHeight - Tokens.Space.xl
        let stack = min(room / shown.height, window.width * 0.85 / shown.width)
        let tallest = window.height * 0.78 / shown.height
        let byHeight = window.height * 0.62 / shown.height
        let size = max(160, min(max(side, stack), tallest, max(byHeight, stack)))
        self.size = size
        stacked = stack > side
        let leading = stacked ? Self.margin : wideLeading
        offset = CGSize(width: -(ink.minX + ink.width * 0.05) * size,
                        height: window.height - (ink.minY + shown.height) * size)
        columnLeading = leading
        columnWidth = window.width - leading - Self.margin
    }
}

/// Tena alone on the flood, never framed. While she is still an egg she is the button that hatches her.
private struct HomeTena: View {
    let summary: TodaySummary
    let mood: TenaMood
    let layout: HomeLayout
    let hatch: () -> Void

    var body: some View {
        Group {
            if summary.stage == .egg {
                Button(action: hatch) { tena }
                    .buttonStyle(.plain)
                    .help("Hatch Tena")
                    .accessibilityLabel("Hatch Tena")
            } else {
                tena
            }
        }
        .offset(layout.offset)
    }

    private var tena: some View {
        TenaView(mood: mood, stage: summary.stage, size: layout.size)
    }
}

/// The hero number, what it counts, and the ink pill.
private struct HomeLead: View {
    let summary: TodaySummary
    var heroSize: CGFloat = 160
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(hero)
                .font(Typography.display(heroSize))
                .foregroundStyle(Tokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .padding(.bottom, -14)
            Text(caption)
                .font(Typography.title)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            // Nothing left to start once the day is done: the hero says so, and no dead pill sits under it.
            if summary.primary.isActionable {
                Button(action: action) {
                    HStack(spacing: Tokens.Space.s) {
                        Text(pillTitle)
                            .lineLimit(1)
                        KeyCap("Return")
                    }
                }
                .buttonStyle(.fat)
                .fixedSize()
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel(summary.primary.title)
                .padding(.top, 40)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var hero: String {
        switch summary.primary {
        case let .placement(minutes, _): "\(minutes)"
        case let .review(count): "\(count)"
        case let .comeBack(count, _): "\(count)"
        case .allDone: "Done"
        }
    }

    private var caption: String {
        switch summary.primary {
        case let .placement(_, inProgress):
            inProgress ? "minute test, and your answers are saved" : "minutes to find your level"
        case let .review(count):
            count == 1 ? "word is waiting for you" : "words are waiting for you"
        case let .comeBack(count, at):
            "\(count == 1 ? "word comes" : "words come") back at \(at.formatted(date: .omitted, time: .shortened))"
        case .allDone:
            summary.line
        }
    }

    private var pillTitle: String {
        switch summary.primary {
        case let .placement(_, inProgress): inProgress ? "Continue the test" : "Start the test"
        case .review: "Review"
        case .comeBack: "Review early"
        case .allDone: summary.primary.shortTitle
        }
    }
}
