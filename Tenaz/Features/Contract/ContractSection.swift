import SwiftUI

/// A titled block of the Contract: a Fraunces title, an optional one-line note, and the rows on a flat
/// card (no outline, no shadow). Rows are separated by `ContractRule`, a 1 pt ink hairline.
struct ContractSection<Content: View>: View {
    let title: String
    var note: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.displayS)
                    .foregroundStyle(Tokens.ink)
                if let note {
                    Text(note)
                        .font(Typography.label)
                        .foregroundStyle(Tokens.brand)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, Tokens.Space.l)
            .padding(.vertical, Tokens.Space.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous).fill(Tokens.card) }
        }
    }
}

/// The 1 pt hairline between list rows.
struct ContractRule: View {
    var body: some View {
        Rectangle().fill(Tokens.ink.opacity(0.12)).frame(height: Tokens.rule)
    }
}
