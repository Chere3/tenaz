import SwiftUI
import TenazCore

/// One clear next step after the result, with the XP note and any honest caveats, then the one
/// ink pill and "All exams" as text.
struct NextStepCard: View {
    let model: ExamResultModel
    let onNext: () -> Void
    let onHistory: () -> Void

    private var plan: String {
        switch model.kind {
        case .placement: "Start your first words now. Tomorrow, an 8-minute Daily Check keeps your level fresh."
        case .daily: "Good. Your daily estimate moved a little. Now clear today's reviews."
        case .weekly, .monthly: "Your weak spots go into your review deck. Do your reviews, then rest."
        }
    }

    private var caveats: [String] {
        var lines: [String] = []
        if model.readInstead > 0 {
            lines.append(model.readInstead == 1 ? "1 listening item was read, not heard (audio didn't play)."
                                                : "\(model.readInstead) listening items were read, not heard (audio didn't play).")
        }
        if model.typedSpeaking > 0 { lines.append("Speaking was typed, so it is graded as typed English, not pronunciation.") }
        if let xp = model.xpGained, xp > 0 { lines.append("+\(xp) XP for Tena.") }
        if model.stageAdvanced { lines.append("Tena grew! Look at the menu bar.") }
        if let problem = model.loadProblem { lines.append(problem) }
        return lines
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            Rectangle().fill(Tokens.ink.opacity(0.18)).frame(height: 1.5)
                .padding(.bottom, Tokens.Space.m)
            Text(plan)
                .font(Typography.title)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 640, alignment: .leading)
            ForEach(caveats, id: \.self) { line in
                Text(line)
                    .font(Typography.label)
                    .foregroundStyle(ResultInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: Tokens.Space.l) {
                Button(action: onNext) {
                    HStack(spacing: Tokens.Space.s) {
                        Text(model.kind == .placement ? "Start reviewing" : "Go to reviews")
                        KeyCap("Return")
                    }
                }
                .buttonStyle(.fat)
                .keyboardShortcut(.defaultAction)
                .fixedSize(horizontal: true, vertical: false)
                Button("All exams", action: onHistory)
                    .buttonStyle(InkTextButtonStyle(tint: Tokens.ink))
            }
            .padding(.top, Tokens.Space.s)
        }
    }
}
