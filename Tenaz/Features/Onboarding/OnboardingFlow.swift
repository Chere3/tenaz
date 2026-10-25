import SwiftUI

/// The onboarding sheet for one step: progress, the step, then Back (Esc) and the one primary action
/// (Return). Pure, so each step can be snapshotted. Welcome and the plan are your turn (yellow);
/// the two explanation steps are paper.
struct OnboardingFlow: View {
    let page: OnboardingPage
    let hatched: Bool
    @Binding var plan: OnboardingPlan
    /// A save that failed, shown above the buttons.
    var problem: String?
    var actions = OnboardingActions()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var primaryTitle: String { page == .welcome && !hatched ? "Hatch Tena" : page.primaryTitle }

    private var floodColor: Flood? {
        switch page {
        case .welcome, .plan: .turn
        case .intrusions, .minimum: nil
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: Tokens.Space.l) {
                HStack {
                    OnboardingProgress(page: page)
                    Spacer()
                    // "Not now" closes the welcome step, so it needs no second exit; later steps keep the ✕.
                    if page != .welcome {
                        Button("Close", systemImage: "xmark", action: actions.close)
                            .labelStyle(.iconOnly)
                            .buttonStyle(.ink)
                            .help("Close. You can finish this later.")
                    }
                }
                Group {
                    switch page {
                    case .welcome: OnboardingWelcome(hatched: hatched)
                    case .intrusions: OnboardingIntrusions()
                    case .minimum: OnboardingMinimum()
                    case .plan: OnboardingPlanStep(plan: $plan, onSubmit: actions.next)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: page == .welcome ? .trailing : .topLeading)
                .id(page)
                .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                if let problem {
                    Label(problem, systemImage: "exclamationmark.triangle.fill")
                        .font(Typography.label)
                        .foregroundStyle(Tokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: Tokens.Space.m) {
                    if page == .welcome {
                        Spacer()
                        Button(action: actions.close) {
                            HStack(spacing: 6) {
                                Text("Not now")
                                KeyCap("esc")
                            }
                        }
                        .buttonStyle(.ink)
                        .keyboardShortcut(.cancelAction)
                    } else {
                        Button(action: actions.back) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                                KeyCap("esc")
                            }
                        }
                        .buttonStyle(.ink)
                        .keyboardShortcut(.cancelAction)
                        Spacer()
                    }
                    Button(action: page == .welcome && !hatched ? actions.hatch : actions.next) {
                        HStack(spacing: Tokens.Space.s) {
                            Text(primaryTitle)
                            KeyCap("Return")
                        }
                    }
                    .buttonStyle(.fat)
                    .keyboardShortcut(.defaultAction)
                    .frame(width: page == .plan ? 380 : 280)
                }
            }
            .padding(Tokens.Space.xl)
        }
        .background(alignment: .bottomLeading) {
            if page == .welcome {
                OnboardingTena(hatched: hatched)
                    .transition(.opacity)
            }
        }
        .frame(width: 760, height: 600)
        .clipped()
        .flood(floodColor)
    }
}
