import SwiftUI

/// The review screen for any phase. Pure, so each state can be snapshotted. The whole window is one
/// flood and the flood is the state: `.turn` while a card is open, `.good` on a right answer, the
/// checkpoint and the end, `.fix` on a wrong answer, paper while waiting or empty.
struct ReviewBoard: View {
    let state: ReviewViewState
    @Binding var typed: String
    var actions = ReviewActions()
    var now: Date = .now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var flood: Flood? {
        switch state.phase {
        case .loading, .question: .turn
        case let .feedback(_, feedback): feedback.correct ? .good : .fix
        case .checkpoint, .done: .good
        case .waiting, .empty: nil
        }
    }

    private var showsHeader: Bool {
        switch state.phase {
        case .question, .feedback, .waiting, .checkpoint: true
        default: false
        }
    }

    /// The answer sheet handles Esc itself while a typed card is open; pause screens have "Stop here".
    private var headerEscape: Bool {
        switch state.phase {
        case let .question(card): card.isChoice
        case .feedback: true
        default: false
        }
    }

    /// Tena on the hero screens, with the mood of the flood (rays only on events).
    private var tena: (mood: TenaMood, rays: Bool)? {
        switch state.phase {
        case let .feedback(_, feedback): feedback.correct ? (.ecstatic, true) : (.happy, false)
        case .checkpoint: (.proud, true)
        case .waiting: (.neutral, false)
        case .empty: (.happy, false)
        case let .done(summary): (summary.mood, summary.answered > 0)
        case .loading, .question: nil
        }
    }

    private var stage: TenaStage {
        if case let .done(summary) = state.phase { return summary.stage }
        return state.stage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsHeader {
                ReviewHeader(progress: state.progress, stop: actions.stop, stopsWithEscape: headerEscape,
                             showsStop: state.phase.card != nil, showsScore: state.phase.feedback != nil)
            }
            Group {
                if let card = state.phase.card {
                    Group {
                        if let feedback = state.phase.feedback {
                            ReviewFeedbackHero(card: card, feedback: feedback, stage: stage, next: actions.next)
                        } else {
                            ReviewQuestion(card: card, typed: $typed, actions: actions)
                        }
                    }
                    .id(card.id)
                } else {
                    switch state.phase {
                    case .loading:
                        ProgressView().controlSize(.large)
                            .frame(maxWidth: .infinity)
                    case let .empty(message):
                        ReviewPause(hero: "Nothing to review", line: message, primaryTitle: "Back to Today", primary: actions.home)
                    case .question, .feedback:
                        EmptyView()
                    case .checkpoint:
                        ReviewPause(hero: "\(state.progress.correctToday)", heroFont: Typography.numberHero,
                                    caption: "words right today",
                                    line: "Your daily words are done. Keep going, or stop here. Both are fine.",
                                    primaryTitle: "Keep going", primary: actions.next,
                                    secondaryTitle: "Stop here", secondary: actions.stop)
                    case let .waiting(until):
                        ReviewWaitingView(until: until, stop: actions.stop, write: actions.write, now: now)
                    case let .done(summary):
                        ReviewDoneView(summary: summary, actions: actions)
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .padding(.horizontal, 64)
        .padding(.top, Tokens.Space.l)
        .padding(.bottom, Tokens.Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if let tena {
                BleedTena(mood: tena.mood, stage: stage, rays: tena.rays)
                    .transition(.opacity)
            }
        }
        .clipped()
        .animation(Motion.animation(.settle, reduceMotion: reduceMotion), value: state.phase)
        .flood(flood)
    }
}
