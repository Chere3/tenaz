import Foundation

/// WCAG 2.2 contrast math (relative luminance of sRGB, ratio (L1 + 0.05) / (L2 + 0.05)).
public enum Contrast {
    /// AA for normal text.
    public static let normalText = 4.5
    /// AA for large text (>= 24 px, or >= 18.66 px bold) and for UI components and graphics.
    public static let largeText = 3.0

    public static func relativeLuminance(_ color: HexColor) -> Double {
        func linear(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)
    }

    public static func ratio(_ a: HexColor, _ b: HexColor) -> Double {
        let la = relativeLuminance(a)
        let lb = relativeLuminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
