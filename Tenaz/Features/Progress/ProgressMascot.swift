import TenazCore

/// Engine values as the mascot drawing enums (kept in a namespace so other areas can add their own
/// mappings without clashing).
enum ProgressMascot {
    static func mood(_ mood: MascotMood) -> TenaMood { TenaMood(rawValue: mood.rawValue) ?? .neutral }
    static func stage(_ stage: Int) -> TenaStage { TenaStage(rawValue: stage) ?? .juvenile }
}
