import SwiftUI

/// Tier L: the page floods mint with "Unlocked"; or Tena's "we'll finish later" at the time limit.
struct GateStamp: View {
    let phase: GatePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        switch phase {
        case .unlocked:
            ZStack {
                NotchedPage().fill(Flood.good.color).ignoresSafeArea()
                OverlayRays(center: UnitPoint(x: 0.85, y: 0.95)).clipShape(NotchedPage()).ignoresSafeArea()
                VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                    Text("Unlocked")
                        .font(Typography.display(170))
                        .foregroundStyle(Tokens.ink)
                    Text("Claude will check your English in a moment.")
                        .font(Typography.title)
                        .foregroundStyle(Tokens.ink)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.leading, Tokens.Space.hero)
                TenaView(mood: .ecstatic, stage: .juvenile, size: 460)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .offset(y: 100)
                    .padding(.trailing, Tokens.Space.xxl)
            }
            .environment(\.colorScheme, .light)
            .transition(.opacity)
        case .later:
            HStack(spacing: Tokens.Space.l) {
                TenaView(mood: .neutral, stage: .juvenile, size: 150)
                Text("Time's up. We'll finish later.")
                    .font(Typography.displayM)
                    .foregroundStyle(Tokens.ink)
            }
            .padding(Tokens.Space.xl)
            .background { RoundedRectangle(cornerRadius: Tokens.Radius.sheet, style: .continuous).fill(Tokens.paper) }
            .environment(\.colorScheme, .light)
        default:
            EmptyView()
        }
    }
}
