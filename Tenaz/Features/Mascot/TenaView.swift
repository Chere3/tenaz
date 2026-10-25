import SwiftUI

/// Tena the axolotl, drawn natively. `TenaView(mood: .happy, stage: .juvenile, size: 160)`.
/// Idles at up to 30 fps while on screen; holds the resting pose when hidden, under Reduce Motion,
/// or when `mascotStill` is set (snapshots). One rig draw per frame: no keyline, no ground shadow.
struct TenaView: View {
    let mood: TenaMood
    let stage: TenaStage
    var size: CGFloat = 160
    /// Kept for source compatibility; Tena no longer draws a ground shadow.
    var ground = false
    /// Mood props (headset, sign, bandage, medal, z).
    var props = true
    /// The due word on Nagging's sign.
    var word: String?
    /// Regenerating: task progress 0...1 regrows the injured limb.
    var progress: Double = 0.4
    /// Solid ink, no face: the QA silhouette test.
    var silhouette = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mascotStill) private var still
    @Environment(\.mascotFlood) private var flood
    @Environment(\.colorScheme) private var scheme
    @State private var isVisible = false

    private var paused: Bool { still || reduceMotion || !isVisible }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused)) { timeline in
            let time = paused ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
            Canvas { context, _ in
                let rig = TenaRig(mood: mood, stage: stage, time: time, size: size, dark: scheme == .dark,
                                  props: props, word: word, progress: progress,
                                  warmFlood: flood == .fix || flood == .celebrate, silhouette: silhouette)
                rig.draw(in: &context)
            }
        }
        .frame(width: size, height: size)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .accessibilityElement()
        .accessibilityLabel("Tena, \(stage.title.lowercased()), \(mood.title.lowercased())")
    }
}
