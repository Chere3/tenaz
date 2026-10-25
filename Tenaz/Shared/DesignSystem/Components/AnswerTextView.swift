import AppKit

/// The single-line text view behind every answer field (review, overlay, gate, exam).
/// Retrieval must be the learner's own, so every system helper that writes English for them is off
/// (PLAN-critique #5): Writing Tools, inline predictions, autocorrect, spelling and grammar,
/// completion, replacements, smart quotes and dashes, and the Services menu. With `allowsPaste`
/// false, paste and drops do nothing and leave the context menu.
final class AnswerTextView: NSTextView {
    var allowsPaste = true {
        didSet {
            guard allowsPaste != oldValue else { return }
            allowsPaste ? registerForDraggedTypes(acceptableDragTypes) : unregisterDraggedTypes()
        }
    }
    /// Take keyboard focus as soon as the view lands in a window (R4: start cost near zero).
    var focusOnAppear = true
    var placeholder = ""
    var onSubmit: () -> Void = {}
    /// Esc. nil keeps NSTextView's default (completion), so existing fields behave as before.
    var onCancel: (() -> Void)?
    /// Caret width in points (the design system's thick orange caret).
    static let caretWidth: CGFloat = 3

    convenience init(font: NSFont) {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.maximumNumberOfLines = 1
        container.lineBreakMode = .byClipping
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)
        self.init(frame: .zero, textContainer: container)
        self.font = font
        typingAttributes[.font] = font
        Self.disableSystemAI(self)
        isRichText = false
        importsGraphics = false
        allowsUndo = true
        drawsBackground = false
        isHorizontallyResizable = false
        isVerticallyResizable = false
        textContainerInset = .zero
    }

    /// Turns off every system feature that could suggest or rewrite text. Public so a custom field
    /// elsewhere can reuse the same list; `SelfTest "answerfield"` asserts it.
    static func disableSystemAI(_ view: NSTextView) {
        view.writingToolsBehavior = .none
        view.inlinePredictionType = .no
        view.isAutomaticSpellingCorrectionEnabled = false
        view.isContinuousSpellCheckingEnabled = false
        view.isGrammarCheckingEnabled = false
        view.isAutomaticTextCompletionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticLinkDetectionEnabled = false
        view.isAutomaticDataDetectionEnabled = false
        view.smartInsertDeleteEnabled = false
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if focusOnAppear { window?.makeFirstResponder(self) }
    }

    // MARK: Single line: Return submits, never inserts.

    override func insertNewline(_ sender: Any?) {
        onSubmit()
    }

    override func insertLineBreak(_ sender: Any?) {
        onSubmit()
    }

    override func insertNewlineIgnoringFieldEditor(_ sender: Any?) {
        onSubmit()
    }

    override func cancelOperation(_ sender: Any?) {
        if let onCancel { onCancel() } else { super.cancelOperation(sender) }
    }

    // MARK: No Services, no paste when disallowed, a minimal context menu.

    override func validRequestor(forSendType sendType: NSPasteboard.PasteboardType?, returnType: NSPasteboard.PasteboardType?) -> Any? {
        nil
    }

    override func paste(_ sender: Any?) {
        pasteAsPlainText(sender)
    }

    override func pasteAsRichText(_ sender: Any?) {
        paste(sender)
    }

    /// "Paste and Match Style" and Cmd+Opt+Shift+V reach here without going through `paste(_:)`.
    override func pasteAsPlainText(_ sender: Any?) {
        if allowsPaste { super.pasteAsPlainText(sender) }
    }

    /// The common path for paste, drops and Services; closed when paste is not allowed.
    override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        allowsPaste && super.readSelection(from: pboard, type: type)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        editingMenu()
    }

    /// Cut, Copy, (Paste), Select All: no Writing Tools, Spelling, Substitutions or Services.
    func editingMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Cut", action: #selector(cut(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Copy", action: #selector(copy(_:)), keyEquivalent: "")
        if allowsPaste { menu.addItem(withTitle: "Paste", action: #selector(paste(_:)), keyEquivalent: "") }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Select All", action: #selector(selectAll(_:)), keyEquivalent: "")
        return menu
    }

    // MARK: Look: thick caret, placeholder.

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        var caret = rect
        caret.size.width = Self.caretWidth
        super.drawInsertionPoint(in: caret, color: insertionPointColor, turnedOn: flag)
    }

    override func setNeedsDisplay(_ rect: NSRect, avoidAdditionalLayout flag: Bool) {
        var wider = rect
        wider.size.width += Self.caretWidth
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
        guard string.isEmpty, !placeholder.isEmpty, let font else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: Tokens.nsColor(\.brand).withAlphaComponent(0.45),
        ]
        NSAttributedString(string: placeholder, attributes: attributes).draw(at: NSPoint(x: textContainerInset.width + (textContainer?.lineFragmentPadding ?? 0), y: 0))
    }
}
