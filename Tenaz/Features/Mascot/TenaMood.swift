/// Tena's 12 moods (PLAN F8). Raw values match the mood names in the plan so the gamification
/// model can map onto this rendering enum with `TenaMood(rawValue:)`.
enum TenaMood: String, CaseIterable, Identifiable, Sendable {
    case ecstatic, happy, focused, curious, neutral, hungry, nagging, sad, sick, regenerating, proud, asleep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sick: "Sick / injured"
        default: rawValue.capitalized
        }
    }
}
