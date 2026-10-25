import Foundation

public struct LearningMinutes: Codable, Hashable, Sendable {
    /// Minutes of `aprendizaje` foreground time spent in Tenaz itself.
    public var tenaz: Double
    /// All `aprendizaje` active time (Tenaz, Duolingo, lessons in the browser...).
    public var all: Double
}
