import SwiftUI

/// Stage 0: a jelly-coated egg with Tena curled inside; the eyes still show the mood.
extension TenaRig {
    func drawEgg(in context: GraphicsContext) {
        let lw = outlinePoints / (size / 200)
        var egg = context
        egg.translateBy(x: 0, y: 70)
        egg.rotate(by: .degrees(4 * sin(2 * .pi * time / 3.4 * pose.breathRate)))
        egg.translateBy(x: 0, y: -70)
        let center = CGPoint(x: 0, y: 8)
        // The shell stays cream on Night paper so the egg never reads as a dark disc.
        let shellInk = dark ? Self.highlight : Tokens.paper
        // Jelly coat: a dashed outer ring with a flat tint.
        let jelly = ellipse(center, 72, 68)
        // Big (hero) eggs are one flat shape: no dashed ring or tint, so she is not a framed badge.
        if size <= 300 {
            egg.fill(jelly, with: .color(Tokens.tenaPink.opacity(0.18)))
            egg.stroke(jelly, with: .color(Tokens.tenaOutline.opacity(0.7)), style: StrokeStyle(lineWidth: lw * 0.6, dash: [5, 5]))
        }
        // Shell.
        let shell = ellipse(center, 50, 52)
        egg.fill(shell.offsetBy(dx: Self.pinkPlate.width, dy: Self.pinkPlate.height), with: .color(shellInk))
        var shade = egg
        shade.clip(to: shell)
        shade.fill(ellipse(CGPoint(x: 22, y: 34), 46, 36), with: .color(Tokens.tenaShade.opacity(0.4)))
        // Curled embryo: head, tucked tail, gill nubs.
        let headC = CGPoint(x: -6, y: 4)
        var tail = Path()
        tail.move(to: CGPoint(x: 10, y: 14))
        tail.addQuadCurve(to: CGPoint(x: -18, y: 34), control: CGPoint(x: 24, y: 40))
        let tailShape = tail.strokedPath(StrokeStyle(lineWidth: 11, lineCap: .round))
        shade.fill(tailShape.offsetBy(dx: 1.5, dy: 1.2), with: .color(Tokens.tenaPink))
        shade.stroke(tailShape, with: .color(Tokens.tenaOutline), lineWidth: lw * 0.7)
        for side in [-1.0, 1.0] {
            for i in 0 ..< 3 {
                let a = (Double(i) - 1) * 0.5 + (side < 0 ? .pi : 0)
                let nub = ellipse(CGPoint(x: headC.x + CGFloat(side) * 22 + 6 * CGFloat(cos(a)), y: headC.y - 8 + CGFloat(i) * 7), 4, 3.2)
                shade.fill(nub.offsetBy(dx: Self.orangePlate.width, dy: Self.orangePlate.height), with: .color(Tokens.tenaGill))
                shade.stroke(nub, with: .color(Tokens.tenaOutline), lineWidth: lw * 0.55)
            }
        }
        let head = ellipse(headC, 22, 18)
        shade.fill(head.offsetBy(dx: 1.5, dy: 1.2), with: .color(Tokens.tenaPink))
        shade.stroke(head, with: .color(Tokens.tenaOutline), lineWidth: lw * 0.7)
        let closed = [.sleepy, .happy].contains(pose.eyes) || isBlinking
        for side in [-1.0, 1.0] {
            let eye = CGPoint(x: headC.x + CGFloat(side) * 9, y: headC.y - 1)
            if closed {
                var arc = Path()
                arc.addArc(center: CGPoint(x: eye.x, y: eye.y - 2), radius: 3.2, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
                shade.stroke(arc, with: .color(Tokens.tenaOutline), style: StrokeStyle(lineWidth: lw * 0.6, lineCap: .round))
            } else {
                shade.fill(ellipse(eye, 3.2, 3.4), with: .color(Tokens.tenaOutline))
                shade.fill(ellipse(CGPoint(x: eye.x - 1, y: eye.y - 1.2), 1.1, 1.1), with: .color(Tokens.paper))
            }
        }
        egg.stroke(shell, with: .color(Tokens.tenaOutline), lineWidth: lw)
        // Shine.
        var shine = Path()
        shine.addArc(center: center, radius: 40, startAngle: .degrees(200), endAngle: .degrees(240), clockwise: false)
        egg.stroke(shine, with: .color(shellInk), style: StrokeStyle(lineWidth: lw * 1.2, lineCap: .round))
        if pose.extras.contains(.sleepZ) {
            drawFloatingExtras(in: context, lineWidth: lw)
        }
    }
}
