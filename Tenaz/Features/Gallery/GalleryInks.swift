import SwiftUI
import TenazCore

/// Every colour token of one sheet with its contrast on the page.
struct GalleryInks: View {
    let palette: Palette

    private static let roles: [(String, KeyPath<Palette, HexColor>)] = [
        ("paper", \.background), ("card", \.card), ("ink", \.text), ("brand", \.brand),
        ("accent", \.accent), ("accentText", \.accentText), ("correct", \.correct), ("wrong", \.wrong),
        ("gold", \.gold), ("tenaPink", \.tenaPink), ("tenaShade", \.tenaShade), ("tenaOutline", \.tenaOutline),
    ]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.s), count: 6), alignment: .leading, spacing: Tokens.Space.m) {
            ForEach(Self.roles, id: \.0) { name, role in
                SwatchTile(name: name, role: role, palette: palette)
            }
        }
    }
}
