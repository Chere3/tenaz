import AppKit
import SwiftUI

/// Tena's head as a one-ink menu-bar glyph: a solid flat-topped head with three thick tapered fronds per
/// side (58/30/6°, top longest) and the face cut out of it (bead eyes, the wide smile). Every cut and
/// every frond is at least 1.5 pt, so the five states read at 18 pt; `image(_:)` returns a template
/// NSImage so the menu bar tints it. States differ by shape only: due (a badge at the lower right),
/// hungry (fans flared, mouth open), sick (one fan dropped, heavy lids, wavy mouth), asleep (fans
/// curled down, closed arcs).
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

    /// Degrees added to the fan on each side (-1 left, +1 right).
    private func gillLift(side: CGFloat) -> Double {
        switch state {
        case .sick: side < 0 ? -42 : -12
        case .asleep: -16
        case .hungry: 12
        default: 0
        }
    }

    private func draw(in layer: inout GraphicsContext) {
        let ink = GraphicsContext.Shading.foreground
        let head = HeadShape(center: CGPoint(x: 9, y: 10.6), size: CGSize(width: 12.4, height: 9.0))
        let lengths: [CGFloat] = [3.9, 3.4, 2.7].map { $0 * (state == .sick ? 0.85 : 1) }
        for side in [CGFloat(-1), 1] {
            for i in 0 ..< 3 {
                let root = head.contour(polar: [40, 20, 2][i], side: side)
                let a = [58.0, 30, 6][i] + gillLift(side: side)
                let d = CGPoint.heading(a, side: side)
                let bend = CGPoint.heading(a + 10 - (state == .asleep ? 45 : 0), side: side)
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
        let eyeY: CGFloat = 9.4
        for x in [9 - 3.2, 9 + 3.2] as [CGFloat] {
            switch state {
            case .asleep:
                var arc = Path()
                arc.move(to: CGPoint(x: x - 1.3, y: eyeY - 0.1))
                arc.addQuadCurve(to: CGPoint(x: x + 1.3, y: eyeY - 0.1), control: CGPoint(x: x, y: eyeY + 1.4))
                layer.stroke(arc, with: ink, style: line)
            case .sick:
                // Heavy lids: only the lower half of each bead shows.
                var half = Path()
                half.addArc(center: CGPoint(x: x, y: eyeY - 0.1), radius: 1.45, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                half.closeSubpath()
                layer.fill(half, with: ink)
            default:
                layer.fill(Path(ellipseIn: CGRect(x: x - 1.3, y: eyeY - 1.4, width: 2.6, height: 2.8)), with: ink)
            }
        }
        switch state {
        case .hungry:
            layer.fill(Path(ellipseIn: CGRect(x: 7.1, y: 11.7, width: 3.8, height: 2.7)), with: ink)
        case .asleep:
            layer.fill(Path(ellipseIn: CGRect(x: 8.2, y: 12.1, width: 1.6, height: 1.6)), with: ink)
        case .sick:
            var mouth = Path()
            for i in 0 ... 12 {
                let t = CGFloat(i) / 12
                let p = CGPoint(x: 6.2 + 5.6 * t, y: 12.9 + 0.5 * sin(t * 2.5 * 2 * .pi))
                i == 0 ? mouth.move(to: p) : mouth.addLine(to: p)
            }
            layer.stroke(mouth, with: ink, style: line)
        default:
            // The wide axolotl smile: 55 % of the head.
            var mouth = Path()
            mouth.move(to: CGPoint(x: 5.6, y: 12.2))
            mouth.addCurve(to: CGPoint(x: 12.4, y: 12.2), control1: CGPoint(x: 7.4, y: 13.6), control2: CGPoint(x: 10.6, y: 13.6))
            layer.stroke(mouth, with: ink, style: line)
        }
        layer.blendMode = .normal
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
