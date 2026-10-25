/// The integrity verdict (PLAN F5), most severe first: UNVERIFIABLE > VIOLATION > WARNING > CLEAN.
public enum ExamIntegrity: String, Codable, CaseIterable, Sendable {
    case clean, warning, violation, unverifiable

    public var isVerified: Bool { self == .clean || self == .warning }
}
