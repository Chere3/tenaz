import SwiftUI

/// A calm full-bleed moment between cards (checkpoint, waiting, empty, done): one hero (a giant number
/// or title), one line, the one ink pill and an optional text secondary. Tena hangs off the bottom-left
/// corner, drawn by `ReviewBoard`; this is the text column to her right.
struct ReviewPause<Extra: View>: View {
    let hero: String
    var heroFont: Font = Typography.displayL
    /// A short line right under a number hero ("words right today").
    var caption: String?
    let line: String
    let primaryTitle: String
    let primary: () -> Void
    var secondaryTitle: String?
    var secondary: () -> Void = {}
    @ViewBuilder var extra: Extra

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                Text(hero)
                    .font(heroFont)
                    .foregroundStyle(Tokens.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText(countsDown: true))
                if let caption {
                    Text(caption)
                        .font(Typography.title)
                        .foregroundStyle(Tokens.ink)
                        .padding(.top, -Tokens.Space.xs)
                }
                Text(line)
                    .font(Typography.body)
                    .foregroundStyle(Tokens.brand)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 440, alignment: .leading)
                    .padding(.top, Tokens.Space.s)
                extra
                    .padding(.top, Tokens.Space.l)
                HStack(spacing: Tokens.Space.m) {
                    Button(action: primary) {
                        HStack(spacing: Tokens.Space.s) {
                            Text(primaryTitle)
                                .lineLimit(1)
                                .fixedSize()
                            KeyCap("Return")
                        }
                    }
                    .buttonStyle(.fat)
                    .keyboardShortcut(.defaultAction)
                    .fixedSize()
                    if let secondaryTitle {
                        Button(action: secondary) {
                            HStack(spacing: 6) {
                                Text(secondaryTitle)
                                KeyCap("esc")
                            }
                        }
                        .buttonStyle(.ink)
                        .keyboardShortcut(.cancelAction)
                        .fixedSize()
                    }
                }
                .padding(.top, Tokens.Space.xl)
                Spacer(minLength: 0)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, proxy.size.width * BleedTena.columnShare)
        }
    }
}

extension ReviewPause where Extra == EmptyView {
    init(hero: String, heroFont: Font = Typography.displayL, caption: String? = nil, line: String, primaryTitle: String,
         primary: @escaping () -> Void, secondaryTitle: String? = nil, secondary: @escaping () -> Void = {})
    {
        self.init(hero: hero, heroFont: heroFont, caption: caption, line: line, primaryTitle: primaryTitle, primary: primary,
                  secondaryTitle: secondaryTitle, secondary: secondary) { EmptyView() }
    }
}
