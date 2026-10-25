import AppKit
import SwiftUI

/// SwiftUI bridge to `ExamTextView`. Focus is driven from outside (`isFocused`) so gap fields and
/// interview answers can move focus with Tab. Snapshots draw a SwiftUI stand-in, because
/// ImageRenderer cannot draw AppKit views.
struct ExamTextField: View {
    @Binding var text: String
    var prompt = ""
    var multiline = false
    var fontSize: CGFloat = 22
    var weight: Font.Weight = .medium
    var isFocused = true
    var actions = ExamTextActions()
    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        if isSnapshot {
            ExamTextStandIn(text: text, prompt: prompt, multiline: multiline, fontSize: fontSize, weight: weight, isFocused: isFocused)
        } else {
            ExamTextRepresentable(text: $text, prompt: prompt, multiline: multiline, fontSize: fontSize, weight: weight,
                                  isFocused: isFocused, actions: actions)
        }
    }
}

/// Callbacks of an exam field; all optional.
struct ExamTextActions {
    var submit: () -> Void = {}
    var commandSubmit: () -> Void = {}
    var tab: () -> Void = {}
    var backtab: () -> Void = {}
    var focus: () -> Void = {}
    var edit: (Int, Int, Bool) -> Void = { _, _, _ in }
    var pasteBlocked: () -> Void = {}
}

private struct ExamTextRepresentable: NSViewRepresentable {
    @Binding var text: String
    var prompt: String
    var multiline: Bool
    var fontSize: CGFloat
    var weight: Font.Weight
    var isFocused: Bool
    var actions: ExamTextActions
    @Environment(\.isEnabled) private var isEnabled

    static func font(_ size: CGFloat, regular: Bool = false) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: regular ? .regular : .medium)
        guard let rounded = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: rounded, size: size) ?? base
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = multiline
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        // Answers are typed on the cream exam sheet, so the field is always drawn in the light appearance.
        scroll.appearance = NSAppearance(named: .aqua)
        let view = ExamTextView.make(multiline: multiline, font: Self.font(fontSize, regular: weight == .regular))
        view.delegate = context.coordinator
        view.textColor = Tokens.nsColor(\.text)
        view.insertionPointColor = Tokens.nsColor(\.accent)
        view.minSize = NSSize(width: 0, height: 0)
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.autoresizingMask = [.width, .height]
        view.setAccessibilityLabel(prompt)
        scroll.documentView = view
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let view = scroll.documentView as? ExamTextView else { return }
        if view.string != text { view.string = text }
        view.placeholder = prompt
        view.onSubmit = actions.submit
        view.onCommandSubmit = actions.commandSubmit
        view.onTab = actions.tab
        view.onBacktab = actions.backtab
        view.onFocus = actions.focus
        view.onEdit = actions.edit
        view.onPasteBlocked = actions.pasteBlocked
        // Disabled (the leave card is up): no typing, and the keyboard goes back to the panel so
        // Return reaches "Keep going" instead of the answer.
        view.isEditable = isEnabled
        view.wantsFocus = isFocused && isEnabled
        if !isEnabled, let window = view.window, window.firstResponder === view { window.makeFirstResponder(nil) }
        if view.wantsFocus, view.window?.firstResponder !== view { view.focusSoon() }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        if multiline { return nil }
        let font = Self.font(fontSize, regular: weight == .regular)
        return CGSize(width: proposal.width ?? 120, height: ceil(font.ascender - font.descender + font.leading) + 2)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ExamTextRepresentable

        init(parent: ExamTextRepresentable) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.text = view.string
        }
    }
}
