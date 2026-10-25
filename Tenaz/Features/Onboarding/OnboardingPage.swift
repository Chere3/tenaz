/// The four onboarding steps, in order.
enum OnboardingPage: Int, CaseIterable, Identifiable {
    case welcome, intrusions, minimum, plan

    var id: Int { rawValue }

    var primaryTitle: String {
        switch self {
        case .welcome: "Next"
        case .intrusions: "Got it"
        case .minimum: "Sounds good"
        case .plan: "Go to my placement test"
        }
    }
}
