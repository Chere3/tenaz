import SwiftUI
import TenazCore

/// The text a writing kind works on (a message to rewrite, a short text to summarise, a Spanish
/// sentence, a KPI table, a story opener), quoted above the answer sheet on the flood: ink text beside
/// a thin rule, no card (Full Bleed). Short texts take their own height; long ones scroll inside `maxHeight`.
struct TaskTextBlock: View {
    let text: String
    var kind: WritingKind = .personal
    var fontSize: CGFloat = 17
    var maxHeight: CGFloat = 160

    var body: some View {
        HeightCap(maxHeight: maxHeight) {
            ViewThatFits(in: .vertical) {
                label
                SnapshotSafeScroll { label }
            }
        }
        .padding(.leading, Tokens.Space.m)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Tokens.ink.opacity(0.3))
                .frame(width: 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("The text: \(text)")
    }

    private var label: some View {
        Text(text)
            // A KPI table lines up in columns only in a monospaced face.
            .font(kind == .chart ? .system(size: fontSize - 1, weight: .regular, design: .monospaced)
                : .system(size: fontSize, weight: .regular, design: .rounded))
            .foregroundStyle(Tokens.ink)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Proposes at most `maxHeight` to its child and takes the child's own size (a `.frame(maxHeight:)`
/// would grow to the cap even around two lines of text).
private struct HeightCap: Layout {
    let maxHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        return child.sizeThatFits(ProposedViewSize(width: proposal.width, height: min(proposal.height ?? maxHeight, maxHeight)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }
}
