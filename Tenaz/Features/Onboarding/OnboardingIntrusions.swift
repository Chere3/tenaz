import SwiftUI

/// Step 2: what Tenaz can do to get your attention, and that all of it starts OFF.
struct OnboardingIntrusions: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            Text("What Tenaz can do")
                .font(Typography.display(52))
                .foregroundStyle(Tokens.ink)
            VStack(spacing: 0) {
                rule
                IntrusionRow(systemImage: "textformat.size.larger", title: "Big words on your screen",
                             detail: "A 3-word quiz between tasks. Under a minute.")
                rule
                IntrusionRow(systemImage: "lock.open.fill", title: "A writing gate after unlock",
                             detail: "Write 2 or 3 sentences before you start.")
                rule
                IntrusionRow(systemImage: "signature", title: "Penalties you choose",
                             detail: "Tena loses health when you skip. You write the rules.")
                rule
            }
            HStack(alignment: .top, spacing: Tokens.Space.s) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Tokens.ink)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Everything is off now. Nothing appears during a meeting.")
                        .font(Typography.labelBold)
                        .foregroundStyle(Tokens.ink)
                    Text("Turn them on later in Settings, when you are ready. ⌃⌥⌘⎋ stops everything at once.")
                        .font(Typography.label)
                        .foregroundStyle(Tokens.brand)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var rule: some View {
        Rectangle().fill(Tokens.ink.opacity(0.12)).frame(height: Tokens.rule)
    }
}
