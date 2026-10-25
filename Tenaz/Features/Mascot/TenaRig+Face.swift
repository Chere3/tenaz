import SwiftUI

/// Eyes, brows, blush and mouth.
extension TenaRig {
    var eyeRadius: CGFloat { 6.6 * build.eyeSize }
    var eyeY: CGFloat { headCenter.y - (build.landForm ? 18 : 12) }
    var eyeX: CGFloat { 27 * build.headWidth + (build.eyeSize - 1) * 4 }

    /// Blinks for 0.14 s every 4.6 s; never at time 0, so stills and snapshots have open eyes.
    var isBlinking: Bool {
        guard time > 0 else { return false }
        return time.truncatingRemainder(dividingBy: 4.6) > 4.46
    }

    func drawFace(in context: GraphicsContext, lineWidth lw: CGFloat) {
        let ink = Tokens.tenaOutline
        let fine = StrokeStyle(lineWidth: max(lw * 0.85, 2.2), lineCap: .round, lineJoin: .round)
        if pose.blush { drawBlush(in: context) }
        var eyes = pose.eyes
        if isBlinking, [.open, .sparkle, .focused].contains(eyes) { eyes = .sleepy }
        for side in [-1.0, 1.0] {
            let center = CGPoint(x: CGFloat(side) * eyeX, y: eyeY)
            if build.landForm {
                // Land form: eyes sit in raised sockets.
                let socket = ellipse(CGPoint(x: center.x, y: center.y - 2), eyeRadius * 1.6, eyeRadius * 1.5)
                plate(socket, in: context, fill: bodyInk, lineWidth: lw * 0.8)
            }
            drawEye(eyes, at: center, side: side, in: context, ink: ink, style: fine)
            drawBrow(side: side, eye: center, in: context, ink: ink, style: fine)
        }
        drawMouth(in: context, ink: ink, style: fine)
    }

