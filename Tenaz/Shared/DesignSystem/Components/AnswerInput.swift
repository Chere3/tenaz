import AppKit
import SwiftUI

/// SwiftUI bridge to `AnswerTextView`. Takes focus when it appears (start cost near zero, R4).
/// ImageRenderer cannot draw AppKit views, so snapshots show the same text as a plain `Text`.
struct AnswerInput: NSViewRepresentable {
    @Binding var text: String
    var prompt: String
    var allowsPaste = true
    var onSubmit: () -> Void
    /// Esc while typing (nil = system default).
    var onCancel: (() -> Void)?

    /// SF Pro Rounded Medium 28, the `answer` type token.
    static let font: NSFont = {
        let base = NSFont.systemFont(ofSize: 28, weight: .medium)
        guard let rounded = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: rounded, size: 28) ?? base
    }()

    func makeNSView(context: Context) -> AnswerTextView {
        let view = AnswerTextView(font: Self.font)
        view.delegate = context.coordinator
        view.textColor = Tokens.nsColor(\.text)
        view.insertionPointColor = Tokens.nsColor(\.text)
        view.setAccessibilityLabel(prompt)
        return view
    }

    func updateNSView(_ view: AnswerTextView, context: Context) {
        context.coordinator.parent = self
        if view.string != text { view.string = text }
        view.placeholder = prompt
        view.allowsPaste = allowsPaste
        view.onSubmit = onSubmit
        view.onCancel = onCancel
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: AnswerTextView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 280, height: ceil(Self.font.ascender - Self.font.descender + Self.font.leading) + 2)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AnswerInput

        init(parent: AnswerInput) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.text = view.string
        }
    }
}
