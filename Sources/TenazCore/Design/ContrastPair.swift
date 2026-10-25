/// A foreground/background pair the design system promises, with the WCAG bar it must clear.
public struct ContrastPair: Sendable, CustomStringConvertible {
    public enum Use: Sendable {
        /// Body-size text: needs 4.5:1.
        case text
        /// Text >= 20 pt Bold or >= 24 pt, icons, fills and outlines: needs 3:1.
        case largeOrGraphic

        public var minimum: Double {
            switch self {
            case .text: Contrast.normalText
            case .largeOrGraphic: Contrast.largeText
            }
        }
    }

    public let name: String
    public let foreground: HexColor
    public let background: HexColor
    public let use: Use
    /// The ratio written in docs/research/11-design-system.md §3.3, so a token edit cannot drift silently.
    public let documented: Double?

    public init(_ name: String, _ foreground: HexColor, on background: HexColor, use: Use, documented: Double? = nil) {
        self.name = name
        self.foreground = foreground
        self.background = background
        self.use = use
        self.documented = documented
    }

    public var ratio: Double { Contrast.ratio(foreground, background) }

    public var description: String { "\(name) \(foreground) on \(background)" }
}
