import Foundation

/// A raw focus event (`app_active`, `window_focus`, `tab_active`). Catches a flash too short to become a span.
public struct FocusEvent: Hashable, Sendable {
    public var ts: Int64
    public var bundleId: String?
    public var domain: String?
    public var url: String?

    public init(ts: Int64, bundleId: String? = nil, domain: String? = nil, url: String? = nil) {
        self.ts = ts
        self.bundleId = bundleId
        self.domain = domain
        self.url = url
    }
}
