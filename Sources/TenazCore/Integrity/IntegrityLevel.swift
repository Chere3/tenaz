import Foundation

/// Precedence when combining evidence: UNVERIFIABLE > VIOLATION > WARNING > CLEAN (PLAN F5).
public enum IntegrityLevel: String, Codable, Sendable {
    case clean = "CLEAN"
    case warning = "WARNING"
    case violation = "VIOLATION"
    case unverifiable = "UNVERIFIABLE"
}
