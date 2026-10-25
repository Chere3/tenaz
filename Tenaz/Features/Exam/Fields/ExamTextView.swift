import AppKit

/// The text view behind every exam answer: single line (gaps, Listen & Repeat) or multi-line
/// (writing, interview). The same system aids are off as in `AnswerTextView` (Writing Tools,
/// predictions, autocorrect, spelling, completion, substitutions, Services), paste and drops are
/// refused and reported, and every edit reports its size for the typing telemetry.
final class ExamTextView: NSTextView {
    var multiline = false
    var onSubmit: () -> Void = {}
    /// Command-Return in a multi-line field.
    var onCommandSubmit: () -> Void = {}
    var onTab: () -> Void = {}
    var onBacktab: () -> Void = {}
    var onEdit: (_ inserted: Int, _ deleted: Int, _ isIME: Bool) -> Void = { _, _, _ in }
    var onPasteBlocked: () -> Void = {}
    var onFocus: () -> Void = {}
    var placeholder = ""

    /// The first click into a field types there at once, even while the panel is not key yet
    /// (the hosting view's own override only covers clicks that land on SwiftUI content).
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Never shorter than the visible field: an empty page (or a gap) is clickable top to bottom,
    /// not only on its first line. Without this a single-line gap stayed 0 pt tall and a click
    /// into it never reached the text view.
    override func setFrameSize(_ newSize: NSSize) {
        var size = newSize
        if let clip = superview as? NSClipView { size.height = max(size.height, clip.bounds.height) }
        super.setFrameSize(size)
    }

    /// The SwiftUI side's latest wish (`isFocused` and enabled). Focus is taken a turn later, so the
    /// deferred call checks this again: a newer update (a click into another gap) must win.
    var wantsFocus = false

    func focusSoon() {
        guard wantsFocus else { return }
        Task { @MainActor [weak self] in
            guard let self, self.wantsFocus, let window = self.window, window.firstResponder !== self else { return }
            window.makeFirstResponder(self)
        }
    }

    /// The first update often runs before the field is in the panel: take focus once it is.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { focusSoon() }
    }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok { onFocus() }
        return ok
    }

    static func make(multiline: Bool, font: NSFont) -> ExamTextView {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0
        if !multiline {
            container.maximumNumberOfLines = 1
            container.lineBreakMode = .byClipping
        }
        layout.addTextContainer(container)
        let view = ExamTextView(frame: .zero, textContainer: container)
        view.multiline = multiline
        view.font = font
        view.typingAttributes[.font] = font
        AnswerTextView.disableSystemAI(view)
        view.isRichText = false
        view.importsGraphics = false
        view.allowsUndo = true
        view.drawsBackground = false
        view.isVerticallyResizable = multiline
        view.isHorizontallyResizable = false
        view.textContainerInset = multiline ? NSSize(width: 0, height: 6) : .zero
        view.unregisterDraggedTypes()
        return view
    }

    // MARK: Keys

    override func insertNewline(_ sender: Any?) {
        if multiline { super.insertNewline(sender) } else { onSubmit() }
    }

    override func insertLineBreak(_ sender: Any?) {
        if multiline { super.insertLineBreak(sender) } else { onSubmit() }
    }

    override func insertTab(_ sender: Any?) { onTab() }

    override func insertBacktab(_ sender: Any?) { onBacktab() }

    override func keyDown(with event: NSEvent) {
        if multiline, event.modifierFlags.contains(.command), event.keyCode == 36 || event.keyCode == 76 {
            onCommandSubmit()
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if multiline, event.modifierFlags.contains(.command), event.keyCode == 36 || event.keyCode == 76 {
            onCommandSubmit()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    // MARK: No paste, no drops, no Services, minimal menu

    override func paste(_ sender: Any?) { onPasteBlocked() }
    override func pasteAsPlainText(_ sender: Any?) { onPasteBlocked() }
    override func pasteAsRichText(_ sender: Any?) { onPasteBlocked() }

    override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        onPasteBlocked()
        return false
    }

    override func validRequestor(forSendType sendType: NSPasteboard.PasteboardType?, returnType: NSPasteboard.PasteboardType?) -> Any? {
        nil
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: "Cut", action: #selector(cut(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Copy", action: #selector(copy(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Select All", action: #selector(selectAll(_:)), keyEquivalent: "")
        return menu
    }

    // MARK: Telemetry

    override func shouldChangeText(in affectedCharRange: NSRange, replacementString: String?) -> Bool {
        let ok = super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
        if ok { onEdit((replacementString ?? "").count, affectedCharRange.length, hasMarkedText()) }
        return ok
    }

    // MARK: Look

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
        guard string.isEmpty, !placeholder.isEmpty, let font else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: Tokens.nsColor(\.brand).withAlphaComponent(0.45),
        ]
        NSAttributedString(string: placeholder, attributes: attributes)
            .draw(at: NSPoint(x: textContainerInset.width + (textContainer?.lineFragmentPadding ?? 0), y: textContainerInset.height))
    }
}
