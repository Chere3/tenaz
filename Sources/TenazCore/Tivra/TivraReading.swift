import Foundation

/// Everything the reader learned about one window.
public struct TivraReading: Hashable, Sendable {
    public var health: TivraHealth
    public var foreground: ForegroundEvidence
    public var devices: [DeviceUsageSpan]

    public init(health: TivraHealth, foreground: ForegroundEvidence = .init(), devices: [DeviceUsageSpan] = []) {
        self.health = health
        self.foreground = foreground
        self.devices = devices
    }
}
