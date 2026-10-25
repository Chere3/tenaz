import AppKit
import SwiftUI
import TenazCore

/// App-side design tokens ("Full Bleed"). Colours are dynamic: Paper in light appearance, Night in dark,
/// both read from `TenazCore.Palette` so the WCAG tests cover what the app draws.
enum Tokens {
    // MARK: Colour roles (see Palette for the meaning of each)
    static let paper = color(\.background)
    static let card = color(\.card)
    static let ink = color(\.text)
    static let brand = color(\.brand)
    static let accent = color(\.accent)
    static let accentText = color(\.accentText)
    static let onAccent = color(\.onAccent)
    static let inverse = color(\.inverseText)
    static let correct = color(\.correct)
    static let wrong = color(\.wrong)
    static let gold = color(\.gold)
    static let onGold = color(\.onGold)
    static let tenaPink = color(\.tenaPink)
    static let tenaShade = color(\.tenaShade)
    static let tenaOutline = color(\.tenaOutline)
    static let tenaGill = color(\.tenaGill)

    // Floods: one per screen, the colour is the state. Use `.flood(_:)`, not these directly.
    static let floodTurn = color(\.floodTurn)
    static let floodGood = color(\.floodGood)
    static let floodFix = color(\.floodFix)
    static let floodSerious = color(\.floodSerious)
    static let floodRisk = color(\.floodRisk)
    static let floodCelebrate = color(\.floodCelebrate)

    /// A colour that follows the effective appearance (NSAppearance in AppKit, colorScheme in SwiftUI).
    static func nsColor(_ role: KeyPath<Palette, HexColor>) -> NSColor {
        let light = NSColor(hex: Palette.paper[keyPath: role])
        let dark = NSColor(hex: Palette.nightPress[keyPath: role])
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }

    static func color(_ role: KeyPath<Palette, HexColor>) -> Color {
        Color(nsColor: nsColor(role))
    }

    // MARK: Spacing (4-pt grid)
    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let hero: CGFloat = 72
    }

    // MARK: Shape. No outlines and no shadows: separation comes from colour fields and space.
    enum Radius {
        static let control: CGFloat = 14
        /// The answer sheet, the one rounded surface on a flood.
        static let sheet: CGFloat = 24
        static let card: CGFloat = 20
        static let pill: CGFloat = 999
    }

    /// Hairline rule between list rows (ink at 12 %).
    static let rule: CGFloat = 1
    /// Edge drawn only under Increase Contrast.
    static let strokeIncreased: CGFloat = 2
    /// The primary pill's height.
    static let pillHeight: CGFloat = 62

    // Legacy "Riso Arcade" tokens, kept at zero while screens move to Full Bleed.
    static let stroke: CGFloat = 0
    static let shadowDepth: CGFloat = 0
    static let misregistration = CGSize.zero
}
