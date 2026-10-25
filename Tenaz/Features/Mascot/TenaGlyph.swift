import AppKit
import SwiftUI

/// Tena's head as a one-ink menu-bar glyph: the flat-topped head with three tapered fronds per side
/// (58/30/6°, top longest), the face cut out of it: bead eyes and the wide smile line.
/// Readable at 18 pt; `image(_:)` returns a template NSImage so the menu bar tints it.
/// States differ by shape only: due (badge), hungry (open mouth), sick (limp gills, heavy lids,
/// wavy mouth), asleep (closed arcs, curled gills).
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

    private var gillLift: Double {
        switch state {
        case .sick: -22
        case .asleep: -10
        default: 0
        }
    }

    private func draw(in layer: inout GraphicsContext) {
        let ink = GraphicsContext.Shading.foreground
        let head = HeadShape(center: CGPoint(x: 9, y: 10.4), size: CGSize(width: 12.4, height: 8.4))
        let lengths: [CGFloat] = [3.9, 3.4, 2.7]
        for side in [CGFloat(-1), 1] {
            for i in 0 ..< 3 {
                let root = head.contour(polar: [40, 20, 2][i], side: side)
                let a = [58.0, 30, 6][i] + gillLift
                let d = CGPoint.heading(a, side: side)
                let bend = CGPoint.heading(a + 10 - (state == .asleep ? 30 : 0), side: side)
                let c = root + d * (lengths[i] * 0.5)
                let tip = c + bend * (lengths[i] * 0.5)
                let spine = (0 ... 8).map { Curve.quad(root - d * 0.8, c, tip, CGFloat($0) / 8) }
                layer.fill(Curve.ribbon(spine, halfWidth: { s in 0.95 * (1 - s) + 0.5 * s }), with: ink)
            }
        }
        layer.fill(head.path, with: ink)

        // Face, cut out of the silhouette.
        layer.blendMode = .destinationOut
        let line = StrokeStyle(lineWidth: 1.05, lineCap: .round)
        for x in [9 - 3.1, 9 + 3.1] {
            switch state {
            case .asleep:
                var arc = Path()
                arc.move(to: CGPoint(x: x - 1.2, y: 10.0))
                arc.addQuadCurve(to: CGPoint(x: x + 1.2, y: 10.0), control: CGPoint(x: x, y: 11.2))
                layer.stroke(arc, with: ink, style: line)
            case .sick:
                // Heavy lids: the top half of each bead is gone.
                var half = Path()
                half.addArc(center: CGPoint(x: x, y: 9.9), radius: 1.05, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                half.closeSubpath()
                layer.fill(half, with: ink)
            default:
                layer.fill(Path(ellipseIn: CGRect(x: x - 1.0, y: 8.9, width: 2.0, height: 2.15)), with: ink)
            }
        }
        switch state {
        case .hungry:
            var mouth = Path()
            mouth.move(to: CGPoint(x: 6.6, y: 12.2))
            mouth.addCurve(to: CGPoint(x: 11.4, y: 12.2), control1: CGPoint(x: 7.8, y: 11.8), control2: CGPoint(x: 10.2, y: 11.8))
            mouth.addCurve(to: CGPoint(x: 6.6, y: 12.2), control1: CGPoint(x: 10.6, y: 14.6), control2: CGPoint(x: 7.4, y: 14.6))
            mouth.closeSubpath()
            layer.fill(mouth, with: ink)
        case .asleep:
            layer.fill(Path(ellipseIn: CGRect(x: 8.2, y: 12.1, width: 1.6, height: 1.3)), with: ink)
        case .sick:
            var mouth = Path()
            for i in 0 ... 12 {
                let t = CGFloat(i) / 12
                let p = CGPoint(x: 6.6 + 4.8 * t, y: 12.6 + 0.45 * sin(t * 2.5 * 2 * .pi))
                i == 0 ? mouth.move(to: p) : mouth.addLine(to: p)
            }
            layer.stroke(mouth, with: ink, style: StrokeStyle(lineWidth: 0.95, lineCap: .round, lineJoin: .round))
        default:
            // The wide axolotl smile: 60 % of the head.
            var mouth = Path()
            mouth.move(to: CGPoint(x: 5.3, y: 12.0))
            mouth.addCurve(to: CGPoint(x: 12.7, y: 12.0), control1: CGPoint(x: 7.4, y: 13.1), control2: CGPoint(x: 10.6, y: 13.1))
            layer.stroke(mouth, with: ink, style: line)
        }
        layer.blendMode = .normal
        if state == .due {
            // Due dot: a solid badge top-right with a cut ring separating it from the head.
            layer.blendMode = .destinationOut
            layer.fill(Path(ellipseIn: CGRect(x: 11.6, y: 0.4, width: 6.4, height: 6.4)), with: ink)
            layer.blendMode = .normal
            layer.fill(Path(ellipseIn: CGRect(x: 12.7, y: 1.5, width: 4.2, height: 4.2)), with: ink)
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
