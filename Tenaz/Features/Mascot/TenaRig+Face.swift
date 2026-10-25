import SwiftUI

/// The face (rules §8): bead eyes that never change shape, acting only through skin-coloured lids
/// with a tier-1 lid line; the wide axolotl smile as one 6-point path; nostril dots.
extension TenaRig {
    func drawFace(_ face: TenaFigure.Face, in ctx: GraphicsContext, weights w: Weights) {
        let pose = livePose
        let shut = pose.eye.closed == nil ? blink(time) : 0
        let drift = gazeDrift(time)
        for (i, center) in face.eyes.enumerated() {
            let side: CGFloat = i == 0 ? -1 : 1
            let state = side > 0 ? (pose.rightEye ?? pose.eye) : pose.eye
            drawEye(state, at: center, side: side, radius: face.eyeRadius, shut: shut, drift: drift, in: ctx, weights: w)
        }
        if showsDetail {
            let r = max(w.t2 * 0.9, 0.9)
            for n in face.nostrils { ctx.fill(Curve.ellipse(n, r, r), with: .color(ink)) }
        }
        drawMouth(pose.mouth, face: face, in: ctx, weights: w)
    }

    var faceStroke: CGFloat { lod == .small ? 1.25 : (lod == .glyph ? 1.4 : 1) }

    func drawEye(_ e: TenaPose.EyeState, at c: CGPoint, side: CGFloat, radius: CGSize, shut: Double, drift: CGVector,
                 in ctx: GraphicsContext, weights w: Weights) {
        let s = radius.width / 6.5
        if let closed = e.closed {
            var arc = Path()
            switch closed {
            case .up:
                arc.move(to: CGPoint(x: c.x - 8 * s, y: c.y + 2.5 * s))
                arc.addQuadCurve(to: CGPoint(x: c.x + 8 * s, y: c.y + 2.5 * s), control: CGPoint(x: c.x, y: c.y - 8 * s))
                ctx.stroke(arc, with: .color(ink), style: StrokeStyle(lineWidth: w.t1 * 1.3 * faceStroke, lineCap: .round))
            case .down:
                arc.move(to: CGPoint(x: c.x - 7 * s, y: c.y))
                arc.addQuadCurve(to: CGPoint(x: c.x + 7 * s, y: c.y), control: CGPoint(x: c.x, y: c.y + 6.5 * s))
                ctx.stroke(arc, with: .color(ink), style: StrokeStyle(lineWidth: w.t1 * 1.1 * faceStroke, lineCap: .round))
            }
            return
        }
        let scale = CGFloat(min(1.1, max(0.9, e.pupilScale)))
        let rx = radius.width * scale, ry = radius.height * scale
        let gaze = CGVector(dx: e.gaze.dx + drift.dx, dy: e.gaze.dy + drift.dy)
        let bead = CGPoint(x: c.x + CGFloat(gaze.dx) * rx * 1.6, y: c.y + CGFloat(gaze.dy) * ry * 1.6)
        let beadPath = Curve.ellipse(bead, rx, ry)

        // Upper lid: cuts the top of the bead, its edge angled (+ = inner corner down). The lids mask
        // the bead (inverse clip) rather than painting skin over it, so no seam rings the eye.
        let lid = CGFloat(e.lid + (1 - e.lid) * shut)
        let slope = CGFloat(tan(e.lidAngle * .pi / 180)) * -side
        let edgeBase = c.y - ry + 2 * ry * lid
        func edge(_ x: CGFloat) -> CGFloat { edgeBase + slope * (x - c.x) }
        // Lower lid push: a crescent from below, so the bead reads as a half-moon. At Standard and Hero a
        // full push (Happy) becomes a true smiling crescent: a deeper, rounder arch and no gloss, because a
        // half-moon bead with a catchlight reads as a glance up and sideways at that size.
        let crescent = showsDetail && e.lowerLid >= 0.45 && e.lid < 0.2
        let lower = CGFloat(crescent ? 0.72 : e.lowerLid)
        let lowerTop = c.y + ry - 2 * ry * lower
        var mask = Path()
        if lid > 0.02 {
            mask.move(to: CGPoint(x: c.x - 3 * rx, y: edge(c.x - 3 * rx)))
            mask.addLine(to: CGPoint(x: c.x + 3 * rx, y: edge(c.x + 3 * rx)))
            mask.addLine(to: CGPoint(x: c.x + 3 * rx, y: c.y - 4 * ry))
            mask.addLine(to: CGPoint(x: c.x - 3 * rx, y: c.y - 4 * ry))
            mask.closeSubpath()
        }
        if lower > 0.02 {
            // A narrow arch from below: the centre is cut up to `lowerTop` while the outer corners stay,
            // so the bead's lower edge bows up (the smiling eye), not a flat chop.
            let arch: (CGFloat, CGFloat) = crescent ? (1.12, 1.05) : (1.08, 1.6)
            mask = mask.union(Curve.ellipse(CGPoint(x: c.x, y: lowerTop + ry * arch.1), rx * arch.0, ry * arch.1))
        }
        var lids = ctx
        if !mask.isEmpty { lids.clip(to: mask, options: .inverse) }
        lids.fill(beadPath, with: .color(ink))
        lids.clip(to: beadPath)
        // Gloss at the upper right (fixed light), kept inside what the lids leave open.
        let open = max(0, min(lowerTop, c.y + ry) - max(edge(bead.x + rx * 0.46), c.y - ry))
        var gloss = 3.2 * s * scale * (e.pupilScale < 0.8 ? 0.55 : 1)
        gloss = min(gloss, open * 0.42)
        if gloss > 0.7, shut < 0.5, !crescent {
            let gx = bead.x + rx * 0.46
            var gy = bead.y - ry * 0.57
            gy = max(gy, edge(gx) + gloss + 0.5)
            gy = min(gy, lowerTop - gloss - 0.3)
            lids.fill(Curve.ellipse(CGPoint(x: gx, y: gy), gloss, gloss), with: .color(color(.highlight)))
            if e.wet {
                let r2 = gloss * 0.45
                lids.fill(Curve.ellipse(CGPoint(x: bead.x + rx * 0.05, y: min(gy + gloss * 1.6, lowerTop - r2 - 0.3)), r2, r2), with: .color(color(.highlight)))
            }
        }
        // The lid line carries the brow work (thicker in the bust, where it is the only brow cue).
        if lid >= 0.18 {
            var line = Path()
            let half = rx * (lod == .glyph ? 1.3 : 1.22)
            line.move(to: CGPoint(x: c.x - half, y: edge(c.x - half)))
            line.addLine(to: CGPoint(x: c.x + half, y: edge(c.x + half)))
            let weight = w.t1 * faceStroke * (lod == .glyph ? 1.25 : 1)
            ctx.stroke(line, with: .color(ink), style: StrokeStyle(lineWidth: weight, lineCap: .round))
        }
    }

