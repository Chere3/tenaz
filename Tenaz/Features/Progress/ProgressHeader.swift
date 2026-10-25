import SwiftUI

/// The top of every rest screen: a Fraunces title, one line of context and an optional trailing
/// piece of text. No eyebrow, no ghost: the hero below does the shouting.
struct ProgressHeader<Trailing: View>: View {
    let eyebrow: String
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.l) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(Typography.displayM)
                    .foregroundStyle(Tokens.ink)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(Typography.body)
                        .foregroundStyle(Tokens.brand)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Tokens.Space.m)
            trailing
        }
    }
}

extension ProgressHeader where Trailing == EmptyView {
    init(eyebrow: String, title: String, subtitle: String? = nil) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// A sentence-case section label with an optional detail on the right.
struct ProgressSectionLabel: View {
    let title: String
    var detail: String?

    init(_ title: String, detail: String? = nil) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
            Text(title)
                .font(Typography.title)
                .foregroundStyle(Tokens.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Tokens.Space.s)
            if let detail {
                Text(detail)
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
                    .fixedSize()
            }
        }
    }
}

/// The hairline between list rows (ink at 12 %).
struct ProgressRule: View {
    var body: some View {
        Rectangle().fill(Tokens.ink.opacity(0.12)).frame(height: Tokens.rule)
    }
}

/// The page every rest screen sits on: paper, generous margins, a readable max width.
/// Off-screen snapshots cannot draw a ScrollView, so they get the same column without one.
struct ProgressPage<Content: View>: View {
    var maxWidth: CGFloat = 1040
    var spacing: CGFloat = Tokens.Space.xl
    @ViewBuilder var content: Content
    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        if isSnapshot {
            column
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .paperBackground()
        } else {
            ScrollView { column }
                .scrollContentBackground(.hidden)
                .paperBackground()
        }
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
        .padding(.horizontal, Tokens.Space.xxl)
        .padding(.vertical, Tokens.Space.l)
        .frame(maxWidth: maxWidth, alignment: .leading)
        .frame(maxWidth: .infinity)
    }
}
