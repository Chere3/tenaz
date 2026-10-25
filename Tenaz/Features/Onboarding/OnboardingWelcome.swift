import SwiftUI

/// Step 1: Tena's egg, huge and cropped by the window edge; the primary button ("Hatch Tena") cracks it
/// open into a hatchling. The words sit on the right; Tena is drawn behind the whole window by `OnboardingFlow`.
struct OnboardingWelcome: View {
    let hatched: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            Text(hatched ? "Hi! I'm Tena." : "Hello there.")
                .font(Typography.displayL)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Tenaz helps you remember English words and speak with confidence at work.")
                .font(Typography.title)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("I grow when your English grows. Not when you just open the app.")
                .font(Typography.body)
                .foregroundStyle(Tokens.brand)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 390, alignment: .leading)
    }
}

/// The big Tena behind the welcome page: shakes when she hatches.
struct OnboardingTena: View {
    let hatched: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Her right side stops here (the words column starts at 338 pt, minus 3 % of the 760 pt window).
    static let rightEdge: CGFloat = 315

    private var mood: TenaMood { hatched ? .ecstatic : .happy }
    private var stage: TenaStage { hatched ? .hatchling : .egg }
    /// 4.5 % of the 600 pt window: the clearance below her hands and beside her head.
    static let margin: CGFloat = 0.045 * 600

    /// The big-headed hatchling is wider than the egg, so she is drawn smaller to keep the same right edge,
    /// and smaller still if the left window edge would come within `margin` of her head (only gills may
    /// be cut there).
    private var size: CGFloat {
        guard hatched else { return 470 }
        let rest = TenaRig(mood: mood, stage: stage, time: 0, size: 360).rest
        guard let head = rest.skull else { return 360 }
        return min(360, (Self.rightEdge - Self.margin) / (rest.ink.maxX - head.minX))
    }

    /// Drawn in the window's bottom-leading corner: her right side on `rightEdge`, and the window's bottom
    /// edge cropping her at `TenaInk.bottomCut` (the egg through its lower body, the hatchling below her
    /// hands, never through her mouth).
    var body: some View {
        let size = size
        let ink = TenaInk.bounds(stage: stage, mood: mood, size: size)
        let cut = TenaInk.bottomCut(stage: stage, mood: mood, size: size, margin: Self.margin)
        TenaView(mood: mood, stage: stage, size: size)
            .offset(x: Self.rightEdge - ink.maxX * size, y: (1 - cut) * size)
            .keyframeAnimator(initialValue: 0.0, trigger: hatched) { content, angle in
                content.rotationEffect(.degrees(angle), anchor: .bottom)
            } keyframes: { _ in
                KeyframeTrack {
                    for a in reduceMotion ? [0.0] : [-6, 6, -4, 4, 0] {
                        LinearKeyframe(a, duration: 0.07)
                    }
                }
            }
            .scaleEffect(hatched && !reduceMotion ? 1.0 : 0.97, anchor: .bottom)
            .animation(Motion.animation(.pop, reduceMotion: reduceMotion), value: hatched)
    }
}