    /// The mouth as one 6-point path: upper lip (corner, 2 controls, corner) and lower lip back.
    func mouthPath(_ m: TenaPose.MouthShape, face: TenaFigure.Face) -> (upper: Path, closed: Path?, drop: CGFloat, corners: (CGPoint, CGPoint)) {
        let w = face.mouthWidth
        let c = face.mouthCenter
        let lift = 13 * CGFloat(m.curve) * sqrt(w / 74)
        let left = CGPoint(x: c.x - w / 2, y: c.y - lift + CGFloat(m.skew) * 2)
        let right = CGPoint(x: c.x + w / 2, y: c.y - lift - CGFloat(m.skew) * 6)
        let depth = CGFloat(m.open) * min(face.mouthHeightLimit, w * 0.85)
        let arch = CGFloat(m.round) * depth * 0.5
        let drop = depth - arch
        let upY = c.y + (-8 * arch + 2 * lift) / 6
        let lowY = c.y + (8 * drop + 2 * lift) / 6
        // Round mouths move the controls out over the corners so an "o" has round ends, not points.
        let upSpread = 0.22 + 0.28 * CGFloat(m.round)
        let spread = 0.22 + 0.24 * CGFloat(m.square) + 0.28 * CGFloat(m.round)
        let u1 = CGPoint(x: c.x - upSpread * w, y: upY), u2 = CGPoint(x: c.x + upSpread * w, y: upY)
        let l1 = CGPoint(x: c.x + spread * w, y: lowY), l2 = CGPoint(x: c.x - spread * w, y: lowY)
        var upper = Path()
        if m.wave > 0 {
            let steps = 28
            for i in 0 ... steps {
                let t = CGFloat(i) / CGFloat(steps)
                let p = Curve.cubic(left, u1, u2, right, t) + CGPoint(x: 0, y: CGFloat(m.wave) * 2.2 * sin(t * 2.5 * 2 * .pi))
                i == 0 ? upper.move(to: p) : upper.addLine(to: p)
            }
        } else {
            upper.move(to: left)
            upper.addCurve(to: right, control1: u1, control2: u2)
        }
        guard depth > 1 else { return (upper, nil, 0, (left, right)) }
        var closed = Path()
        closed.move(to: left)
        closed.addCurve(to: right, control1: u1, control2: u2)
        closed.addCurve(to: left, control1: l1, control2: l2)
        closed.closeSubpath()
        return (upper, closed, drop, (left, right))
    }

    func drawMouth(_ m: TenaPose.MouthShape, face: TenaFigure.Face, in ctx: GraphicsContext, weights w: Weights) {
        let (upper, closed, drop, corners) = mouthPath(m, face: face)
        let style = StrokeStyle(lineWidth: w.t1 * faceStroke, lineCap: .round, lineJoin: .round)
        if let closed {
            var inside = ctx
            inside.clip(to: closed)
            inside.fill(closed, with: .color(RGB(0x7A1F35).mix(wash, livePose.fade).color))
            if m.tongue {
                let c = face.mouthCenter
                inside.fill(Curve.ellipse(CGPoint(x: c.x + 0.06 * face.mouthWidth, y: c.y + drop * 0.95), 0.23 * face.mouthWidth, drop * 0.5),
                            with: .color(RGB(0xF06A86).mix(wash, livePose.fade).color))
            }
            ctx.stroke(closed, with: .color(ink), style: style)
        } else {
            ctx.stroke(upper, with: .color(ink), style: style)
            // Corner ticks on a smile (tier 2, Standard and Hero only).
            if showsDetail, m.curve > 0.2, m.wave == 0, face.mouthWidth > 50 {
                var ticks = Path()
                for (corner, side) in [(corners.0, CGFloat(-1)), (corners.1, CGFloat(1))] {
                    ticks.move(to: CGPoint(x: corner.x - side * 1.2, y: corner.y - 2.6))
                    ticks.addLine(to: CGPoint(x: corner.x + side * 1.4, y: corner.y + 1.8))
                }
                ctx.stroke(ticks, with: .color(ink), style: StrokeStyle(lineWidth: w.t2, lineCap: .round))
            }
        }
    }
}
