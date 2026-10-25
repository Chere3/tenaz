import Foundation

/// A Tivra focus block (row of `sessions`) that has ended; the trigger for a word overlay (PLAN F1, M11).
public struct FocusBlockEnd: Hashable, Sendable {
    public var id: String
    public var endTs: Int64
    public var finalState: String?
}
