import AppKit
import SwiftUI

/// The answer sheet on the flood: paper, radius 24, 96 pt tall, what the learner types in 44 pt sans.
/// Uses the shared `AnswerTextView` (paste-proof, no system AI, Return submits, Esc cancels).
struct ReviewAnswerSheet: View {
    @Binding var text: String
    var prompt = "Type the English"
    /// Production cards take a whole sentence, so the type steps down to keep it in one line.
    var fontSize: CGFloat = 44
    var onSubmit: () -> Void = {}
    var onCancel: (() -> Void)?
    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        Group {
            if isSnapshot {
                HStack(spacing: 2) {
                    Text(text.isEmpty ? prompt : text)
                        .font(.system(size: fontSize, weight: .medium, design: .rounded))
                        .foregroundStyle(text.isEmpty ? Tokens.brand.opacity(0.5) : Tokens.ink)
                        .lineLimit(1)
                    if !text.isEmpty {
                        Capsule().fill(Tokens.ink).frame(width: 3, height: fontSize * 0.95)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                SheetInput(text: $text, prompt: prompt, fontSize: fontSize, onSubmit: onSubmit, onCancel: onCancel)
            }
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, minHeight: 96, maxHeight: 96)
        .background(RoundedRectangle(cornerRadius: Tokens.Radius.sheet, style: .continuous).fill(Tokens.paper))
    }
}

/// `AnswerInput` at the sheet's size, with its appearance pinned to the flood's ink scheme so the
/// AppKit text resolves dark ink on the light sheet even when the system is in dark mode.
private struct SheetInput: NSViewRepresentable {
    @Binding var text: String
    let prompt: String
    let fontSize: CGFloat
    let onSubmit: () -> Void
    let onCancel: (() -> Void)?
    @Environment(\.colorScheme) private var scheme

    private var font: NSFont {
        let base = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        guard let rounded = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: rounded, size: fontSize) ?? base
    }

    func makeNSView(context: Context) -> AnswerTextView {
        let view = AnswerTextView(font: font)
        view.delegate = context.coordinator
        view.textColor = Tokens.nsColor(\.text)
        view.insertionPointColor = Tokens.nsColor(\.text)
        view.setAccessibilityLabel(prompt)
        view.allowsPaste = false
        return view
    }

    func updateNSView(_ view: AnswerTextView, context: Context) {
        context.coordinator.parent = self
        view.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        if view.string != text { view.string = text }
        view.placeholder = prompt
        view.onSubmit = onSubmit
        view.onCancel = onCancel
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView _: AnswerTextView, context _: Context) -> CGSize? {
        let font = font
        return CGSize(width: proposal.width ?? 280, height: ceil(font.ascender - font.descender + font.leading) + 2)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SheetInput

        init(parent: SheetInput) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.text = view.string
        }
    }
}
