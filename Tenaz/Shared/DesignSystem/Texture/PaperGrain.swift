import SwiftUI

/// Deterministic paper speckle (risograph stock). Off under Reduce Transparency and Increase Contrast.
struct PaperGrain: View {
    var density: CGFloat = 1
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        if !reduceTransparency && contrast != .increased {
            Canvas { context, size in
                var rng = SeededGenerator(seed: 0x7E7A_2026)
                let count = Int(size.width * size.height / 70 * density)
                var fine = Path()
                var coarse = Path()
                for i in 0 ..< count {
                    let x = CGFloat.random(in: 0 ... size.width, using: &rng)
                    let y = CGFloat.random(in: 0 ... size.height, using: &rng)
                    if i % 9 == 0 {
                        let r = CGFloat.random(in: 0.7 ... 1.3, using: &rng)
                        coarse.addEllipse(in: CGRect(x: x, y: y, width: r, height: r * 0.8))
                    } else {
                        let r = CGFloat.random(in: 0.35 ... 0.7, using: &rng)
                        fine.addEllipse(in: CGRect(x: x, y: y, width: r, height: r))
                    }
                }
                context.fill(fine, with: .color(Tokens.ink.opacity(0.10)))
                context.fill(coarse, with: .color(Tokens.brand.opacity(0.14)))
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
