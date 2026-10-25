import SwiftUI

/// Mood props: sparkles, question mark, drool, growl, alarm, tear, bandage, regrowth, medal, Zzz, headband.
extension TenaRig {
    var twinkle: Double { 0.5 + 0.5 * sin(2 * .pi * time / 1.3) }

    func drawHeadExtras(in context: GraphicsContext, lineWidth lw: CGFloat) {
        let ink = Tokens.tenaOutline
        for extra in pose.extras {
            switch extra {
            case .headband:
                var band = Path()
                band.move(to: CGPoint(x: -headRX * 0.9, y: headCenter.y - headRY * 0.45))
                band.addQuadCurve(to: CGPoint(x: headRX * 0.9, y: headCenter.y - headRY * 0.45), control: CGPoint(x: 0, y: headCenter.y - headRY * 0.98))
                let shape = band.strokedPath(StrokeStyle(lineWidth: 9, lineCap: .butt))
                var clipped = context
                clipped.clip(to: headPath)
                clipped.fill(shape.offsetBy(dx: Self.orangePlate.width, dy: Self.orangePlate.height), with: .color(Tokens.accent))
                clipped.stroke(shape, with: .color(ink), lineWidth: lw * 0.7)
                // Knot and tails on the right.
                let knot = CGPoint(x: headRX * 0.86, y: headCenter.y - headRY * 0.5)
                var tails = Path()
                tails.move(to: knot)
                tails.addQuadCurve(to: CGPoint(x: knot.x + 20, y: knot.y - 8 - 3 * twinkle), control: CGPoint(x: knot.x + 10, y: knot.y - 12))
                tails.move(to: knot)
                tails.addQuadCurve(to: CGPoint(x: knot.x + 18, y: knot.y + 10), control: CGPoint(x: knot.x + 12, y: knot.y + 2))
                let tailShape = tails.strokedPath(StrokeStyle(lineWidth: 6, lineCap: .round))
                plate(tailShape.union(ellipse(knot, 5, 5)), in: context, fill: Tokens.accent, offset: Self.orangePlate, lineWidth: lw * 0.7)
            case .bandage:
                let center = CGPoint(x: headRX * 0.42, y: headCenter.y - headRY * 0.62)
                for angle in [32.0, -32.0] {
                    var strip = context
                    strip.translateBy(x: center.x, y: center.y)
                    strip.rotate(by: .degrees(angle))
                    let rect = CGRect(x: -17, y: -5.5, width: 34, height: 11)
                    let shape = Path(roundedRect: rect, cornerRadius: 4)
                    strip.fill(shape, with: .color(TenaRig.highlight))
                    strip.stroke(shape, with: .color(ink), lineWidth: lw * 0.75)
                    var pad = Path()
                    for i in -1 ... 1 {
                        pad.addEllipse(in: CGRect(x: CGFloat(i) * 4 - 1, y: -1, width: 2, height: 2))
                    }
                    strip.fill(pad, with: .color(ink.opacity(0.7)))
                }
            case .tear:
                let start = CGPoint(x: -eyeX - 3, y: eyeY + eyeRadius + 3 + CGFloat(4 * twinkle))
                plate(drop(at: start, size: 7), in: context, fill: Tokens.brand.opacity(0.85), offset: .zero, lineWidth: lw * 0.6)
            case .drool:
                plate(drop(at: CGPoint(x: 7, y: eyeY + 28 + CGFloat(2 * twinkle)), size: 5.5), in: context, fill: TenaRig.highlight, offset: .zero, lineWidth: lw * 0.6)
            default:
                break
            }
        }
    }

