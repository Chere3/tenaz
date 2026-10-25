import SwiftUI
import TenazCore

/// The anti-cheat verdict, honestly: a glyph and a word, what it means for the result, a short
/// timeline, and the caveat. A WARNING counts once the learner confirms it.
struct IntegrityCard: View {
    let model: ExamResultModel

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text("Integrity")
                .font(Typography.label)
                .foregroundStyle(ResultInk.secondary)
            Rectangle().fill(ResultInk.rule).frame(height: 1)
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
                IntegrityStamp(level: model.integrity, confirmed: model.integrityConfirmed)
                Text(summary)
                    .font(Typography.label)
                    .foregroundStyle(Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, Tokens.Space.xxs)
            if !model.timeline.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(model.timeline.prefix(5).enumerated()), id: \.offset) { _, entry in
                        TimelineRow(entry: entry, start: model.startedAt)
                    }
                }
            }
            if model.integrity == .warning, !model.integrityConfirmed {
                Button("That was me, not AI help. Count it.", systemImage: "hand.raised.fill", action: model.confirmWarning)
                    .buttonStyle(InkTextButtonStyle(tint: Tokens.ink))
                    .padding(.leading, -Tokens.Space.s)
            }
            Text("Tenaz can catch common AI shortcuts. It can't prove you didn't use another device.")
                .font(Typography.caption)
                .foregroundStyle(ResultInk.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var summary: String {
        switch model.integrity {
        case nil: "Checking Tivra's records for the exam time…"
        case .clean?: "Nothing suspicious. This result is verified."
        case .warning?: model.integrityConfirmed ? "You confirmed the short app switch. This result counts."
                                                 : "A short switch to another app. Confirm it to count this result."
        case .violation?: "Another app was in front too long. Your level is shown, but it won't count for promotion or XP."
        case .unverifiable?: "Tivra wasn't watching, so this can't be verified. Your level estimate still counts for practice."
        }
    }
}

/// Clean / Warning / Flagged / Unverified as a glyph and a word (never colour alone). Colour only
/// where it means something: green for clean, red for flagged.
private struct IntegrityStamp: View {
    let level: IntegrityLevel?
    let confirmed: Bool

    var body: some View {
        let (text, symbol, tint): (String, String, Color) = switch level {
        case nil: ("Checking", "hourglass", Tokens.ink)
        case .clean?: ("Clean", "checkmark.seal.fill", Tokens.correct)
        case .warning?: (confirmed ? "Confirmed" : "Warning", "exclamationmark.triangle.fill", confirmed ? Tokens.ink : Tokens.gold)
        case .violation?: ("Flagged", "xmark.octagon.fill", Tokens.wrong)
        case .unverifiable?: ("Unverified", "eye.slash.fill", Tokens.ink)
        }
        Label(text, systemImage: symbol)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .fixedSize()
    }
}

private struct TimelineRow: View {
    let entry: IntegrityTimelineEntry
    let start: Date

    var body: some View {
        let minute = max(0, Int((Double(entry.startTs) / 1000 - start.timeIntervalSince1970) / 60))
        HStack(spacing: Tokens.Space.xs) {
            Image(systemName: entry.severity == .violation ? "xmark.circle.fill" : entry.severity == .warning ? "exclamationmark.circle.fill" : "info.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(entry.severity == .violation ? Tokens.wrong : entry.severity == .warning ? Tokens.gold : ResultInk.secondary)
            Text("min \(minute)")
                .font(Typography.numeric(12))
                .foregroundStyle(ResultInk.secondary)
                .frame(width: 48, alignment: .leading)
            Text(entry.label)
                .font(Typography.label)
                .foregroundStyle(Tokens.ink)
            Spacer(minLength: 0)
            if entry.endTs > entry.startTs {
                Text("\(max(1, (entry.endTs - entry.startTs) / 1000)) s")
                    .font(Typography.numeric(12))
                    .foregroundStyle(ResultInk.secondary)
            }
        }
    }
}
