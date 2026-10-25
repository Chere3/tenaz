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

    var body: some View {
        TenaView(mood: hatched ? .ecstatic : .happy, stage: hatched ? .hatchling : .egg, size: 640)
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