    func drawFloatingExtras(in context: GraphicsContext, lineWidth lw: CGFloat) {
        let ink = Tokens.tenaOutline
        for extra in pose.extras {
            switch extra {
            case .sparkles:
                let spots: [(CGFloat, CGFloat, CGFloat, Double)] = [(-86, -56, 11, 0), (82, -62, 9, 0.5), (-80, 34, 7, 0.25), (88, 22, 10, 0.75)]
                for (x, y, r, phase) in spots {
                    let pulse = 0.75 + 0.25 * sin(2 * .pi * (time / 1.1 + phase))
                    plate(star(CGPoint(x: x, y: y), r * CGFloat(pulse)), in: context, fill: Tokens.gold, offset: Self.orangePlate, lineWidth: lw * 0.6)
                }
            case .question:
                drawGlyph("?", at: CGPoint(x: 78, y: -66 - CGFloat(3 * twinkle)), size: 40, fill: Tokens.brand, in: context, lineWidth: lw)
            case .alarm:
                let c = CGPoint(x: 76, y: -64)
                var bubble = context
                bubble.translateBy(x: c.x, y: c.y)
                bubble.rotate(by: .degrees(8 * sin(2 * .pi * time * 1.6)))
                plate(ellipse(.zero, 17, 17), in: bubble, fill: Tokens.accent, offset: Self.orangePlate, lineWidth: lw * 0.8)
                bubble.draw(Text("!").font(Typography.display(26)).foregroundStyle(Tokens.ink), at: CGPoint(x: 0, y: 0))
            case .growl:
                var lines = Path()
                for i in 0 ..< 3 {
                    let r = CGFloat(7 + i * 5)
                    lines.addArc(center: CGPoint(x: bodyRX * 0.7, y: bodyCenter.y + 4), radius: r, startAngle: .degrees(-40), endAngle: .degrees(40), clockwise: false)
                }
                context.stroke(lines.offsetBy(dx: 18, dy: 0), with: .color(ink.opacity(0.7 + 0.3 * twinkle)), style: StrokeStyle(lineWidth: lw * 0.6, lineCap: .round))
            case .regrowth:
                for (i, p) in [CGPoint(x: bodyRX + 22, y: bodyCenter.y - 6), CGPoint(x: bodyRX + 34, y: bodyCenter.y + 14), CGPoint(x: bodyRX + 10, y: bodyCenter.y - 26)].enumerated() {
                    let r: CGFloat = i == 0 ? 7 : 5
                    let bob = CGFloat(3 * sin(2 * .pi * (time / 1.6 + Double(i) * 0.3)))
                    plate(plus(CGPoint(x: p.x, y: p.y + bob), r), in: context, fill: Tokens.correct, offset: .zero, lineWidth: lw * 0.5)
                }
            case .sleepZ:
                let rise = CGFloat((time / 2.4).truncatingRemainder(dividingBy: 1) * 6)
                for (i, size) in [16.0, 22.0, 28.0].enumerated() {
                    let p = CGPoint(x: 52 + CGFloat(i) * 16, y: -50 - CGFloat(i) * 20 - rise)
                    drawGlyph("z", at: p, size: size, fill: Tokens.brand, in: context, lineWidth: lw)
                }
            default:
                break
            }
        }
    }

    func drawMedal(in context: GraphicsContext, lineWidth lw: CGFloat) {
        let c = CGPoint(x: 0, y: bodyCenter.y + bodyRY * 0.3)
        var ribbon = Path()
        ribbon.move(to: CGPoint(x: -10, y: c.y - 22))
        ribbon.addLine(to: CGPoint(x: 0, y: c.y - 4))
        ribbon.addLine(to: CGPoint(x: 10, y: c.y - 22))
        plate(ribbon.strokedPath(StrokeStyle(lineWidth: 6, lineJoin: .round)), in: context, fill: Tokens.accent, offset: Self.orangePlate, lineWidth: lw * 0.6)
        plate(ellipse(c, 11, 11), in: context, fill: Tokens.gold, offset: Self.orangePlate, lineWidth: lw * 0.75)
        context.fill(star(c, 6.5), with: .color(Tokens.tenaOutline))
    }

    /// A drop with a pointed top.
    func drop(at top: CGPoint, size s: CGFloat) -> Path {
        var p = Path()
        p.move(to: top)
        p.addCurve(to: CGPoint(x: top.x, y: top.y + s * 2), control1: CGPoint(x: top.x + s * 1.1, y: top.y + s), control2: CGPoint(x: top.x + s, y: top.y + s * 2))
        p.addCurve(to: top, control1: CGPoint(x: top.x - s, y: top.y + s * 2), control2: CGPoint(x: top.x - s * 1.1, y: top.y + s))
        p.closeSubpath()
        return p
    }

    func plus(_ c: CGPoint, _ r: CGFloat) -> Path {
        let w = r * 0.42
        var p = Path(CGRect(x: c.x - w, y: c.y - r, width: w * 2, height: r * 2))
        p = p.union(Path(CGRect(x: c.x - r, y: c.y - w, width: r * 2, height: w * 2)))
        return p
    }

    /// Display-font glyph ("?", "!") in one flat ink.
    func drawGlyph(_ glyph: String, at p: CGPoint, size: CGFloat, fill: Color, in context: GraphicsContext, lineWidth _: CGFloat) {
        context.draw(Text(glyph).font(Typography.display(size)).foregroundStyle(fill), at: p)
    }
}
