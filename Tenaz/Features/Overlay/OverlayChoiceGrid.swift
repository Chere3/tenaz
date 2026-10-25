import SwiftUI
import TenazCore

/// Four Spanish meanings as numbered paper chips; keys 1-4 pick (recognition cards).
struct OverlayChoiceGrid: View {
    let options: [String]
    var picked: Int?
    var correct: Int?
    var compact = false
    let choose: (Int) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Tokens.Space.xs), GridItem(.flexible(), spacing: Tokens.Space.xs)],
                  spacing: Tokens.Space.xs) {
            ForEach(options.indices, id: \.self) { i in
                Button { choose(i) } label: {
                    HStack(spacing: Tokens.Space.s) {
                        KeyCap("\(i + 1)")
                        Text(options[i])
                            .font(.system(size: compact ? 13 : 22, weight: .semibold, design: .rounded))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let glyph = glyph(i) {
                            Image(systemName: glyph).font(.system(size: compact ? 14 : 22, weight: .bold))
                        }
                    }
                    .foregroundStyle(isCorrect(i) ? Tokens.paper : Tokens.ink)
                    .padding(.horizontal, compact ? Tokens.Space.xs : Tokens.Space.m)
                    .frame(minHeight: compact ? 30 : 64)
                    .background {
                        RoundedRectangle(cornerRadius: compact ? 15 : Tokens.Radius.control, style: .continuous)
                            .fill(isCorrect(i) ? Tokens.ink : Tokens.paper)
                    }
                    .opacity(picked != nil && !isCorrect(i) && i != picked ? 0.5 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Option \(i + 1): \(options[i])")
            }
        }
    }

    private func isCorrect(_ i: Int) -> Bool { picked != nil && i == correct }

    private func glyph(_ i: Int) -> String? {
        guard picked != nil else { return nil }
        if i == correct { return "checkmark.circle.fill" }
        if i == picked { return "xmark.circle.fill" }
        return nil
    }
}
