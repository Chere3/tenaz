import SwiftUI

/// Tena whole beside a hero row on paper or a flood, never cut by an inner frame: the window's right
/// edge takes only her near gills (and tail). `inset` is how far that window edge lies beyond the row's
/// trailing side; her head and hands stay 24 pt inside it.
struct FloorlessTena: View {
    let mood: TenaMood
    let size: CGFloat
    var inset: CGFloat = 0

    var body: some View {
        let rig = TenaRig(mood: mood, stage: .juvenile, time: 0, size: size)
        let keep = [rig.headFrame, rig.armFrame].compactMap(\.self).map(\.maxX).max() ?? 0.75
        TenaView(mood: mood, stage: .juvenile, size: size)
            .offset(x: inset - 24 + (1 - keep) * size)
    }
}
