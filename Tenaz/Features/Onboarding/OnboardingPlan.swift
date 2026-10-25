/// The if-then plan from the last step: a cue the learner picks (or writes) and the fixed action.
struct OnboardingPlan: Equatable {
    static let cues = ["I open my laptop in the morning", "I finish lunch", "I get my coffee", "I leave my last meeting"]

    var cue: String? = OnboardingPlan.cues[0]
    var custom = ""

    /// The custom cue wins when typed.
    var chosenCue: String? {
        let typed = custom.trimmingCharacters(in: .whitespacesAndNewlines)
        return typed.isEmpty ? cue : typed
    }

    /// The fixed action half of onboarding's plan.
    static let action = "I do my Tenaz set"

    /// The cue as it reads inside the sentence (stored as the plan's cue).
    var planCue: String? { chosenCue.map(\.lowercasedFirst) }

    var sentence: String? { planCue.map { "If \($0), then \(Self.action)." } }
}

private extension String {
    var lowercasedFirst: String {
        guard let first else { return self }
        // Keep "I" as it is ("I finish lunch").
        if hasPrefix("I ") { return self }
        return first.lowercased() + dropFirst()
    }
}
