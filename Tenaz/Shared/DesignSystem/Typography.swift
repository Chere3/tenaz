import AppKit
import CoreText
import SwiftUI

/// Display = Fraunces at SOFT 100 / WONK 0 (bundled, OFL): a fat, soft 70s serif. UI = SF Pro Rounded.
/// Max two typefaces on a screen. What the learner types is always sans (their own voice).
enum Typography {
    /// PostScript name of a Fraunces instance; the variation dictionary sets the real axes.
    static let frauncesPostScriptName = "Fraunces-Regular"
    private(set) static var frauncesAvailable = false

    // OpenType variation axis tags as CoreText integers.
    private static let weightAxis = 0x7767_6874 // 'wght'
    private static let widthAxis = 0x7764_7468 // 'wdth'
    private static let opticalSizeAxis = 0x6F70_737A // 'opsz'
    private static let softAxis = 0x534F_4654 // 'SOFT'
    private static let wonkAxis = 0x574F_4E4B // 'WONK'

    /// Registers the bundled TTF for this process. Call before anything renders (snapshots included).
    static func registerFonts() {
        if let url = Bundle.main.url(forResource: "Fraunces", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        frauncesAvailable = NSFont(name: frauncesPostScriptName, size: 12) != nil
    }

    /// Fraunces at any weight (100-900), always SOFT 100 and WONK 0; the optical size follows the point
    /// size. `width` is ignored (kept so older call sites compile). Falls back to SF Rounded Heavy.
    static func display(_ size: CGFloat, weight: CGFloat = 900, width: CGFloat = 100) -> Font {
        guard frauncesAvailable else {
            return .system(size: size, weight: weight >= 750 ? .heavy : .bold, design: .rounded)
        }
        let variation: [Int: CGFloat] = [
            weightAxis: weight,
            opticalSizeAxis: min(144, max(9, size)),
            softAxis: 100,
            wonkAxis: 0,
        ]
        let descriptor = NSFontDescriptor(fontAttributes: [
            .name: frauncesPostScriptName,
            NSFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variation,
        ])
        guard let font = NSFont(descriptor: descriptor, size: size) else {
            return .system(size: size, weight: .heavy, design: .rounded)
        }
        return Font(font as CTFont)
    }

    // Type scale (pt), docs/design/full-bleed.md. One hero per screen at 3-4x anything else.
    static var wordHero: Font { display(200) }
    /// The giant count on Home ("14") and the minutes on placement ("52").
    static var numberHero: Font { display(160) }
    static var displayL: Font { display(64) }
    /// The review question.
    static var prompt: Font { display(50, weight: 800) }
    static var displayM: Font { display(36, weight: 800) }
    static var displayS: Font { display(26, weight: 800) }
    /// Primary pill label.
    static let button = Font.system(size: 22, weight: .bold, design: .rounded)
    static let title = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 18, weight: .regular, design: .rounded)
    static let answer = Font.system(size: 34, weight: .semibold, design: .rounded)
    /// Sentence case, never uppercase-tracked.
    static let label = Font.system(size: 14, weight: .medium, design: .rounded)
    static let labelBold = Font.system(size: 14, weight: .semibold, design: .rounded)
    static let caption = Font.system(size: 12, weight: .semibold, design: .rounded)
    static let textButton = Font.system(size: 16, weight: .semibold, design: .rounded)
    static func numeric(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
    }
}
