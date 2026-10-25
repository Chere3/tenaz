import SwiftUI
import TenazCore

struct ExamsOverviewActions {
    var daily: () -> Void = {}
    var weekly: () -> Void = {}
    var monthly: () -> Void = {}
    var placement: () -> Void = {}
    var resume: (String) -> Void = { _ in }
    var resumePaused: () -> Void = {}
    var resumeNotInCall: () -> Void = {}
    var startAnyway: () -> Void = {}
    var open: (ExamAttemptSummary) -> Void = { _ in }
}

/// The Exams screen: anything to continue, the four exams with when they open, and the history.
struct ExamsOverview: View {
    let state: ExamsOverviewState
    var paused = false
    var pausedForMeeting = false
    /// The paused attempt, so its "unfinished" row isn't shown a second time.
    var pausedId: String?
    var problem: String?
    var calendarBlocked = false
    var actions = ExamsOverviewActions()

    private var primary: ExamKind { state.placementDone == nil ? .placement : .daily }

    private var placementNote: String? {
        if let done = state.placementDone { return "Done \(done.formatted(date: .abbreviated, time: .omitted))" }
        return state.unfinished.contains { $0.kind == .placement } || paused ? "In progress: opens where you stopped" : nil
    }

    var body: some View {
        SnapshotSafeScroll {
            VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                card(primary)
                    .frame(maxWidth: 640, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .topTrailing) {
                        // Cropped by the window's right edge, never framed.
                        FloorlessTena(mood: .happy, size: 380)
                            .offset(x: Tokens.Space.hero + 190, y: -150)
                            .accessibilityHidden(true)
                    }
                if paused || !state.unfinished.filter({ $0.id != pausedId }).isEmpty || problem != nil {
                    VStack(alignment: .leading, spacing: Tokens.Space.s) {
                        if paused {
                            PausedExamCard(forMeeting: pausedForMeeting, resume: actions.resumePaused, notInCall: actions.resumeNotInCall)
                        }
                        ForEach(state.unfinished.filter { $0.id != pausedId }) { u in
                            PlacementBanner(text: "\(ExamCardInfo(u.kind).title) started \(u.started.formatted(date: .abbreviated, time: .shortened)), \(u.answered) answers saved.",
                                            button: "Continue", action: { actions.resume(u.id) })
                        }
                        if let problem {
                            ExamProblemRow(problem: problem, startAnyway: calendarBlocked ? actions.startAnyway : nil)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: Tokens.Space.m) {
                    Rectangle().fill(Tokens.ink.opacity(0.12)).frame(height: 1)
                    HStack(alignment: .top, spacing: Tokens.Space.xl) {
                        ForEach(ExamKind.overviewOrder.filter { $0 != primary }, id: \.self) { kind in
                            card(kind)
                        }
                    }
                    MicrophoneSetupRow()
                }
                ExamHistoryList(history: state.history, open: actions.open)
            }
            .padding(.horizontal, Tokens.Space.hero)
            .padding(.vertical, Tokens.Space.xxl)
            .frame(maxWidth: 1180, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .clipped()
        .paperBackground()
    }

    private func card(_ kind: ExamKind) -> ExamCard {
        switch kind {
        case .placement:
            ExamCard(info: ExamCardInfo(.placement), isPrimary: primary == .placement,
                     availability: .open, note: placementNote, action: actions.placement)
        case .daily:
            ExamCard(info: ExamCardInfo(.daily), isPrimary: primary == .daily,
                     availability: state.placementDone == nil ? .locked("after your placement") : .open,
                     note: state.dailyDoneToday ? "Done today" : nil, action: actions.daily)
        case .weekly:
            ExamCard(info: ExamCardInfo(.weekly), isPrimary: false, availability: state.weekly, note: nil, action: actions.weekly)
        case .monthly:
            ExamCard(info: ExamCardInfo(.monthly), isPrimary: false, availability: state.monthly, note: nil, action: actions.monthly)
        }
    }
}

private extension ExamKind {
    /// The order the Exams screen lists them in.
    static let overviewOrder: [ExamKind] = [.placement, .daily, .weekly, .monthly]
}

/// An exam paused by a meeting (or the watchdog): continue, or say the mic isn't a call.
private struct PausedExamCard: View {
    let forMeeting: Bool
    let resume: () -> Void
    let notInCall: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Space.m) {
            Image(systemName: forMeeting ? "phone.fill" : "pause.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Tokens.ink)
            VStack(alignment: .leading, spacing: 2) {
                Text(forMeeting ? "Exam paused for a meeting" : "Exam paused")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.ink)
                Text("The timer stopped and nothing was flagged. Continue when you are free.")
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
            }
            Spacer()
            if forMeeting {
                Button("Not in a meeting? Continue", action: notInCall)
                    .help("Ignores the microphone and the calendar for this attempt. The camera still pauses it.")
                    .buttonStyle(.ink)
            }
            Button("Continue", systemImage: "play.fill", action: resume)
                .buttonStyle(.ink)
        }
    }
}
