import SwiftUI

/// Debug sheet: all 12 moods at every stage (Standard tier, 120 pt), then the eight stages in one row.
struct MascotGallery: View {
    private let cell: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.m) {
                Text("Tena")
                    .font(Typography.display(56))
                    .foregroundStyle(Tokens.ink)
                Text("12 moods · 8 stages · Ink & Smile")
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
            }
            Grid(horizontalSpacing: 4, verticalSpacing: 2) {
                GridRow {
                    Color.clear.frame(width: 84, height: 1)
                    ForEach(TenaMood.allCases) { mood in
                        Text(mood.title)
                            .font(Typography.labelBold)
                            .foregroundStyle(Tokens.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: cell)
                    }
                }
                ForEach(TenaStage.allCases) { stage in
                    GridRow {
                        Text(stage.title)
                            .font(Typography.labelBold)
                            .foregroundStyle(Tokens.brand)
                            .frame(width: 84, alignment: .leading)
                        ForEach(TenaMood.allCases) { mood in
                            TenaView(mood: mood, stage: stage, size: cell, word: "levera")
                        }
                    }
                }
            }
            GallerySection(title: "Growth stages") {
                HStack(alignment: .bottom, spacing: Tokens.Space.m) {
                    ForEach(TenaStage.allCases) { stage in
                        VStack(spacing: 4) {
                            TenaView(mood: .happy, stage: stage, size: 176)
                            Text("\(stage.rawValue) · \(stage.title)")
                                .font(Typography.labelBold)
                                .foregroundStyle(Tokens.ink)
                        }
                    }
                }
            }
        }
        .padding(Tokens.Space.xl)
        .fixedSize()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .paperBackground()
    }
}
