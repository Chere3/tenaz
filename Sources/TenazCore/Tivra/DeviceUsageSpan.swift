import Foundation

/// Foreground app use on a paired non-Mac device (the Pixel), from `device_usage` events.
public struct DeviceUsageSpan: Hashable, Sendable {
    public var startTs: Int64
    public var endTs: Int64
    public var packageName: String?

    public init(startTs: Int64, endTs: Int64, packageName: String?) {
        self.startTs = startTs
        self.endTs = endTs
        self.packageName = packageName
    }
}
