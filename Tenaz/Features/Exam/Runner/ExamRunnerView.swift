import SwiftUI
import TenazCore

/// One exam screen: header (section, chips, time), the task or section intro, and the footer
/// with the integrity line and the single primary action. Used in Exam Mode and in the window.
struct ExamRunnerView: View {
    @Bindable var runner: ExamRunner
    /// 0...1 while Esc is held (Exam Mode); drawn as a filling ring.
    var escHold: Double = 0
    /// Window mode only: leave the Daily Check (the attempt is void).
    var onLeave: () -> Void = {}
    /// Exam Mode: the top-right notification band stays see-through (and click-through), so an
    /// incoming call or Teams banner is never hidden (PLAN F1/F2, critique #1).
    var notched = false

    /// Window mode: the flood runs under the title bar, so the header clears it.
    private static let titleBar: CGFloat = 28

    private var bandInset: CGFloat { notched ? OverlayLayoutBand.width : 0 }

    var body: some View {
        VStack(spacing: 0) {
            ExamHeader(runner: runner)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Tokens.Space.xl)
                .padding(.trailing, bandInset)
                .padding(.top, Tokens.Space.xl + (runner.examMode ? 0 : Self.titleBar))
                .padding(.bottom, Tokens.Space.xl)
            // The stage scrolls instead of pushing the header and footer off the window.
            GeometryReader { proxy in
                SnapshotSafeScroll {
                    ExamStage(runner: runner)
                        .padding(.horizontal, Tokens.Space.xl)
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
                }
            }
            .layoutPriority(-1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Rectangle().fill(Tokens.ink.opacity(0.12)).frame(height: 1)
            ExamFooter(runner: runner, escHold: escHold, onLeave: onLeave)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Tokens.Space.xl)
                .padding(.vertical, Tokens.Space.m)
        }
        .modifier(ExamFlood(flood: runner.examMode ? .serious : .turn, notched: notched))
    }
}

/// The exam's flood: indigo (serious) in Exam Mode, yellow for the daily check in the window.
/// In Exam Mode the notched page replaces the full-window fill so the notification band stays see-through.
private struct ExamFlood: ViewModifier {
    let flood: Flood
    let notched: Bool

    func body(content: Content) -> some View {
        if notched {
            content
                .environment(\.colorScheme, flood.inkScheme)
                .background {
                    ZStack {
                        flood.color
                        PaperGrain(density: 0.6)
                    }
                    .environment(\.colorScheme, flood.inkScheme)
                    .ignoresSafeArea()
                    .clipShape(NotchedPage())
                }
        } else {
            content.flood(flood)
        }
    }
}
