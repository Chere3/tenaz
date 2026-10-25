import AppKit
import TenazCore

extension NSColor {
    convenience init(hex: HexColor) {
        self.init(srgbRed: hex.red, green: hex.green, blue: hex.blue, alpha: 1)
    }
}
