import SwiftUI

/// Tena the axolotl, drawn natively. `TenaView(mood: .happy, stage: .juvenile, size: 160)`.
/// Idles at up to 30 fps while on screen; holds the resting pose when hidden, under Reduce Motion,
/// or when `mascotStill` is set (snapshots).
struct TenaView: View {
    let mood: TenaMood
    let stage: TenaStage
    var size: CGFloat = 160
    /// The soft floor shadow; off for the app icon, where Icon Composer adds its own.
    var ground = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mascotStill) private var still
    @Environment(\.colorScheme) private var scheme
    @State private var isVisible = false

    private var paused: Bool { still || reduceMotion || !isVisible }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused)) { timeline in
            let time = paused ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
            Canvas { context, _ in
                let rig = TenaRig(mood: mood, stage: stage, time: time, size: size, dark: scheme == .dark, ground: ground)
                if scheme == .dark {
                    // Night paper: the ink outline vanishes, so a cream keyline hugs the silhouette.
                    let k = max(1.2, size * 0.01)
                    var flat = ColorMatrix()
                    flat.r1 = 0; flat.g2 = 0; flat.b3 = 0
                    flat.r5 = 1; flat.g5 = 0.969; flat.b5 = 0.933
                    for angle in stride(from: 0.0, to: 360, by: 45) {
                        let rad = angle * .pi / 180
                        context.drawLayer { layer in
                            layer.translateBy(x: k * cos(rad), y: k * sin(rad))
                            layer.addFilter(.colorMatrix(flat))
                            var inner = layer
                            rig.draw(in: &inner)
                        }
                    }
                    rig.draw(in: &context)
                } else {
                    rig.draw(in: &context)
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .accessibilityElement()
        .accessibilityLabel("Tena, \(stage.title.lowercased()), \(mood.title.lowercased())")
    }
}
