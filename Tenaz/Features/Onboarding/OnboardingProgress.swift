import SwiftUI

/// "Step 2 of 4" as four thin segments: ink at 100 % up to the current step, 15 % after.
struct OnboardingProgress: View {
    let page: OnboardingPage

    var body: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingPage.allCases) { step in
                Capsule()
                    .fill(Tokens.ink.opacity(step.rawValue <= page.rawValue ? 1 : 0.15))
                    .frame(width: 44, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(page.rawValue + 1) of \(OnboardingPage.allCases.count)")
    }
}
