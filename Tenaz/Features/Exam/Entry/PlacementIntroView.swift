import SwiftUI
import TenazCore

/// The placement test's front page on the serious (indigo) flood: the title, what it measures, the
/// sections drawn as one bar with widths ∝ minutes, the promise, the one ink pill, and Tivra plus the
/// microphone as one quiet line. Tena sits bottom-right in her headband, cropped by the window.
struct PlacementIntroView: View {
    let state: PlacementEntryState
    let witness: ExamWitness
    var paused = false
    var problem: String?
    var calendarBlocked = false
    var actions = PlacementIntroActions()
    @State private var pledged: Bool

    init(state: PlacementEntryState, witness: ExamWitness, paused: Bool = false, problem: String? = nil,
         calendarBlocked: Bool = false, actions: PlacementIntroActions = PlacementIntroActions(), pledged: Bool = false) {
        self.state = state
        self.witness = witness
        self.paused = paused
        self.problem = problem
        self.calendarBlocked = calendarBlocked
        self.actions = actions
        _pledged = State(initialValue: pledged)
    }

    private var isContinuing: Bool { paused || state.unfinished != nil }

    /// A paused attempt continues in memory; an unfinished one is rebuilt from the database.
    private var primaryAction: () -> Void {
        if paused { return actions.resumePaused }
        return state.unfinished == nil ? actions.start : actions.resume
    }

    /// The text column; Tena only takes the space to its right.
    private static let column: CGFloat = 600
    private static let gutter: CGFloat = Tokens.Space.hero

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                tena(in: proxy.size)
                VStack(alignment: .leading, spacing: 0) {
                    SnapshotSafeScroll {
                        // Centred in the room above the quiet line, so no empty band is left.
                        VStack(spacing: 0) {
                            Spacer(minLength: Tokens.Space.l)
                            content
                                .frame(maxWidth: Self.column, alignment: .leading)
                                .padding(.horizontal, Self.gutter)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Spacer(minLength: Tokens.Space.l)
                        }
                        .frame(minHeight: max(0, proxy.size.height - 110))
                    }
                    quietLine
                        .frame(maxWidth: Self.column, alignment: .leading)
                        .padding(.horizontal, Self.gutter)
                        .padding(.bottom, Tokens.Space.xl)
                }
            }
        }
        .clipped()
        .flood(.serious)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Placement test")
                .font(Typography.displayL)
                .foregroundStyle(Tokens.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Reading, listening, writing, speaking and grammar. You get a TOEFL-style band, your CEFR level, and what to practice next.")
                .font(Typography.body)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Tokens.Space.s)
            if let banner = bannerText {
                PlacementBanner(text: banner.text, button: banner.button, action: banner.action)
                    .padding(.top, Tokens.Space.m)
            }
            PlacementSectionList(sections: state.sections, totalMinutes: state.totalMinutes)
                .padding(.top, Tokens.Space.xl)
            if let problem {
                ExamProblemRow(problem: problem, startAnyway: calendarBlocked ? actions.startAnyway : nil)
                    .padding(.top, Tokens.Space.m)
            }
            // The promise is the pill: pressing it ticks the pledge and starts.
            Button(action: pledgeAndStart) {
                HStack(spacing: Tokens.Space.s) {
                    Text(isContinuing ? "Continue the test" : "I won't use AI. Start")
                    KeyCap("Return")
                }
            }
            .buttonStyle(.fat)
            .keyboardShortcut(.defaultAction)
            .accessibilityLabel(isContinuing ? "Continue the test" : "Promise: I will not use AI, translators or notes")
            .fixedSize(horizontal: true, vertical: false)
            .padding(.top, Tokens.Space.xl)
            PledgeCard()
                .padding(.top, Tokens.Space.s)
        }
    }

    private func pledgeAndStart() {
        pledged = true
        primaryAction()
    }

    /// Tivra and the microphone, quiet, at the bottom edge of the window.
    /// One line when it fits; Tivra above the microphone when Tivra has more to say.
    private var quietLine: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text("Hold Esc 3 s to leave · a meeting pauses it")
                .font(Typography.label)
                .foregroundStyle(Tokens.ink.opacity(0.72))
            if !isContinuing {
                Button(action: actions.startInWindow) {
                    Text("Exam Mode not working? Take it in this window").font(Typography.label)
                }
                    .buttonStyle(InkTextButtonStyle(tint: Tokens.ink.opacity(0.72)))
                    .help("Same test in the normal window. Other apps aren't hidden, so the result is a level estimate, not a verified exam.")
                    .padding(.leading, -Tokens.Space.s)
            }
            witnessLine
        }
    }

    private var witnessLine: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
                WitnessCard(witness: witness)
                Text("·").font(Typography.label).foregroundStyle(Tokens.ink.opacity(0.5))
                MicrophoneSetupRow()
            }
            VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                WitnessCard(witness: witness)
                MicrophoneSetupRow()
            }
        }
    }

    /// Tena focused in her headband, about three quarters of the window tall, cropped by the bottom and
    /// right edges (`BleedTena`: the cut clears her hands, her gills clear the text column). She only takes
    /// the room right of the text column, and hides when there is none.
    @ViewBuilder
    private func tena(in size: CGSize) -> some View {
        let room = size.width - Self.column - Self.gutter - Tokens.Space.l
        if min(size.height * 0.74, room * 1.5) >= 260 {
            BleedTena(mood: .focused, stage: .juvenile, corner: .bottomTrailing, textEdge: Self.gutter + Self.column)
                .accessibilityHidden(true)
        }
    }

    private var bannerText: (text: String, button: String, action: () -> Void)? {
        if paused {
            return ("Your test is paused. Answers are saved.", "Resume", actions.resumePaused)
        }
        if let unfinished = state.unfinished {
            return ("You stopped at \(unfinished.where). Your answers are saved.", "Continue", actions.resume)
        }
        if let last = state.last, let band = last.overall {
            return ("You took it on \(last.startedAt.formatted(date: .abbreviated, time: .omitted)): \(BandWords.label(band)) (\(BandWords.format(band))).",
                    "See result", actions.showLast)
        }
        return nil
    }
}
