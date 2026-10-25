import AppKit
import SwiftUI

/// SwiftUI bridge to `WritingTextView`; snapshots draw the text as plain `Text`.
struct WritingInput: View {
    @Binding var text: String
    var placeholder = "Write here…"
    var onCancel: () -> Void = {}
    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        if isSnapshot {
            Text(text.isEmpty ? placeholder : text)
                .font(.system(size: 20, weight: .regular, design: .rounded))
                .foregroundStyle(text.isEmpty ? Tokens.brand.opacity(0.45) : Tokens.ink)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            WritingRepresentable(text: $text, placeholder: placeholder, onCancel: onCancel)
        }
    }
}

private struct WritingRepresentable: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onCancel: () -> Void
    @Environment(\.colorScheme) private var scheme

    static let font: NSFont = {
        let base = NSFont.systemFont(ofSize: 20, weight: .regular)
        return base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 20) } ?? base
    }()

    func makeNSView(context: Context) -> NSScrollView {
        let (scroll, view) = WritingTextView.make(font: Self.font)
        view.delegate = context.coordinator
        view.textColor = Tokens.nsColor(\.text)
        view.insertionPointColor = Tokens.nsColor(\.text)
        view.setAccessibilityLabel(placeholder)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        // The sheet is light paper on a dark-ink flood even in system dark mode: resolve colours by the
        // flood's scheme, not the window's appearance.
        scroll.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        guard let view = scroll.documentView as? WritingTextView else { return }
        if view.string != text { view.string = text }
        view.placeholder = placeholder
        view.onCancel = onCancel
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: WritingRepresentable

        init(parent: WritingRepresentable) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.text = view.string
        }
    }
}
