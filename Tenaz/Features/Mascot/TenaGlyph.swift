import AppKit
import SwiftUI

/// Tena's head as a one-ink menu-bar glyph: a solid, wide, flat-topped head (the figure's 1.55 : 1) with
/// three tapered fronds per side (58/30/6°, top longest) and the face cut out of it. Every cut and every
/// frond is at least 1.5 pt; `image(_:)` returns a template NSImage so the menu bar tints it. The five
/// states differ in silhouette first, so they read at 18 pt in one ink:
/// - normal: fans up, bead eyes, the wide smile;
/// - due: normal plus a solid badge at the lower right;
/// - hungry: fans flared high, a big open mouth hole that fills the lower face;
/// - sick: the whole head tipped, the left fan hanging straight down, flat lid lines and a wavy mouth;
/// - asleep: fans folded flat back and short, closed lid arcs, no mouth, a "z" at the upper right.
struct TenaGlyph: View {
    let state: TenaGlyphState
    var size: CGFloat = 18

    var body: some View {
        Canvas { context, canvasSize in
            let u = canvasSize.width / 18
            context.scaleBy(x: u, y: u)
            context.drawLayer { layer in
                draw(in: &layer)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// Degrees added to frond `i` on each side (-1 left, +1 right).
    private func gillLift(_ i: Int, side: CGFloat) -> Double {
        switch state {
        case .sick: side < 0 ? [-78.0, -70, -60][i] : -8
        case .asleep: [-52.0, -34, -20][i]
        case .hungry: 16
        default: 0
        }
    }

    private var gillLength: CGFloat {
        switch state {
        case .asleep: 0.72
        case .sick: 0.9
        default: 1
        }
    }

    private func draw(in layer: inout GraphicsContext) {
        let ink = GraphicsContext.Shading.foreground
        let head = HeadShape(center: CGPoint(x: 9, y: state == .asleep ? 11.4 : 10.8), size: CGSize(width: 13.2, height: 8.5))
        if state == .sick {
            // Tipped toward the drooping fan: the outline itself goes lopsided.
            layer.concatenate(CGAffineTransform(translationX: 9, y: 11).rotated(by: -12 * .pi / 180).translatedBy(x: -9, y: -11))
        }
        let lengths: [CGFloat] = [3.9, 3.4, 2.7].map { $0 * gillLength }
        for side in [CGFloat(-1), 1] {
            for i in 0 ..< 3 {
                let root = head.contour(polar: [40, 20, 2][i], side: side)
                let a = [58.0, 30, 6][i] + gillLift(i, side: side)
                let d = CGPoint.heading(a, side: side)
                let bend = CGPoint.heading(a + (state == .asleep ? -6 : 10), side: side)
                let c = root + d * (lengths[i] * 0.5)
                let tip = c + bend * (lengths[i] * 0.5)
                let spine = (0 ... 8).map { Curve.quad(root - (root - head.center).normalized * 1.0, c, tip, CGFloat($0) / 8) }
                // 2.5 pt at the root, 1.5 pt at the round tip.
                layer.fill(Curve.ribbon(spine, halfWidth: { s in 1.25 * (1 - s) + 0.75 * s }), with: ink)
            }
        }
        layer.fill(head.path, with: ink)

        // Face, cut out of the silhouette: 1.5 pt lines, 2.6 pt beads.
        layer.blendMode = .destinationOut
        let line = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
        let eyeY = head.center.y - 1.2
        for x in [9 - 3.3, 9 + 3.3] as [CGFloat] {
            switch state {
            case .asleep:
                var arc = Path()
                arc.move(to: CGPoint(x: x - 1.4, y: eyeY - 0.2))
                arc.addQuadCurve(to: CGPoint(x: x + 1.4, y: eyeY - 0.2), control: CGPoint(x: x, y: eyeY + 1.5))
                layer.stroke(arc, with: ink, style: line)
            case .sick:
                // Heavy, flat lids: a level lid line, no bead showing.
                var lid = Path()
                lid.move(to: CGPoint(x: x - 1.4, y: eyeY + 0.3))
                lid.addLine(to: CGPoint(x: x + 1.4, y: eyeY + 0.3))
                layer.stroke(lid, with: ink, style: line)
            default:
                layer.fill(Path(ellipseIn: CGRect(x: x - 1.3, y: eyeY - 1.4, width: 2.6, height: 2.8)), with: ink)
            }
        }
        let mouthY = head.center.y + 1.6
        switch state {
        case .hungry:
            // Wide open, a D that fills the lower face: the hole is the state.
            var mouth = Path()
            mouth.move(to: CGPoint(x: 5.9, y: mouthY - 0.3))
            mouth.addLine(to: CGPoint(x: 12.1, y: mouthY - 0.3))
            mouth.addCurve(to: CGPoint(x: 5.9, y: mouthY - 0.3), control1: CGPoint(x: 12.0, y: mouthY + 3.4), control2: CGPoint(x: 6.0, y: mouthY + 3.4))
            mouth.closeSubpath()
            layer.fill(mouth, with: ink)
        case .asleep:
            break
        case .sick:
            var mouth = Path()
            for i in 0 ... 12 {
                let t = CGFloat(i) / 12
                let p = CGPoint(x: 6.4 + 5.2 * t, y: mouthY + 0.9 + 0.5 * sin(t * 2.5 * 2 * .pi))
                i == 0 ? mouth.move(to: p) : mouth.addLine(to: p)
            }
            layer.stroke(mouth, with: ink, style: line)
        default:
            // The wide axolotl smile: 55 % of the head.
            var mouth = Path()
            mouth.move(to: CGPoint(x: 5.4, y: mouthY))
            mouth.addCurve(to: CGPoint(x: 12.6, y: mouthY), control1: CGPoint(x: 7.3, y: mouthY + 1.6), control2: CGPoint(x: 10.7, y: mouthY + 1.6))
            layer.stroke(mouth, with: ink, style: line)
        }
        layer.blendMode = .normal
        if state == .asleep {
            // One "z" at the upper right, where the folded fans left room.
            var z = Path()
            z.move(to: CGPoint(x: 13.2, y: 1.4))
            z.addLine(to: CGPoint(x: 16.6, y: 1.4))
            z.addLine(to: CGPoint(x: 13.2, y: 4.8))
            z.addLine(to: CGPoint(x: 16.6, y: 4.8))
            layer.stroke(z, with: ink, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        if state == .due {
            // Due dot: a solid badge at the lower right, under the gill fan, with a cut ring
            // separating it from the jaw.
            layer.blendMode = .destinationOut
            layer.fill(Path(ellipseIn: CGRect(x: 12.0, y: 12.0, width: 6.0, height: 6.0)), with: ink)
            layer.blendMode = .normal
            layer.fill(Path(ellipseIn: CGRect(x: 13.15, y: 13.15, width: 3.7, height: 3.7)), with: ink)
        }
    }

    /// A template image for the status item (the system tints it for light, dark and highlighted menu bars).
    static func image(_ state: TenaGlyphState) -> NSImage {
        let renderer = ImageRenderer(content: TenaGlyph(state: state))
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil) ?? NSImage()
        image.isTemplate = true
        image.accessibilityDescription = "Tenaz"
        return image
    }
}
