import AppKit
import SwiftUI

/// SwiftUI bridge to `ParagraphTextView` inside a scroll view. Takes focus when it appears.
struct ParagraphInput: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        // The sheet is always cream, so the field always draws with the light palette.
        scroll.appearance = NSAppearance(named: .aqua)
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let view = ParagraphTextView(frame: .zero)
        view.configure()
        view.delegate = context.coordinator
        view.textColor = Tokens.nsColor(\.text)
        view.insertionPointColor = Tokens.nsColor(\.accent)
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = true
        view.setAccessibilityLabel(placeholder)
        scroll.documentView = view
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let view = scroll.documentView as? ParagraphTextView else { return }
        if view.string != text { view.string = text }
        view.placeholder = placeholder
        view.onSubmit = onSubmit
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ParagraphInput

        init(parent: ParagraphInput) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.text = view.string
        }
    }
}
