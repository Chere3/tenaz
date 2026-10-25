import AppKit
import SwiftUI

/// Tena's head as a one-ink menu-bar glyph: a filled silhouette with gills, the face cut out of it.
/// Readable at 18 pt; `image(_:)` returns a template NSImage so the menu bar tints it.
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

    private func draw(in layer: inout GraphicsContext) {
        let ink = GraphicsContext.Shading.foreground
        // Gills: three short stalks each side.
        var gills = Path()
        // Roots sit on the upper flanks of the head and fan up and out like the real fronds.
        let fronds: [(root: CGPoint, angle: Double, length: Double)] = [
            (CGPoint(x: 5.2, y: 6.6), -62, 3.6), (CGPoint(x: 4.2, y: 8.6), -28, 3.4), (CGPoint(x: 4.0, y: 10.8), 6, 2.8),
        ]
        for side in [-1.0, 1.0] {
            for frond in fronds {
                let a = frond.angle * .pi / 180
                let root = CGPoint(x: 9 + side * (9 - frond.root.x), y: frond.root.y)
                gills.move(to: root)
                gills.addLine(to: CGPoint(x: root.x + side * frond.length * cos(a), y: root.y + frond.length * sin(a)))
            }
        }
        layer.stroke(gills, with: ink, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        layer.fill(Path(ellipseIn: CGRect(x: 3.3, y: 4.8, width: 11.4, height: 10.4)), with: ink)
        // Face, cut out of the silhouette.
        layer.blendMode = .destinationOut
        let face = StrokeStyle(lineWidth: 1.15, lineCap: .round)
        for x in [6.6, 11.4] {
            if state == .asleep {
                var lid = Path()
                lid.addArc(center: CGPoint(x: x, y: 9.0), radius: 1.3, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
                layer.stroke(lid, with: ink, style: face)
            } else {
                layer.fill(Path(ellipseIn: CGRect(x: x - 1.05, y: 8.3, width: 2.1, height: 2.2)), with: ink)
            }
        }
        switch state {
        case .hungry:
            layer.fill(Path(ellipseIn: CGRect(x: 7.85, y: 11.2, width: 2.3, height: 2.6)), with: ink)
        case .asleep:
            var mouth = Path()
            mouth.move(to: CGPoint(x: 8.1, y: 12.4))
            mouth.addLine(to: CGPoint(x: 9.9, y: 12.4))
            layer.stroke(mouth, with: ink, style: face)
        default:
            var mouth = Path()
            mouth.move(to: CGPoint(x: 7.3, y: 11.8))
            mouth.addQuadCurve(to: CGPoint(x: 10.7, y: 11.8), control: CGPoint(x: 9, y: 13.6))
            layer.stroke(mouth, with: ink, style: face)
        }
        if state == .sick {
            // A bandage strip across the forehead: a cut band with the head showing through its pad.
            var band = Path()
            band.move(to: CGPoint(x: 9.6, y: 4.2))
            band.addLine(to: CGPoint(x: 14.2, y: 7.6))
            layer.stroke(band, with: ink, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            layer.blendMode = .normal
            layer.fill(Path(ellipseIn: CGRect(x: 11.3, y: 5.3, width: 1.3, height: 1.3)), with: ink)
        }
        layer.blendMode = .normal
        if state == .due {
            // Due dot: a solid badge top-right with a cut ring separating it from the head.
            layer.blendMode = .destinationOut
            layer.fill(Path(ellipseIn: CGRect(x: 11.6, y: 0.6, width: 6.2, height: 6.2)), with: ink)
            layer.blendMode = .normal
            layer.fill(Path(ellipseIn: CGRect(x: 12.6, y: 1.6, width: 4.2, height: 4.2)), with: ink)
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
