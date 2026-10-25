import AppKit

/// Multi-line, paste-proof text view for writing practice: the same system-AI switches as
/// `AnswerTextView` (Writing Tools, predictions, autocorrect, spelling, grammar, substitutions,
/// Services) and no paste or drops, because the sentence must be the learner's own.
final class WritingTextView: NSTextView {
    var onCancel: () -> Void = {}
    var placeholder = ""

    static func make(font: NSFont) -> (NSScrollView, WritingTextView) {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let old = scroll.documentView as? NSTextView
        let view = WritingTextView(frame: old?.frame ?? .zero, textContainer: old?.textContainer)
        view.autoresizingMask = [.width]
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.textContainer?.widthTracksTextView = true
        view.font = font
        view.typingAttributes[.font] = font
        AnswerTextView.disableSystemAI(view)
        view.isRichText = false
        view.importsGraphics = false
        view.allowsUndo = true
        view.drawsBackground = false
        view.textContainerInset = NSSize(width: 0, height: 4)
        view.unregisterDraggedTypes()
        scroll.documentView = view
        return (scroll, view)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func cancelOperation(_: Any?) {
        onCancel()
    }

    // MARK: No paste, drops or Services.

    override func paste(_: Any?) {}
    override func pasteAsPlainText(_: Any?) {}
    override func pasteAsRichText(_: Any?) {}
    override func readSelection(from _: NSPasteboard, type _: NSPasteboard.PasteboardType) -> Bool {
        false
    }

    override func validRequestor(forSendType _: NSPasteboard.PasteboardType?, returnType _: NSPasteboard.PasteboardType?) -> Any? {
        nil
    }

    override func menu(for _: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: "Cut", action: #selector(cut(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Copy", action: #selector(copy(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Select All", action: #selector(selectAll(_:)), keyEquivalent: "")
        return menu
    }

    /// AppKit only redraws the glyphs that changed, so the placeholder would stay under the first
    /// letters typed. Redraw the whole view whenever the text changes.
    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholder.isEmpty, let font else { return }
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: Tokens.nsColor(\.brand).withAlphaComponent(0.45)]
        NSAttributedString(string: placeholder, attributes: attributes).draw(at: NSPoint(x: textContainerInset.width + (textContainer?.lineFragmentPadding ?? 0), y: textContainerInset.height))
    }
}
