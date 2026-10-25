/// Everything one grading call needs.
public struct GradeRequest: Codable, Hashable, Sendable {
    public var kind: GradeKind
    public var taskPrompt: String
    public var response: String
    /// The learner's current band for this skill, so Claude knows the level it is reading.
    public var learnerBand: Double
    /// Speaking answered by typing (no microphone).
    public var typed: Bool

    public init(kind: GradeKind, taskPrompt: String, response: String, learnerBand: Double, typed: Bool = false) {
        self.kind = kind
        self.taskPrompt = taskPrompt
        self.response = response
        self.learnerBand = learnerBand
        self.typed = typed
    }

    public var metrics: TextMetrics { TextMetrics(text: response) }
}
