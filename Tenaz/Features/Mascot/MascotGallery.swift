import SwiftUI

/// Debug sheet: all 12 moods across four stages, then the eight stages in one row.
struct MascotGallery: View {
    static let stages: [TenaStage] = [.hatchling, .juvenile, .adult, .elder]
    private let cell: CGFloat = 112

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.m) {
                Text("Tena")
                    .font(Typography.display(56))
                    .foregroundStyle(Tokens.ink)
                Text("12 moods · 8 stages")
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
            }
            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                GridRow {
                    Color.clear.frame(width: 76, height: 1)
                    ForEach(TenaMood.allCases) { mood in
                        Text(mood.title)
                            .font(Typography.labelBold)
                            .foregroundStyle(Tokens.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: cell)
                    }
                }
                ForEach(Self.stages) { stage in
                    GridRow {
                        Text(stage.title)
                            .font(Typography.labelBold)
                            .foregroundStyle(Tokens.brand)
                            .frame(width: 76, alignment: .leading)
                        ForEach(TenaMood.allCases) { mood in
                            TenaView(mood: mood, stage: stage, size: cell)
                        }
                    }
                }
            }
            GallerySection(title: "Growth stages") {
                HStack(alignment: .bottom, spacing: Tokens.Space.m) {
                    ForEach(TenaStage.allCases) { stage in
                        VStack(spacing: 4) {
                            TenaView(mood: .happy, stage: stage, size: 150)
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
