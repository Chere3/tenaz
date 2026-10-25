import SwiftUI

/// Stage 0: an outlined jelly egg with the crown dots printed on the shell, and through a lighter
/// window the curled embryo (bead eyes, 3 + 3 nubs, the smile). No ring, no dashes, no frame.
/// Moods map to eye state plus egg motion only: a wobble for the bright moods, still for the rest.
extension TenaRig {
    static let wobblingMoods: Set<TenaMood> = [.ecstatic, .happy, .curious, .proud, .nagging]

    func eggFigure(pose: TenaPose, time t: Double) -> TenaFigure {
        let angle = Self.wobblingMoods.contains(mood) ? 4 * sin(2 * .pi * t / 1.8) * envelope(t) : 0
        let eggT = about(CGPoint(x: 100, y: 159), CGAffineTransform(rotationAngle: angle * .pi / 180))
        let center = CGPoint(x: 100, y: 104)
        let shellPoints = (0 ..< 60).map { i -> CGPoint in
            let a = Double(i) / 60 * 2 * .pi
            let s = CGFloat(sin(a))
            // Narrower toward the top (y up is negative sine).
            return CGPoint(x: center.x + 48 * CGFloat(cos(a)) * (1 + 0.07 * s), y: center.y + 55 * s)
        }
        let shell = Curve.closed(shellPoints)
        let window = Curve.ellipse(CGPoint(x: 100, y: 108), 35, 40)
        let crownDots = [(92.0, 60.0, 2.6), (100, 58, 3.0), (108, 60, 2.6)].map { x, y, r in
            Decor(path: Curve.ellipse(CGPoint(x: x, y: y), r, r), fill: .mark)
        }
        let gloss = Decor(path: Curve.ellipse(.zero, 7, 3.6)
            .applying(CGAffineTransform(rotationAngle: 0.75).concatenating(CGAffineTransform(translationX: 128, y: 70))), fill: .highlight)
        let shellGroup = TenaFigure.Group(parts: [
            moved(Part(path: shell, fill: .belly, decor: crownDots + [gloss]), eggT),
            moved(Part(path: window, fill: .window, contour: false), eggT),
        ])

        // The embryo, curled into a C around the bottom of the window, tail tip by its cheek.
        let head = HeadShape(center: CGPoint(x: 100, y: 96), size: CGSize(width: build.head.width * 0.86, height: build.head.height * 0.86))
        var spine = smoothed([
            CGPoint(x: 108, y: 104), CGPoint(x: 121, y: 114), CGPoint(x: 119, y: 130), CGPoint(x: 103, y: 138),
            CGPoint(x: 86, y: 133), CGPoint(x: 78, y: 121), CGPoint(x: 80, y: 110),
        ])
        spine = smoothed(spine)
        let body = Curve.ribbon(spine, halfWidth: { s in 8.5 * (1 - s) + 2 })
        let nubs = fronds(head: head, pose: pose, time: t, options: FrondOptions(lengthScale: 1.7)).parts
        var embryo = [Part(path: body, fill: .body)] + nubs
        embryo.append(Part(path: head.path, fill: .body, decor: [
            Decor(path: Curve.ellipse(CGPoint(x: 99, y: 124), 9, 6), fill: .belly),
        ]))
        let embryoGroup = TenaFigure.Group(parts: embryo.map { moved($0, eggT) }, clip: window.applying(eggT))

        var face = faceAnchors(head: head, pose: pose)
        face.eyeRadius = CGSize(width: face.eyeRadius.width * 0.6, height: face.eyeRadius.height * 0.6)
        face.mouthCenter.y = face.eyes[0].y + 0.24 * head.size.height
        face.nostrils = []
        var figure = TenaFigure()
        figure.groups = [shellGroup, embryoGroup]
        figure.face = face
        figure.headTransform = eggT
        return figure
    }

    /// The due word on Nagging's sign, set in the display face (never drawn as paths).
    func drawSignText(_ box: (center: CGPoint, size: CGSize, angle: Double), in context: GraphicsContext, weights w: Weights) {
        var ctx = context
        ctx.translateBy(x: box.center.x, y: box.center.y)
        ctx.rotate(by: .degrees(box.angle))
        if let word, !word.isEmpty {
            let text = Text(word).font(Typography.display(box.size.height * 0.52)).foregroundStyle(ink)
            var resolved = ctx.resolve(text)
            resolved.shading = .color(ink)
            let natural = resolved.measure(in: CGSize(width: 1000, height: 1000))
            let fit = min(1, box.size.width * 0.84 / max(natural.width, 1))
            ctx.scaleBy(x: fit, y: fit)
            ctx.draw(resolved, at: .zero)
        } else {
            var lines = Path()
            lines.move(to: CGPoint(x: -box.size.width * 0.3, y: -box.size.height * 0.12))
            lines.addLine(to: CGPoint(x: box.size.width * 0.3, y: -box.size.height * 0.12))
            lines.move(to: CGPoint(x: -box.size.width * 0.3, y: box.size.height * 0.16))
            lines.addLine(to: CGPoint(x: box.size.width * 0.12, y: box.size.height * 0.16))
            ctx.stroke(lines, with: .color(ink), style: StrokeStyle(lineWidth: w.t1, lineCap: .round))
        }
    }
}
