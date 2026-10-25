import Foundation
import Testing
@testable import TenazCore

struct ContentTests {
    static let contentRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Content")

    @Test func parsesCompleteWordsGaps() {
        let segs = CompleteWordsParser.parse("New tech{{nology}} changes how we wo{{rk}}.")
        #expect(segs == [
            .text("New "), .gap(WordGap(visible: "tech", hidden: "nology")),
            .text(" changes how we "), .gap(WordGap(visible: "wo", hidden: "rk")), .text("."),
        ])
    }

    @Test func bundledContentDecodesAndIsValid() throws {
        let library = try ContentLibrary.load(from: Self.contentRoot)
        let (clean, report) = ContentValidator.cleaned(library)
        // Allow a small number of rejects (the app drops them), but the bank must be mostly clean.
        let total = library.vocab.count + library.items.count
        #expect(report.count * 20 <= max(total, 1), "too many invalid entries: \(report.prefix(20))")
        if total > 0 {
            #expect(clean.vocab.count >= 300)
            #expect(!clean.items(of: .completeWords).isEmpty)
            #expect(!clean.items(of: .lifeParagraph).isEmpty)
        }
    }
}
