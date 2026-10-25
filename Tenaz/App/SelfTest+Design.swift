import AppKit
import SwiftUI

extension SelfTest {
    /// `--tenaz-selftest design`: the bundled display font registered, and the answer field has every
    /// system writing aid off (PLAN-critique #5). Exit 0 only if all hold.
    static func design() -> Int32 {
        let view = AnswerTextView(font: AnswerInput.font)
        view.allowsPaste = false
        let board = NSPasteboard(name: NSPasteboard.Name("com.chere3.tenaz.selftest"))
        board.clearContents()
        board.setString("pasted", forType: .string)
        let blocked = !view.readSelection(from: board, type: .string)
        view.pasteAsPlainText(nil)
        let untouched = view.string.isEmpty
        view.allowsPaste = true
        let allowed = view.readSelection(from: board, type: .string)
        view.allowsPaste = false
        board.releaseGlobally()
        // A narrow meter insets its cells into CGRect.null; the halftone used to loop forever on it.
        let nullDots = Halftone.dots(in: .null, spacing: 3.6) { _ in 1 }.isEmpty
        let narrowMeter = ImageRenderer(content: MeterCells(fraction: 1, fill: .green).frame(width: 30, height: 16)).nsImage != nil
        let checks: [(String, Bool)] = [
            ("displayFontRegistered", Typography.frauncesAvailable),
            ("writingToolsOff", view.writingToolsBehavior == .none),
            ("inlinePredictionOff", view.inlinePredictionType == .no),
            ("autocorrectOff", !view.isAutomaticSpellingCorrectionEnabled),
            ("spellCheckOff", !view.isContinuousSpellCheckingEnabled),
            ("grammarOff", !view.isGrammarCheckingEnabled),
            ("completionOff", !view.isAutomaticTextCompletionEnabled),
            ("replacementOff", !view.isAutomaticTextReplacementEnabled),
            ("smartQuotesOff", !view.isAutomaticQuoteSubstitutionEnabled),
            ("smartDashesOff", !view.isAutomaticDashSubstitutionEnabled),
            ("servicesOff", view.validRequestor(forSendType: .string, returnType: .string) == nil),
            ("pasteBlockedWhenDisallowed", blocked && untouched),
            ("pasteWorksWhenAllowed", allowed),
            ("halftoneNullRectEmpty", nullDots),
            ("narrowMeterRenders", narrowMeter),
            ("contextMenuMinimal", view.editingMenu().items.map(\.title) == ["Cut", "Copy", "", "Select All"]),
        ]
        for (name, ok) in checks { print("\(ok ? "ok  " : "FAIL") \(name)") }
        return checks.allSatisfy(\.1) ? 0 : 1
    }
}
