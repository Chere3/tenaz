import AppKit

/// The gate's multi-line writing field. Same rules as `AnswerTextView` (every system writing aid
/// off via `AnswerTextView.disableSystemAI`), and paste, drops and Services are always closed:
/// the gate paragraph must be typed by the learner. Return asks to unlock instead of inserting a line.
final class ParagraphTextView: NSTextView {
    var onSubmit: () -> Void = {}
    var placeholder = ""

    static let font: NSFont = {
        let base = NSFont.systemFont(ofSize: 24, weight: .regular)
        guard let rounded = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: rounded, size: 24) ?? base
    }()

    func configure() {
        AnswerTextView.disableSystemAI(self)
        font = Self.font
        typingAttributes[.font] = Self.font
        isRichText = false
        importsGraphics = false
        allowsUndo = true
        drawsBackground = false
        textContainerInset = NSSize(width: 0, height: 6)
        textContainer?.lineFragmentPadding = 0
        unregisterDraggedTypes()
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 9
        defaultParagraphStyle = style
        typingAttributes[.paragraphStyle] = style
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func insertNewline(_ sender: Any?) { onSubmit() }
    override func insertLineBreak(_ sender: Any?) { onSubmit() }
    override func insertNewlineIgnoringFieldEditor(_ sender: Any?) { onSubmit() }

    // Paste-proof: every route that brings outside text in is closed.
    override func paste(_ sender: Any?) {}
    override func pasteAsPlainText(_ sender: Any?) {}
    override func pasteAsRichText(_ sender: Any?) {}
    override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool { false }
    override func validRequestor(forSendType sendType: NSPasteboard.PasteboardType?, returnType: NSPasteboard.PasteboardType?) -> Any? { nil }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: "Cut", action: #selector(cut(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Copy", action: #selector(copy(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Select All", action: #selector(selectAll(_:)), keyEquivalent: "")
        return menu
    }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        var caret = rect
        caret.size.width = AnswerTextView.caretWidth
        super.drawInsertionPoint(in: caret, color: insertionPointColor, turnedOn: flag)
    }

    override func setNeedsDisplay(_ rect: NSRect, avoidAdditionalLayout flag: Bool) {
        var wider = rect
        wider.size.width += AnswerTextView.caretWidth
        super.setNeedsDisplay(wider, avoidAdditionalLayout: flag)
    }

    /// AppKit only redraws the glyphs that changed, so the placeholder would stay under the first
    /// letters typed. Redraw the whole view whenever the text changes.
    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholder.isEmpty else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Self.font,
            .foregroundColor: Tokens.nsColor(\.brand).withAlphaComponent(0.45),
        ]
        NSAttributedString(string: placeholder, attributes: attributes).draw(at: NSPoint(x: textContainerInset.width + (textContainer?.lineFragmentPadding ?? 0), y: textContainerInset.height))
    }
}
