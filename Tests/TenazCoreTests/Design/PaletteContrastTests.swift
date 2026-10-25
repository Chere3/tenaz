import Testing
@testable import TenazCore

struct PaletteContrastTests {
    @Test(arguments: Palette.all.flatMap(\.declaredPairs))
    func everyDeclaredPairMeetsItsRatio(_ pair: ContrastPair) {
        #expect(pair.ratio >= pair.use.minimum, "\(pair) is \(pair.ratio)")
    }

    @Test(arguments: Palette.all.flatMap(\.declaredPairs).filter { $0.documented != nil })
    func ratiosMatchTheDesignDoc(_ pair: ContrastPair) throws {
        let documented = try #require(pair.documented)
        #expect(abs(pair.ratio - documented) < 0.01, "\(pair) is \(pair.ratio), doc says \(documented)")
    }

    @Test func accentFillKeepsItsMargin() {
        // The accent fill clears 3:1 on Paper by a small margin; never let it slip lower.
        #expect(Contrast.ratio(Palette.paper.accent, Palette.paper.background) >= 3.1)
    }

    @Test func contrastMathEndpoints() {
        #expect(abs(Contrast.ratio(HexColor(0x000000), HexColor(0xFFFFFF)) - 21) < 0.001)
        #expect(Contrast.ratio(HexColor(0x777777), HexColor(0x777777)) == 1)
        #expect(HexColor(0x0A0B0C).description == "#0A0B0C")
    }

    @Test func bothSheetsDeclareTheSamePairs() {
        #expect(Palette.paper.declaredPairs.map(\.name) == Palette.nightPress.declaredPairs.map(\.name))
    }
}
