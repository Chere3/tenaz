import Foundation

/// Reader output: a reading, or the reason Tivra cannot witness (missing file, unreadable, schema drift).
public enum TivraEvidence: Hashable, Sendable {
    case available(TivraReading)
    case unavailable(reason: String)
}
