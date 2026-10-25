import Foundation

public enum IntegrityFindingKind: String, Codable, Sendable {
    /// Deny-listed Mac app / site / Android package seen by Tivra.
    case bundle, domain, package
    /// Deny-listed target focused too briefly to become a span.
    case flash
    /// Any app used on the phone during the exam.
    case phoneActive = "phone_active"
    /// Tenaz saw a deny-listed app come to the front.
    case tenazApp = "tenaz_app"
    /// Paste, clipboard and typing-burst flags counted by Tenaz.
    case tenazFlags = "tenaz_flags"
}
