import SwiftUI
import TenazCore

/// The motion tokens, as numbers (motion itself is judged in the live window).
struct GalleryMotion: View {
    var body: some View {
        HStack(spacing: Tokens.Space.xs) {
            ForEach(MotionToken.allCases, id: \.self) { token in
                VStack(alignment: .leading, spacing: 2) {
                    Text(token.rawValue).font(Typography.labelBold).foregroundStyle(Tokens.ink)
                    Text(Self.describe(token.curve)).font(Typography.caption).foregroundStyle(Tokens.brand)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { RoundedRectangle(cornerRadius: Tokens.Radius.control, style: .continuous).fill(Tokens.card) }
            }
        }
    }

    private static func describe(_ curve: MotionCurve) -> String {
        switch curve {
        case let .spring(duration, bounce): "\(duration.formatted())s · b \(bounce.formatted())"
        case let .loop(duration): "loop \(duration)s"
        case let .crossfade(duration): "fade \(duration)s"
        }
    }
}
