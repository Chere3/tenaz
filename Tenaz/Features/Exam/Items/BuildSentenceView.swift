import SwiftUI
import TenazCore

/// Build a Sentence: someone says something; the learner taps the pieces of their reply in order
/// (or presses their numbers). Tapping a placed piece, or Delete, takes it back.
struct BuildSentenceView: View {
    @Bindable var runner: ExamRunner
    let task: ExamTask

    private var chunks: [String] { task.item?.chunks ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xl) {
            HStack(alignment: .center, spacing: Tokens.Space.l) {
                VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                    Text("Your colleague says")
                        .font(Typography.labelBold)
                        .foregroundStyle(Tokens.brand)
                    Text("\u{201C}\(task.item?.context ?? "")\u{201D}")
                        .font(Typography.display(36, weight: 800))
                        .foregroundStyle(Tokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                Text("Your reply")
                    .font(Typography.labelBold)
                    .foregroundStyle(Tokens.brand)
                FlowLayout(spacing: Tokens.Space.xs, lineSpacing: Tokens.Space.s) {
                    ForEach(Array(runner.draft.order.enumerated()), id: \.element) { position, index in
                        ChunkTile(text: chunks[safe: index] ?? "", number: nil, style: .placed) { remove(at: position) }
                    }
                    if runner.draft.order.count < chunks.count {
                        SlotHint(remaining: chunks.count - runner.draft.order.count)
                    }
                }
                .padding(Tokens.Space.l)
                .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
                .examSheet()
            }
            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                HStack {
                    Text("Pieces")
                        .font(Typography.labelBold)
                        .foregroundStyle(Tokens.brand)
                    Spacer()
                    HStack(spacing: Tokens.Space.xs) {
                        KeyCap("1-\(chunks.count)")
                        Text("place")
                        KeyCap("Delete")
                        Text("take back")
                    }
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
                }
                FlowLayout(spacing: Tokens.Space.s, lineSpacing: Tokens.Space.s) {
                    ForEach(chunks.indices, id: \.self) { i in
                        let used = runner.draft.order.contains(i)
                        ChunkTile(text: chunks[i], number: i + 1, style: used ? .used : .bank) { place(i) }
                            .allowsHitTesting(!used)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: 900)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func place(_ index: Int) {
        guard !runner.draft.order.contains(index) else { return }
        runner.draft.order.append(index)
    }

    private func remove(at position: Int) {
        guard runner.draft.order.indices.contains(position) else { return }
        runner.draft.order.remove(at: position)
    }
}

/// A word piece. Bank pieces are paper with their number key, placed ones are ink, used ones fade.
private struct ChunkTile: View {
    enum Style { case bank, placed, used }
    let text: String
    let number: Int?
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let number, style == .bank {
                    Text("\(number)")
                        .font(Typography.numeric(14))
                        .opacity(0.55)
                }
                Text(text)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(style == .used ? Tokens.brand.opacity(0.6) : style == .placed ? Tokens.paper : Tokens.ink)
            .padding(.horizontal, 18)
            .frame(minHeight: 50)
            .modifier(TileSurface(style: style))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style == .placed ? "\(text), placed. Tap to take back" : text)
    }
}

/// The dashed empty slot at the end of the reply line.
private struct SlotHint: View {
    let remaining: Int

    var body: some View {
        Text(remaining == 1 ? "1 more piece" : "\(remaining) more pieces")
            .font(Typography.label)
            .foregroundStyle(Tokens.ink.opacity(0.5))
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
    }
}

/// Bank and placed pieces sit on paper / ink; a used piece is just a faint ghost on the flood.
private struct TileSurface: ViewModifier {
    let style: ChunkTile.Style

    func body(content: Content) -> some View {
        if style == .used {
            content.background { Capsule().fill(Tokens.ink.opacity(0.1)) }
        } else {
            content.modifier(ExamSheet(radius: 25, fill: style == .placed ? Tokens.ink : Tokens.paper))
        }
    }
}