    func drawBlush(in context: GraphicsContext) {
        for side in [-1.0, 1.0] {
            let center = CGPoint(x: CGFloat(side) * (eyeX + 13), y: eyeY + 13)
            let rx: CGFloat = 10
            let ry: CGFloat = 6
            context.fill(Path(ellipseIn: CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2)), with: .color(Tokens.tenaGill.opacity(0.45)))
        }
    }

    func drawEye(_ eyes: TenaEyes, at c: CGPoint, side: Double, in context: GraphicsContext, ink: Color, style: StrokeStyle) {
        let r = eyeRadius
        switch eyes {
        case .open, .sparkle:
            let radius = eyes == .sparkle ? r * 1.15 : r
            context.fill(ellipse(c, radius, radius * 1.06), with: .color(ink))
            if eyes == .sparkle {
                context.fill(star(CGPoint(x: c.x - radius * 0.32, y: c.y - radius * 0.34), radius * 0.62), with: .color(TenaRig.highlight))
            } else {
                context.fill(ellipse(CGPoint(x: c.x - r * 0.32, y: c.y - r * 0.36), r * 0.36, r * 0.36), with: .color(TenaRig.highlight))
            }
            context.fill(ellipse(CGPoint(x: c.x + radius * 0.34, y: c.y + radius * 0.34), radius * 0.15, radius * 0.15), with: .color(TenaRig.highlight))
        case .focused:
            var lid = context
            lid.clip(to: Path(CGRect(x: c.x - r * 2, y: c.y - r * 0.45, width: r * 4, height: r * 3)))
            lid.fill(ellipse(c, r * 1.05, r), with: .color(ink))
            context.fill(ellipse(CGPoint(x: c.x - r * 0.3, y: c.y), r * 0.26, r * 0.26), with: .color(TenaRig.highlight))
            var line = Path()
            line.move(to: CGPoint(x: c.x - r * 1.25, y: c.y - r * 0.45))
            line.addLine(to: CGPoint(x: c.x + r * 1.25, y: c.y - r * 0.45))
            context.stroke(line, with: .color(ink), style: style)
        case .happy:
            var arc = Path()
            arc.addArc(center: CGPoint(x: c.x, y: c.y + r * 0.45), radius: r * 0.95, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
            context.stroke(arc, with: .color(ink), style: StrokeStyle(lineWidth: style.lineWidth * 1.25, lineCap: .round))
        case .sleepy:
            var arc = Path()
            arc.addArc(center: CGPoint(x: c.x, y: c.y - r * 0.5), radius: r * 0.95, startAngle: .degrees(25), endAngle: .degrees(155), clockwise: false)
            context.stroke(arc, with: .color(ink), style: StrokeStyle(lineWidth: style.lineWidth * 1.2, lineCap: .round))
        case .droopy:
            var lower = context
            lower.clip(to: Path(CGRect(x: c.x - r * 2, y: c.y - r * 0.1, width: r * 4, height: r * 3)))
            lower.fill(ellipse(c, r, r), with: .color(ink))
            context.fill(ellipse(CGPoint(x: c.x - r * 0.3, y: c.y + r * 0.3), r * 0.24, r * 0.24), with: .color(TenaRig.highlight))
            var lid = Path()
            lid.move(to: CGPoint(x: c.x - r * 1.2, y: c.y - r * (side < 0 ? -0.05 : 0.35)))
            lid.addLine(to: CGPoint(x: c.x + r * 1.2, y: c.y - r * (side < 0 ? 0.35 : -0.05)))
            context.stroke(lid, with: .color(ink), style: style)
        case .swirl:
            var spiral = Path()
            let turns = 2.2
            let steps = 40
            for i in 0 ... steps {
                let t = Double(i) / Double(steps)
                let angle = t * turns * 2 * .pi * (side < 0 ? 1 : -1)
                let radius = r * 1.05 * CGFloat(t)
                let p = CGPoint(x: c.x + radius * CGFloat(cos(angle)), y: c.y + radius * CGFloat(sin(angle)))
                i == 0 ? spiral.move(to: p) : spiral.addLine(to: p)
            }
            context.stroke(spiral, with: .color(ink), style: StrokeStyle(lineWidth: style.lineWidth * 0.85, lineCap: .round))
        }
    }

    func drawBrow(side: Double, eye: CGPoint, in context: GraphicsContext, ink: Color, style: StrokeStyle) {
        // Angles are for the left brow, degrees; positive = inner end (towards the nose) higher.
        let spec: (lift: CGFloat, angle: Double)? = switch pose.brows {
        case .none: nil
        case .raised: (5, -8)
        case .worried: (2, 22)
        case .angry: (-1, -26)
        case .focused: (-3, -12)
        case .quizzical: side < 0 ? (8, -10) : (0, 4)
        }
        guard let spec else { return }
        let center = CGPoint(x: eye.x, y: eye.y - eyeRadius * 1.9 - spec.lift)
        let half: CGFloat = 6.5
        let a = spec.angle * .pi / 180
        // Inner end is towards x = 0.
        let inner = CGPoint(x: center.x - CGFloat(side) * half * CGFloat(cos(a)), y: center.y - half * CGFloat(sin(a)))
        let outer = CGPoint(x: center.x + CGFloat(side) * half * CGFloat(cos(a)), y: center.y + half * CGFloat(sin(a)))
        var brow = Path()
        brow.move(to: outer)
        brow.addLine(to: inner)
        context.stroke(brow, with: .color(ink), style: StrokeStyle(lineWidth: style.lineWidth * 1.1, lineCap: .round))
    }

    func drawMouth(in context: GraphicsContext, ink: Color, style: StrokeStyle) {
        let y = eyeY + 16
        var path = Path()
        switch pose.mouth {
        case .smile:
            path.move(to: CGPoint(x: -15, y: y - 1))
            path.addQuadCurve(to: CGPoint(x: 0, y: y + 3), control: CGPoint(x: -8, y: y + 8))
            path.addQuadCurve(to: CGPoint(x: 15, y: y - 1), control: CGPoint(x: 8, y: y + 8))
            context.stroke(path, with: .color(ink), style: style)
        case .grin:
            path.move(to: CGPoint(x: -15, y: y - 2))
            path.addQuadCurve(to: CGPoint(x: 15, y: y - 2), control: CGPoint(x: 0, y: y - 4))
            path.addQuadCurve(to: CGPoint(x: -15, y: y - 2), control: CGPoint(x: 0, y: y + 22))
            path.closeSubpath()
            context.fill(path, with: .color(ink))
            var tongue = context
            tongue.clip(to: path)
            tongue.fill(ellipse(CGPoint(x: 2, y: y + 11), 8, 5), with: .color(Tokens.tenaShade))
        case .flat:
            path.move(to: CGPoint(x: -8, y: y + 2))
            path.addLine(to: CGPoint(x: 8, y: y + 2))
            context.stroke(path, with: .color(ink), style: style)
        case .frown:
            path.move(to: CGPoint(x: -11, y: y + 7))
            path.addQuadCurve(to: CGPoint(x: 11, y: y + 7), control: CGPoint(x: 0, y: y - 2))
            context.stroke(path, with: .color(ink), style: style)
        case .open:
            let mouth = ellipse(CGPoint(x: 0, y: y + 5), 6.5, 7.5)
            context.fill(mouth, with: .color(ink))
            var tongue = context
            tongue.clip(to: mouth)
            tongue.fill(ellipse(CGPoint(x: 0, y: y + 11), 5, 3.5), with: .color(Tokens.tenaShade))
        case .wobble:
            let steps = 24
            for i in 0 ... steps {
                let t = CGFloat(i) / CGFloat(steps)
                let p = CGPoint(x: -13 + 26 * t, y: y + 4 + 2.4 * CGFloat(sin(Double(t) * 3 * 2 * .pi)))
                i == 0 ? path.move(to: p) : path.addLine(to: p)
            }
            context.stroke(path, with: .color(ink), style: style)
        }
    }

    /// Four-point sparkle.
    func star(_ c: CGPoint, _ r: CGFloat) -> Path {
        var p = Path()
        let inner = r * 0.32
        for i in 0 ..< 8 {
            let angle = Double(i) * .pi / 4 - .pi / 2
            let radius = i.isMultiple(of: 2) ? r : inner
            let point = CGPoint(x: c.x + radius * CGFloat(cos(angle)), y: c.y + radius * CGFloat(sin(angle)))
            i == 0 ? p.move(to: point) : p.addLine(to: point)
        }
        p.closeSubpath()
        return p
    }
}
