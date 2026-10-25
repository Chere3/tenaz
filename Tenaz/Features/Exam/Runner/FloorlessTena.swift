import SwiftUI

/// Tena without her ground shadow: the bottom of the art is cut off, so on a flood or paper she
/// reads as a character cropped by the window, not a sticker standing on an ellipse.
struct FloorlessTena: View {
    let mood: TenaMood
    let size: CGFloat

    var body: some View {
        TenaView(mood: mood, stage: .juvenile, size: size)
            .frame(width: size, height: size * 0.84, alignment: .top)
            .clipped()
    }
}
