/// Adaptive section: pick the next task nearest the running estimate; stop at `max` tasks, or
/// once at least `min` are done and the posterior SD is below `stopSD`.
public struct AdaptiveRule: Codable, Hashable, Sendable {
    public var min: Int
    public var max: Int
    public var stopSD: Double

    public init(min: Int, max: Int, stopSD: Double) {
        self.min = min
        self.max = max
        self.stopSD = stopSD
    }
}
