import Foundation

/// Is Tivra a reliable witness for a window? (06 section 4.2, step 1.) Any problem means UNVERIFIABLE.
public struct TivraHealth: Codable, Hashable, Sendable {
    public var captureTickCount: Int
    /// Largest silence between capture ticks inside `[start - 60 s, end + 60 s]`.
    public var maxGapSeconds: Int
    public var sourceStates: [String: String]
    public var pausedOrExcludedSeconds: Int
    public var problems: [String]

    public var isHealthy: Bool { problems.isEmpty }

    public static let maxAllowedGapMs: Int64 = 150_000
    public static let edgeToleranceMs: Int64 = 90_000
    public static let requiredSources = ["window_titles", "browser_url.dia"]

    public static func evaluate(
        tickTimestamps: [Int64], sourceStates: [String: String], pausedOrExcludedMs: Int64, window: TivraWindow
    ) -> TivraHealth {
        let lo = window.startTs - 60_000
        let hi = window.endTs + 60_000
        let inside = tickTimestamps.filter { $0 >= lo && $0 <= hi }.sorted()
        let points = [lo] + inside + [hi]
        let maxGap = zip(points, points.dropFirst()).map { $1 - $0 }.max() ?? 0

        var problems: [String] = []
        if maxGap > maxAllowedGapMs { problems.append("capture_gap") }
        if !tickTimestamps.contains(where: { abs($0 - window.startTs) <= edgeToleranceMs }) { problems.append("no_tick_at_start") }
        if !tickTimestamps.contains(where: { abs($0 - window.endTs) <= edgeToleranceMs }) { problems.append("no_tick_at_end") }
        for source in requiredSources where sourceStates[source] != "ok" {
            problems.append("source_\(source)_\(sourceStates[source] ?? "missing")")
        }
        if pausedOrExcludedMs > 0 { problems.append("paused_or_excluded") }

        return TivraHealth(
            captureTickCount: inside.count, maxGapSeconds: Int(maxGap / 1000), sourceStates: sourceStates,
            pausedOrExcludedSeconds: Int(pausedOrExcludedMs / 1000), problems: problems)
    }
}
