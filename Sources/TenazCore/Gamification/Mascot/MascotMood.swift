/// Tena's 12 moods (PLAN F8, research 02 §4.3). The renderer draws one pose per case.
public enum MascotMood: String, Codable, CaseIterable, Sendable {
    case ecstatic, happy, focused, curious, neutral, hungry, nagging, sad, sick, regenerating, proud, asleep
}
