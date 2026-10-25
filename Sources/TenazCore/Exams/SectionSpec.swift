/// One timed section of a blueprint. Two-stage routing (TOEFL 2026 Reading/Listening): a
/// `router` section, then exactly one of the `lower`/`upper` sections with the same `group`.
public struct SectionSpec: Codable, Hashable, Sendable, Identifiable {
    public enum Stage: String, Codable, Sendable {
        case linear, router, lower, upper
    }

    /// What the UI does when audio or a microphone is missing.
    public enum Fallback: String, Codable, Sendable {
        /// Listening: show the line/script as text instead of playing it.
        case transcript
        /// Speaking: type the answer instead of recording it.
        case typed
    }

    public var id: String
    public var title: String
    /// Evidence target; nil means each item's own skill.
    public var skill: ExamSkill?
    public var minutes: Double
    public var stage: Stage?
    public var group: String?
    public var optional: Bool?
    public var fallback: Fallback?
    public var picks: [ItemPick]
    public var adaptive: AdaptiveRule?
    /// Router only: proportion correct needed for the upper module (default 0.6).
    public var routeUpperAt: Double?

    public var resolvedStage: Stage { stage ?? .linear }
    public var isOptional: Bool { optional ?? false }
    public var timeLimit: Duration { .milliseconds(Int64(minutes * 60_000)) }
}
