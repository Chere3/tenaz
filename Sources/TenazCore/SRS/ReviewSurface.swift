import Foundation

/// Where a review happened (`review_log.surface`).
public enum ReviewSurface: String, Codable, Sendable {
    case overlay, gate, session, exam, notification
}
