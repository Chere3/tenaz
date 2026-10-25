import SwiftUI
import TenazCore

/// Every attempt, newest first: when, which exam, the band, and the integrity verdict.
struct ExamHistoryList: View {
    let history: [ExamAttemptSummary]
    let open: (ExamAttemptSummary) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            Text("History")
                .font(Typography.label)
                .foregroundStyle(Tokens.brand)
            if history.isEmpty {
                Text("No exams yet. Your results will collect here, so you can see the line go up.")
                    .font(Typography.body)
                    .foregroundStyle(Tokens.brand)
                    .padding(.vertical, Tokens.Space.s)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(history.enumerated()), id: \.element.id) { i, attempt in
                        ExamHistoryRow(attempt: attempt) { open(attempt) }
                        if i < history.count - 1 {
                            Rectangle().fill(Tokens.ink.opacity(0.12)).frame(height: 1)
                                .padding(.horizontal, Tokens.Space.m)
                        }
                    }
                }
                .padding(.vertical, Tokens.Space.xxs)
                .background(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous).fill(Tokens.card))
            }
        }
    }
}

private struct ExamHistoryRow: View {
    let attempt: ExamAttemptSummary
    let open: () -> Void

    private var statusText: (String, String)? {
        switch attempt.status {
        case "void": ("Left", "xmark")
        case "abandoned": ("Not finished", "minus")
        case "running": ("In progress", "ellipsis")
        default: nil
        }
    }

    var body: some View {
        Button(action: open) {
            HStack(spacing: Tokens.Space.m) {
                Image(systemName: ExamCardInfo(attempt.kind).symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Tokens.brand)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(ExamCardInfo(attempt.kind).title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.ink)
                    Text(attempt.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(Typography.caption)
                        .foregroundStyle(Tokens.brand)
                }
                .frame(width: 170, alignment: .leading)
                if let band = attempt.overall {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(BandWords.format(band))
                            .font(Typography.display(24))
                            .foregroundStyle(Tokens.ink)
                        Text(BandWords.label(band))
                            .font(Typography.labelBold)
                            .foregroundStyle(Tokens.brand)
                    }
                    .frame(width: 140, alignment: .leading)
                    SkillMiniBars(bands: attempt.skillBands)
                } else {
                    Text(attempt.status == "done" ? "Grading…" : "No band")
                        .font(Typography.label)
                        .foregroundStyle(Tokens.brand)
                        .frame(width: 140, alignment: .leading)
                }
                Spacer()
                if let (text, symbol) = statusText {
                    Label(text, systemImage: symbol)
                        .font(Typography.labelBold)
                        .foregroundStyle(Tokens.brand)
                } else {
                    IntegrityChip(level: attempt.integrity, confirmed: attempt.integrityConfirmed)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Tokens.brand)
                    .opacity(attempt.status == "done" ? 1 : 0)
            }
            .padding(.horizontal, Tokens.Space.m)
            .padding(.vertical, Tokens.Space.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(attempt.status != "done")
        .accessibilityElement(children: .combine)
    }
}

/// Four tiny bars (R, L, W, S) so a row shows the shape of the result at a glance.
private struct SkillMiniBars: View {
    let bands: [ExamSkill: Double]

    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(ExamSkill.sections, id: \.self) { skill in
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(bands[skill] == nil ? Tokens.ink.opacity(0.15) : Tokens.ink.opacity(0.8))
                        .frame(width: 10, height: bands[skill].map { max(4, $0 / 6 * 28) } ?? 3)
                    Text(String(skill.label.prefix(1)))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.brand)
                }
            }
        }
        .frame(height: 42, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

/// Small integrity marker for history rows: a glyph and a word; colour only where it means something.
private struct IntegrityChip: View {
    let level: IntegrityLevel?
    let confirmed: Bool

    var body: some View {
        let (text, symbol, tint): (String, String, Color) = switch level {
        case nil: ("Not checked", "hourglass", Tokens.brand)
        case .clean?: ("Verified", "checkmark.seal.fill", Tokens.correct)
        case .warning?: (confirmed ? "Confirmed" : "Warning", confirmed ? "checkmark" : "exclamationmark.triangle.fill",
                         confirmed ? Tokens.correct : Tokens.accentText)
        case .violation?: ("Flagged", "xmark.octagon.fill", Tokens.wrong)
        case .unverifiable?: ("Unverified", "eye.slash", Tokens.brand)
        }
        Label(text, systemImage: symbol)
            .font(Typography.labelBold)
            .foregroundStyle(tint)
    }
}
