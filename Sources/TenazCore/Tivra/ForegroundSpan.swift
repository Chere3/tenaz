import Foundation

/// A resolved foreground interval from Tivra. Transient: titles are never read, and url/domain are
/// matched against the deny list and dropped, never stored by Tenaz.
public struct ForegroundSpan: Hashable, Sendable {
    public var startTs: Int64
    public var endTs: Int64
    public var bundleId: String?
    public var domain: String?
    public var url: String?

    public init(startTs: Int64, endTs: Int64, bundleId: String? = nil, domain: String? = nil, url: String? = nil) {
        self.startTs = startTs
        self.endTs = endTs
        self.bundleId = bundleId
        self.domain = domain
        self.url = url
    }
}
