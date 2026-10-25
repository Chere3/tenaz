/// An sRGB colour written as a 24-bit hex value, e.g. `HexColor(0xF6EBD3)`.
public struct HexColor: Hashable, Sendable, CustomStringConvertible {
    public let value: UInt32

    public init(_ value: UInt32) {
        self.value = value & 0xFFFFFF
    }

    /// Channels in 0...1.
    public var red: Double { Double((value >> 16) & 0xFF) / 255 }
    public var green: Double { Double((value >> 8) & 0xFF) / 255 }
    public var blue: Double { Double(value & 0xFF) / 255 }

    public var description: String {
        let hex = String(value, radix: 16, uppercase: true)
        return "#" + String(repeating: "0", count: 6 - hex.count) + hex
    }
}
