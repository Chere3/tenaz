import SwiftUI

/// Answer sheet states, time bands, meters and band badges.
struct GalleryFeedback: View {
    @State private var typing = "relia"
    @State private var right = "reliable"

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            HStack(alignment: .top, spacing: Tokens.Space.l) {
                AnswerField(text: $typing)
                AnswerField(text: $right, feedback: .correct)
            }
            VStack(spacing: Tokens.Space.s) {
                InkBand(remaining: 0.8, notches: 5, readout: "4:00")
                InkBand(remaining: 0.22, notches: 5, readout: "1:06")
            }
            VStack(spacing: Tokens.Space.s) {
                MeterBar(kind: .vitality, value: 62)
                MeterBar(kind: .spirit, value: 80)
            }
            HStack(alignment: .center, spacing: Tokens.Space.s) {
                ForEach([0.0, 0.4, 1.0], id: \.self) { fraction in
                    MeterCells(fraction: fraction, fill: Tokens.ink, cells: 7)
                        .frame(width: 110, height: 12)
                }
                Text("session progress segments")
                    .font(Typography.caption)
                    .foregroundStyle(Tokens.brand)
            }
            HStack(alignment: .top, spacing: Tokens.Space.l) {
                BandBadge(band: 3.0)
                BandBadge(band: 3.5, upper: 4.0)
                BandBadge(band: 4.5)
                BandBadge(band: 5.5)
            }
        }
    }
}
