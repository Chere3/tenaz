import SwiftUI

/// The pre-commitment folded into the primary pill ("I won't use AI. Start"); this is the honest
/// line about what Tenaz can and can't catch, one label under it. No box: it sits on the flood.
struct PledgeCard: View {
    var body: some View {
        Text("Only Tenaz can be in front during the test; other apps get hidden and noted. It catches common AI shortcuts, not another device.")
            .font(Typography.label)
            .foregroundStyle(Tokens.ink.opacity(0.72))
            .fixedSize(horizontal: false, vertical: true)
    }
}
