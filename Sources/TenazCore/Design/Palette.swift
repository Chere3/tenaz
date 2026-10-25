/// The two "Full Bleed" sheets: Paper (light) and Night (dark). Screens are one flood of colour whose
/// colour is the state (your turn, good, fix, serious, risk, celebrate); text sits on it in ink.
/// Single source of colour truth; the app turns these into dynamic colours. Hex values and roles
/// come from docs/design/full-bleed.md. Colour means state, and only state.
public struct Palette: Sendable {
    public let name: String
    /// Page background.
    public let background: HexColor
    /// Cards on the page, separators, idle chips, disabled buttons.
    public let card: HexColor
    /// Primary text and the fill of the one primary pill.
    public let text: HexColor
    /// Brand ink: secondary text, links, text buttons, active chips.
    public let brand: HexColor
    /// Energy accent (meters, highlights). Fill or large text only on Paper.
    public let accent: HexColor
    /// The accent when it has to be small text or an icon.
    public let accentText: HexColor
    /// Text on an accent fill: 20 pt Bold minimum on Paper (4.38:1 counts only as large text).
    public let onAccent: HexColor
    /// Text on brand, correct and wrong fills (chips, stamps).
    public let inverseText: HexColor
    public let correct: HexColor
    public let wrong: HexColor
    /// XP, coins, achievements (fill).
    public let gold: HexColor
    /// Text on a gold fill.
    public let onGold: HexColor
    /// Tena's body ink. Reserved for the mascot: never text, never UI state.
    public let tenaPink: HexColor
    /// The one flat shade shape on Tena's body.
    public let tenaShade: HexColor
    /// Tena's outline, eyes and mouth (ink, same on both sheets).
    public let tenaOutline: HexColor
    /// Tena's gill fronds.
    public let tenaGill: HexColor
    /// Tena's belly patch and fin frill (lighter than the body).
    public let tenaBelly: HexColor
    /// Tena's crown dots and freckles.
    public let tenaMark: HexColor
    /// Gill roots and filaments; also the gill fill on the coral and orange floods.
    public let tenaGillDeep: HexColor
    /// The Elder's gill tips and fin edge. Never the body.
    public let tenaAmber: HexColor
    /// Floods: the whole window is one of these, and it means a state. Light floods carry Paper ink;
    /// serious and risk carry Night ink (the app flips the colour scheme inside a flood).
    public let floodTurn: HexColor
    public let floodGood: HexColor
    public let floodFix: HexColor
    public let floodSerious: HexColor
    public let floodRisk: HexColor
    public let floodCelebrate: HexColor

    public static let paper = Palette(
        name: "Paper",
        background: HexColor(0xFFF7EE),
        card: HexColor(0xF4E8DA),
        text: HexColor(0x1A1410),
        brand: HexColor(0x45311F),
        accent: HexColor(0xEE5A24),
        accentText: HexColor(0xB03F14),
        onAccent: HexColor(0x1A1410),
        inverseText: HexColor(0xFFF7EE),
        correct: HexColor(0x1B7A47),
        wrong: HexColor(0xB42318),
        gold: HexColor(0xFFD43B),
        onGold: HexColor(0x1A1410),
        tenaPink: HexColor(0xF7A6C1),
        tenaShade: HexColor(0xE886A8),
        tenaOutline: HexColor(0x311228),
        tenaGill: HexColor(0xC8352A),
        tenaBelly: HexColor(0xFCD3DF),
        tenaMark: HexColor(0xE06C98),
        tenaGillDeep: HexColor(0xA82634),
        tenaAmber: HexColor(0xF4A72A),
        floodTurn: HexColor(0xFFD43B),
        floodGood: HexColor(0x5FD38D),
        floodFix: HexColor(0xFF8A7A),
        floodSerious: HexColor(0x23246B),
        floodRisk: HexColor(0x5A1E18),
        floodCelebrate: HexColor(0xFF6B35)
    )

