import SwiftUI

/// The type scale: Fraunces for display, SF Pro Rounded for everything you read. One hero per screen.
struct GalleryType: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            HStack(alignment: .bottom, spacing: Tokens.Space.l) {
                Text("14")
                    .font(Typography.numberHero)
                    .foregroundStyle(Tokens.ink)
                    .frame(height: 120, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text("numberHero 160 · wordHero 200")
                        .font(Typography.caption)
                        .foregroundStyle(Tokens.brand)
                    Text("Placement test")
                        .font(Typography.displayL)
                        .foregroundStyle(Tokens.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("displayL 64")
                        .font(Typography.caption)
                        .foregroundStyle(Tokens.brand)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("I will follow up tomorrow.")
                    .font(Typography.prompt)
                    .foregroundStyle(Tokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("prompt 50")
                    .font(Typography.caption)
                    .foregroundStyle(Tokens.brand)
            }
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.l) {
                Text("Level up").font(Typography.displayM)
                Text("displayM 36").font(Typography.caption).foregroundStyle(Tokens.brand)
                Text("Section").font(Typography.displayS)
                Text("displayS 26").font(Typography.caption).foregroundStyle(Tokens.brand)
            }
            .foregroundStyle(Tokens.ink)
            VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                Text("Title, SF Rounded semibold 22").font(Typography.title)
                Text("Body copy reads at 18 pt with room to breathe.").font(Typography.body)
                Text("Label, 14 pt, sentence case, in the brand ink").font(Typography.label).foregroundStyle(Tokens.brand)
                Text("follow up: what you type is always sans (answer 34)").font(Typography.answer).lineLimit(1).minimumScaleFactor(0.5)
            }
            .foregroundStyle(Tokens.ink)
        }
    }
}
