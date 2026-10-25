import Foundation

/// `{start, end, kind, label}` plus seconds: the only thing Tenaz keeps from Tivra's data.
public struct IntegrityFinding: Codable, Hashable, Sendable {
    public var startTs: Int64
    public var endTs: Int64
    public var kind: IntegrityFindingKind
    public var label: String
    public var seconds: Int
}