    public static let nightPress = Palette(
        name: "Night",
        background: HexColor(0x17120E),
        card: HexColor(0x241C16),
        text: HexColor(0xFFF4E6),
        brand: HexColor(0xB8A898),
        accent: HexColor(0xF2672F),
        accentText: HexColor(0xFF8A5C),
        onAccent: HexColor(0x17120E),
        inverseText: HexColor(0x17120E),
        correct: HexColor(0x4CC47F),
        wrong: HexColor(0xF07A6A),
        gold: HexColor(0xF2C230),
        onGold: HexColor(0x17120E),
        tenaPink: HexColor(0xF7A6C1),
        tenaShade: HexColor(0xE886A8),
        tenaOutline: HexColor(0x311228),
        tenaGill: HexColor(0xF0583A),
        tenaBelly: HexColor(0xFCD3DF),
        tenaMark: HexColor(0xE06C98),
        tenaGillDeep: HexColor(0xC8352A),
        tenaAmber: HexColor(0xF4A72A),
        floodTurn: HexColor(0xF2C230),
        floodGood: HexColor(0x4CC47F),
        floodFix: HexColor(0xF4806F),
        floodSerious: HexColor(0x2A2C7A),
        floodRisk: HexColor(0x5A1E18),
        floodCelebrate: HexColor(0xF2672F)
    )

    public static let all = [paper, nightPress]

    /// Every pair the UI relies on, with the bar it must clear. `PaletteContrastTests` checks them all,
    /// so a token edit cannot silently break legibility. Light floods are read with Paper ink and dark
    /// floods with Night ink in both appearances, because the app flips the scheme inside a flood.
    public var declaredPairs: [ContrastPair] {
        let lightInk = Palette.paper
        let darkInk = Palette.nightPress
        return [
            ContrastPair("text on background", text, on: background, use: .text),
            ContrastPair("text on card", text, on: card, use: .text),
            ContrastPair("brand on background", brand, on: background, use: .text),
            ContrastPair("brand on card", brand, on: card, use: .text),
            ContrastPair("accent fill on background", accent, on: background, use: .largeOrGraphic),
            ContrastPair("accentText on background", accentText, on: background, use: .text),
            ContrastPair("accentText on card", accentText, on: card, use: .text),
            ContrastPair("onAccent on accent", onAccent, on: accent, use: .text),
            ContrastPair("correct on background", correct, on: background, use: .text),
            ContrastPair("wrong on background", wrong, on: background, use: .text),
            ContrastPair("inverseText on text (the ink pill)", inverseText, on: text, use: .text),
            ContrastPair("inverseText on correct", inverseText, on: correct, use: .text),
            ContrastPair("inverseText on wrong", inverseText, on: wrong, use: .text),
            ContrastPair("onGold on gold", onGold, on: gold, use: .text),
            ContrastPair("tena outline on tena body", tenaOutline, on: tenaPink, use: .largeOrGraphic),
            // On light floods the ink contour carries her silhouette (pink alone is 1.0-1.8:1 there).
            ContrastPair("tena outline on paper", tenaOutline, on: lightInk.background, use: .largeOrGraphic),
            ContrastPair("tena outline on turn flood", tenaOutline, on: floodTurn, use: .largeOrGraphic),
            ContrastPair("tena outline on good flood", tenaOutline, on: floodGood, use: .largeOrGraphic),
            ContrastPair("tena outline on fix flood", tenaOutline, on: floodFix, use: .largeOrGraphic),
            ContrastPair("tena outline on celebrate flood", tenaOutline, on: floodCelebrate, use: .largeOrGraphic),
            // On dark floods the pink fill carries it, with no keyline.
            ContrastPair("tena body on serious flood", tenaPink, on: floodSerious, use: .largeOrGraphic),
            ContrastPair("tena body on risk flood", tenaPink, on: floodRisk, use: .largeOrGraphic),
            ContrastPair("ink on turn flood", lightInk.text, on: floodTurn, use: .text),
            ContrastPair("secondary on turn flood", lightInk.brand, on: floodTurn, use: .text),
            ContrastPair("ink on good flood", lightInk.text, on: floodGood, use: .text),
            ContrastPair("secondary on good flood", lightInk.brand, on: floodGood, use: .text),
            ContrastPair("ink on fix flood", lightInk.text, on: floodFix, use: .text),
            ContrastPair("secondary on fix flood", lightInk.brand, on: floodFix, use: .text),
            ContrastPair("ink on celebrate flood", lightInk.text, on: floodCelebrate, use: .text),
            ContrastPair("secondary on celebrate flood", lightInk.brand, on: floodCelebrate, use: .largeOrGraphic),
            ContrastPair("ink on serious flood", darkInk.text, on: floodSerious, use: .text),
            ContrastPair("secondary on serious flood", darkInk.brand, on: floodSerious, use: .text),
            ContrastPair("ink on risk flood", darkInk.text, on: floodRisk, use: .text),
            ContrastPair("secondary on risk flood", darkInk.brand, on: floodRisk, use: .text),
        ]
    }
}
