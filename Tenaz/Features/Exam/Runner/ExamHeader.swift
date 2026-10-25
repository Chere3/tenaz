import SwiftUI
import TenazCore

/// Thin segments along the top (one per section, the current one filling as tasks pass), the
/// section name, and the time drawn as an ink band.
struct ExamHeader: View {
    let runner: ExamRunner

    /// The position is hidden when the question panel already says "Question x of y".
    private var showPosition: Bool {
        guard runner.phase == .task, runner.session.sectionLength > 1, let task = runner.task,
              let kind = runner.kind else { return false }
        if kind == .reading || kind == .listening { return runner.questionCount(task) <= 1 }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            ExamSegments(runner: runner)
            HStack(alignment: .center, spacing: Tokens.Space.l) {
                HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.m) {
                    Text(runner.section?.title ?? "Done")
                        .font(Typography.title)
                        .foregroundStyle(Tokens.ink)
                    if showPosition {
                        Text(runner.positionText)
                            .font(Typography.numeric(17))
                            .foregroundStyle(Tokens.brand)
                            .accessibilityLabel("Task \(runner.positionText)")
                    }
                }
                Spacer(minLength: Tokens.Space.l)
                ExamTimer(runner: runner)
                    .frame(width: 280)
            }
        }
    }
}

/// One 6 pt segment per section: ink at 15 % until done, ink at 100 % once finished; the current
/// one fills with the tasks done so far. The name sits under it; the current one is bold.
private struct ExamSegments: View {
    let runner: ExamRunner

    private func fraction(_ state: ChipState) -> Double {
        switch state {
        case .done: 1
        case .active:
            runner.phase == .task
                ? max(0.06, Double(runner.session.sectionPosition) / Double(max(runner.session.sectionLength, 1)))
                : 0.06
        case .idle, .locked: 0
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(runner.displaySections) { chip in
                VStack(alignment: .leading, spacing: 5) {
                    GeometryReader { geo in
                        Capsule().fill(Tokens.ink.opacity(0.15))
                            .overlay(alignment: .leading) {
                                Capsule().fill(Tokens.ink).frame(width: geo.size.width * fraction(chip.state))
                            }
                    }
                    .frame(height: 6)
                    HStack(spacing: 4) {
                        if chip.state == .done { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
                        Text(chip.title).lineLimit(1)
                    }
                    .font(.system(size: 12, weight: chip.state == .active ? .bold : .medium, design: .rounded))
                    .foregroundStyle(chip.state == .active ? Tokens.ink : Tokens.brand)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityValue(chip.state.rawValue)
            }
        }
    }
}
