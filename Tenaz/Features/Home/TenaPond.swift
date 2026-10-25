import SwiftUI

/// Tena in her round halftone pond, flat (no outline, no shadow), at any size. Today and the sidebar
/// no longer use it (Full Bleed never frames Tena on a hero screen); other screens still do.
struct TenaPond: View {
    let mood: TenaMood
    let stage: TenaStage
    var size: CGFloat = 220

    var body: some View {
        ZStack {
            Circle().fill(Tokens.paper)
            PondWater()
                .clipShape(.circle)
            TenaView(mood: mood, stage: stage, size: size * 1.04)
                .offset(y: -size * 0.03)
        }
        .frame(width: size, height: size)
    }
}
