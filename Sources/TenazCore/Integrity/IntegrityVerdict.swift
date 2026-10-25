import Foundation

/// The verdict JSON of research 06 section 4.2, extended with the reasons and a timeline.
public struct IntegrityVerdict: Codable, Hashable, Sendable {
    public var examId: String
    public var window: TivraWindow
    public var verifiedTs: Int64
    public var tivraAvailable: Bool
    public var captureGapMaxSec: Int?
    public var verdict: IntegrityLevel
    /// Why the verdict is UNVERIFIABLE (empty otherwise).
    public var problems: [String]
    public var violations: [IntegrityFinding]
    public var warnings: [IntegrityFinding]
    public var timeline: [IntegrityTimelineEntry]
}
