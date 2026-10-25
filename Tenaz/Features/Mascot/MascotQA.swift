import SwiftUI

/// The mascot QA sheet (rules §14): all 12 moods on the four working floods at 64 pt (Small) and
/// 36 pt (the bust), in colour with props, then greyscale with props off, then the silhouette test.
struct MascotQA: View {
    static let floods: [Flood] = [.turn, .good, .fix, .serious]
    private let column: CGFloat = 74

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.m) {
                Text("Tena QA")
                    .font(Typography.display(44))
                    .foregroundStyle(Tokens.ink)
                Text("64 pt and 36 pt on every flood · greyscale without props · silhouettes")
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
            }
            header
            section("Colour, props on", grey: false)
            section("Greyscale, props off", grey: true)
            VStack(alignment: .leading, spacing: 6) {
                Text("Silhouette, 64 pt, props off")
                    .font(Typography.labelBold)
                    .foregroundStyle(Tokens.brand)
                HStack(spacing: 0) {
                    Color.clear.frame(width: 92, height: 1)
                    ForEach(TenaMood.allCases) { mood in
                        TenaView(mood: mood, stage: .juvenile, size: 64, props: false, silhouette: true)
                            .frame(width: column)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Menu-bar glyph: normal, due, hungry, sick, asleep (18 pt and 36 pt)")
                    .font(Typography.labelBold)
                    .foregroundStyle(Tokens.brand)
                HStack(spacing: Tokens.Space.l) {
                    ForEach(TenaGlyphState.allCases, id: \.self) { state in
                        HStack(alignment: .bottom, spacing: Tokens.Space.xs) {
                            TenaGlyph(state: state, size: 18)
                            TenaGlyph(state: state, size: 36)
                        }
                        .foregroundStyle(Tokens.ink)
                    }
                }
                .padding(.leading, 92)
            }
        }
        .padding(Tokens.Space.xl)
        .fixedSize()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .paperBackground()
    }

    private var header: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 92, height: 1)
            ForEach(TenaMood.allCases) { mood in
                Text(mood == .sick ? "Sick" : mood.title)
                    .font(Typography.labelBold)
                    .foregroundStyle(Tokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: column)
            }
        }
    }

    private func section(_ title: String, grey: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Typography.labelBold)
                .foregroundStyle(Tokens.brand)
            VStack(spacing: 0) {
                ForEach(Self.floods, id: \.self) { flood in
                    row(flood, grey: grey)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.control, style: .continuous))
        }
    }

    private func row(_ flood: Flood, grey: Bool) -> some View {
        HStack(alignment: .center, spacing: 0) {
            Text(flood.rawValue)
                .font(Typography.labelBold)
                .foregroundStyle(Tokens.ink)
                .frame(width: 92, alignment: .leading)
                .padding(.leading, Tokens.Space.s)
            ForEach(TenaMood.allCases) { mood in
                VStack(spacing: 2) {
                    TenaView(mood: mood, stage: .juvenile, size: 64, props: !grey, word: "levera")
                    TenaView(mood: mood, stage: .juvenile, size: 36, props: !grey)
                }
                .frame(width: column)
            }
        }
        .padding(.vertical, 6)
        .padding(.trailing, Tokens.Space.s)
        .background(flood.color)
        .grayscale(grey ? 1 : 0)
        .environment(\.colorScheme, flood.inkScheme)
        .environment(\.mascotFlood, flood)
    }
}
