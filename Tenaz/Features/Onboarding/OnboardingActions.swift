/// What the onboarding buttons do. The live root fills them in; snapshots leave them empty.
struct OnboardingActions {
    var next: () -> Void = {}
    var back: () -> Void = {}
    var close: () -> Void = {}
    var hatch: () -> Void = {}
}
