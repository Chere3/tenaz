import SwiftUI

/// Draws Tena into a Canvas: flat pink body, deep-orange gills and an ink outline,
/// with one flat shade shape, an ink outline, and a face that carries the mood.
/// Geometry lives in a 200 x 200 unit box centred on the head/body cluster; `time` drives the idle loop.
struct TenaRig {
    let mood: TenaMood
    let stage: TenaStage
    /// Seconds; 0 = the resting pose.
    let time: Double
    /// Rendered side in points (sets the outline weight).
    let size: CGFloat
    /// Night paper: the sick fade lifts to a desaturated pink instead of a brown multiply.
    var dark = false
    /// Draw the soft floor shadow (off for the app icon layer).
    var ground = true

    var pose: TenaPose { TenaPose.for(mood) }
    var build: TenaBuild { TenaBuild.for(stage) }

    /// Outline weight in points: 3 pt at ~170 pt, never thinner than 1.5 pt.
    var outlinePoints: CGFloat { min(3.6, max(1.5, size * 0.018)) }
    /// Pink plate offset vs the outline plate (units).
    static let pinkPlate = CGSize.zero
    /// Orange plate offset (units).
    static let orangePlate = CGSize.zero
    /// Eye shines and tears: always light, so Tena's eyes keep their sparkle on Night and dark floods.
    static let highlight = Color(red: 1, green: 0.969, blue: 0.933)

    var breath: Double { sin(2 * .pi * time / 2.8 * pose.breathRate) }

    func draw(in context: inout GraphicsContext) {
        let unit = size / 200
        context.scaleBy(x: unit, y: unit)
        context.translateBy(x: 100, y: 104)
        if ground { drawGroundShadow(in: context) }
        if stage == .egg {
            drawEgg(in: context)
            return
        }
        var ctx = context
        ctx.scaleBy(x: build.scale, y: build.scale)
        ctx.translateBy(x: 0, y: (1 - build.scale) * 40 - 3 * pose.bounce * max(0, breath))
        let lw = outlinePoints / (unit * build.scale)
        if build.golden { drawHalo(in: ctx) }
        drawTail(in: ctx, lineWidth: lw)
        if build.legs { drawLegs(in: ctx, lineWidth: lw) }
        drawBody(in: ctx, lineWidth: lw)
        if build.arms { drawArms(in: ctx, lineWidth: lw) }
        if pose.extras.contains(.medal) { drawMedal(in: ctx, lineWidth: lw) }
        var head = ctx
        head.translateBy(x: 0, y: 10)
        head.rotate(by: .degrees(pose.tilt + 1.5 * sin(2 * .pi * time / 5.2)))
        head.translateBy(x: 0, y: -10)
        drawGills(in: head, lineWidth: lw)
        drawHead(in: head, lineWidth: lw)
        drawFace(in: head, lineWidth: lw)
        drawHeadExtras(in: head, lineWidth: lw)
        drawFloatingExtras(in: ctx, lineWidth: lw)
    }

    // MARK: Plates

    var bodyInk: Color { build.golden ? Tokens.gold : (build.landForm ? Tokens.tenaShade : Tokens.tenaPink) }
    var shadeInk: Color { build.golden ? Tokens.accent : (build.landForm ? Tokens.tenaOutline : Tokens.tenaShade) }

    /// Fill on the (mis-registered) colour plate, then the outline on the indigo plate.
    func plate(_ path: Path, in context: GraphicsContext, fill: Color, offset: CGSize = TenaRig.pinkPlate, lineWidth: CGFloat) {
        context.fill(path.offsetBy(dx: offset.width, dy: offset.height), with: .color(fill))
        if pose.fade > 0 {
            context.fill(path.offsetBy(dx: offset.width, dy: offset.height), with: .color((dark ? Color(red: 0.93, green: 0.77, blue: 0.76) : Tokens.paper).opacity(pose.fade)))
        }
        context.stroke(path, with: .color(Tokens.tenaOutline), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }

    func ellipse(_ center: CGPoint, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2))
    }

    // MARK: Body parts

    var headRX: CGFloat { 60 * build.headWidth }
    var headRY: CGFloat { 44 * (1 + 0.012 * breath) }
    var headCenter: CGPoint { CGPoint(x: 0, y: -12) }
    var bodyCenter: CGPoint { CGPoint(x: 0, y: 36 + 6 * (build.bodySize - 1)) }
    var bodyRX: CGFloat { 37 * build.bodySize * (1 + 0.02 * breath) }
    var bodyRY: CGFloat { (build.landForm ? 34 : 30) * build.bodySize }

    func drawGroundShadow(in context: GraphicsContext) {
        let lift = stage == .egg ? 0 : 0.12 * max(0, breath) * pose.bounce
        let rx = (stage == .egg ? 54 : 60 * build.scale) * (1 - lift)
        let center = CGPoint(x: 0, y: stage == .egg ? 80 : 30 + 52 * build.scale)
        let shape = ellipse(center, rx, 7)
        context.fill(shape, with: .color(Tokens.tenaOutline.opacity(0.14)))
    }

    func drawHalo(in context: GraphicsContext) {
        let center = CGPoint(x: 0, y: -4)
        let ring = ellipse(center, 98, 88)
        let dots = Halftone.dots(in: ring.boundingRect, spacing: 6) { p in
            let d = hypot((p.x - center.x) / 98, (p.y - center.y) / 88)
            return d > 1 ? 0 : 0.85 * (1 - abs(d - 0.78) / 0.22)
        }
        context.fill(dots, with: .color(Tokens.gold))
    }

    func drawTail(in context: GraphicsContext, lineWidth lw: CGFloat) {
        let length = 56 * build.tailLength
        let sway = 7 * sin(2 * .pi * time / 3.1 * pose.breathRate)
        let base = CGPoint(x: bodyCenter.x + bodyRX * 0.55, y: bodyCenter.y + 2)
        let tip = CGPoint(x: base.x + length, y: base.y - 26 - sway)
        var tail = Path()
        if build.landForm {
            tail.move(to: CGPoint(x: base.x - 6, y: base.y - 8))
            tail.addQuadCurve(to: tip, control: CGPoint(x: base.x + length * 0.5, y: base.y - 2))
            tail.addQuadCurve(to: CGPoint(x: base.x - 2, y: base.y + 14), control: CGPoint(x: base.x + length * 0.7, y: base.y + 12))
        } else {
            tail.move(to: CGPoint(x: base.x - 8, y: base.y - 14))
            tail.addCurve(to: tip, control1: CGPoint(x: base.x + length * 0.3, y: base.y - 30), control2: CGPoint(x: tip.x - 12, y: tip.y - 14))
            tail.addCurve(to: CGPoint(x: base.x - 4, y: base.y + 18), control1: CGPoint(x: tip.x + 4, y: tip.y + 22), control2: CGPoint(x: base.x + length * 0.5, y: base.y + 22))
        }
        tail.closeSubpath()
        plate(tail, in: context, fill: bodyInk, lineWidth: lw)
        // Fin rays: three short lines on the fin.
        if !build.landForm {
            var rays = Path()
            for i in 1 ... 3 {
                let t = CGFloat(i) / 4
                let p = CGPoint(x: base.x + (tip.x - base.x) * t + 6, y: base.y + (tip.y - base.y) * t - 4)
                rays.move(to: p)
                rays.addLine(to: CGPoint(x: p.x + 5, y: p.y - 6))
            }
            // Clipped to the fin so the rays never stray outside it at hero sizes.
            var fin = context
            fin.clip(to: tail)
            fin.stroke(rays, with: .color(Tokens.tenaOutline.opacity(0.35)), style: StrokeStyle(lineWidth: lw * 0.55, lineCap: .round))
        }
    }

    func drawLegs(in context: GraphicsContext, lineWidth lw: CGFloat) {
        let y = bodyCenter.y + bodyRY * 0.82
        let long: CGFloat = build.landForm ? 1.35 : 1
        for side in [-1.0, 1.0] {
            let center = CGPoint(x: side * bodyRX * 0.5, y: y + 4 * long)
            plate(foot(center, rx: 11, ry: 8 * long, side: side), in: context, fill: bodyInk, lineWidth: lw)
        }
    }

    func drawArms(in context: GraphicsContext, lineWidth lw: CGFloat) {
        let regrowing = pose.extras.contains(.regrowth)
        for side in [-1.0, 1.0] {
            let center = CGPoint(x: side * (bodyRX * 0.86), y: bodyCenter.y + bodyRY * 0.38)
            let arm = foot(center, rx: 10, ry: 8, side: side)
            if regrowing, side > 0 {
                context.stroke(arm, with: .color(Tokens.tenaOutline), style: StrokeStyle(lineWidth: lw * 0.8, lineCap: .round, dash: [3, 3.5]))
            } else {
                plate(arm, in: context, fill: bodyInk, lineWidth: lw)
            }
        }
    }

    /// A stubby limb with three toe bumps.
    func foot(_ center: CGPoint, rx: CGFloat, ry: CGFloat, side: Double) -> Path {
        var path = ellipse(center, rx, ry)
        for i in -1 ... 1 {
            let toe = CGPoint(x: center.x + CGFloat(side) * rx * 0.55 + CGFloat(i) * rx * 0.55, y: center.y + ry * 0.8)
            path = path.union(ellipse(toe, rx * 0.36, ry * 0.42))
        }
        return path
    }

    func drawBody(in context: GraphicsContext, lineWidth lw: CGFloat) {
        let body = ellipse(bodyCenter, bodyRX, bodyRY)
        context.fill(body.offsetBy(dx: Self.pinkPlate.width, dy: Self.pinkPlate.height), with: .color(bodyInk))
        // One flat shade shape on the lower belly.
        var belly = context
        belly.clip(to: body)
        belly.fill(ellipse(CGPoint(x: bodyCenter.x + bodyRX * 0.1, y: bodyCenter.y + bodyRY * 0.75), bodyRX * 1.1, bodyRY * 0.6), with: .color(shadeInk.opacity(build.landForm ? 0.55 : 1)))
        if pose.fade > 0 {
            context.fill(body, with: .color((dark ? Color(red: 0.93, green: 0.77, blue: 0.76) : Tokens.paper).opacity(pose.fade)))
        }
        context.stroke(body, with: .color(Tokens.tenaOutline), lineWidth: lw)
    }

    func gillRoots(side: Double) -> [(CGPoint, Double, Double)] {
        // (root, direction in degrees for the left side, length)
        let rootScale = 0.86
        let roots: [(Double, Double, Double)] = [(208, 222, 30), (182, 192, 34), (158, 162, 27)]
        return roots.prefix(build.gillCount).enumerated().map { i, entry in
            let (rootAngle, direction, length) = entry
            let a = rootAngle * .pi / 180
            let root = CGPoint(x: CGFloat(side) * abs(cos(a)) * headRX * rootScale, y: headCenter.y + sin(a) * headRY * rootScale)
            let wiggle = pose.wiggle * sin(2 * .pi * time * 0.55 * pose.breathRate + Double(i) * 0.9 + (side > 0 ? 0.4 : 0))
            return (root, direction + pose.gillLift - wiggle, length * build.gillLength)
        }
    }

    func drawGills(in context: GraphicsContext, lineWidth lw: CGFloat) {
        for side in [-1.0, 1.0] {
            for (root, leftDirection, length) in gillRoots(side: side) {
                let a = leftDirection * .pi / 180
                // Left side points along (cos, sin) with cos < 0; mirror x for the right side.
                let d = CGVector(dx: CGFloat(cos(a)) * (side < 0 ? 1 : -1), dy: CGFloat(sin(a)))
                let tip = CGPoint(x: root.x + d.dx * length, y: root.y + d.dy * length)
                var stalk = Path()
                stalk.move(to: root)
                stalk.addLine(to: tip)
                var gill = stalk.strokedPath(StrokeStyle(lineWidth: 8.5, lineCap: .round))
                let normal = CGVector(dx: -d.dy, dy: d.dx)
                let filaments = build.gillFilaments
                if filaments > 0 {
                    for i in 1 ... filaments {
                        let t = 0.3 + 0.7 * CGFloat(i) / CGFloat(filaments + 1)
                        let p = CGPoint(x: root.x + d.dx * length * t, y: root.y + d.dy * length * t)
                        for s in [-1.0, 1.0] {
                            let f = CGPoint(x: p.x + normal.dx * CGFloat(s) * 4.6, y: p.y + normal.dy * CGFloat(s) * 4.6)
                            gill = gill.union(ellipse(f, 3.6, 3.6))
                        }
                    }
                }
                gill = gill.union(ellipse(tip, 5.4, 5.4))
                plate(gill, in: context, fill: build.golden ? Tokens.accent : Tokens.tenaGill, offset: Self.orangePlate, lineWidth: lw)
            }
        }
    }

    func drawHead(in context: GraphicsContext, lineWidth lw: CGFloat) {
        let head = headPath
        context.fill(head.offsetBy(dx: Self.pinkPlate.width, dy: Self.pinkPlate.height), with: .color(bodyInk))
        var shade = context
        shade.clip(to: head.offsetBy(dx: Self.pinkPlate.width, dy: Self.pinkPlate.height))
        // One flat shade crescent along the jaw.
        shade.fill(ellipse(CGPoint(x: headCenter.x + headRX * 0.08, y: headCenter.y + headRY * 1.05), headRX * 0.95, headRY * 0.38), with: .color(shadeInk))
        if build.spots > 0 {
            var spots = Path()
            let marks: [(CGFloat, CGFloat, CGFloat)] = [(-0.5, -0.62, 3.2), (0.42, -0.7, 2.6), (0.08, -0.82, 2.2), (-0.72, -0.2, 2.4), (0.7, -0.3, 2.8), (-0.25, -0.88, 1.8), (0.62, -0.58, 1.6), (-0.6, -0.5, 1.5), (0.3, -0.5, 1.4)]
            for mark in marks.prefix(build.spots) {
                spots.addPath(ellipse(CGPoint(x: headCenter.x + mark.0 * headRX, y: headCenter.y + mark.1 * headRY), mark.2, mark.2 * 0.85))
            }
            shade.fill(spots, with: .color(build.golden ? Tokens.accent : Tokens.tenaOutline.opacity(build.landForm ? 0.7 : 0.45)))
        }
        if pose.fade > 0 {
            context.fill(head, with: .color((dark ? Color(red: 0.93, green: 0.77, blue: 0.76) : Tokens.paper).opacity(pose.fade)))
        }
        context.stroke(head, with: .color(Tokens.tenaOutline), lineWidth: lw)
    }

    /// A broad, slightly flat-topped axolotl head (wider at the cheeks than an ellipse).
    var headPath: Path {
        let c = headCenter
        let rx = headRX
        let ry = headRY
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - ry))
        p.addCurve(to: CGPoint(x: c.x + rx, y: c.y + ry * 0.05), control1: CGPoint(x: c.x + rx * 0.62, y: c.y - ry), control2: CGPoint(x: c.x + rx, y: c.y - ry * 0.62))
        p.addCurve(to: CGPoint(x: c.x, y: c.y + ry), control1: CGPoint(x: c.x + rx, y: c.y + ry * 0.7), control2: CGPoint(x: c.x + rx * 0.55, y: c.y + ry))
        p.addCurve(to: CGPoint(x: c.x - rx, y: c.y + ry * 0.05), control1: CGPoint(x: c.x - rx * 0.55, y: c.y + ry), control2: CGPoint(x: c.x - rx, y: c.y + ry * 0.7))
        p.addCurve(to: CGPoint(x: c.x, y: c.y - ry), control1: CGPoint(x: c.x - rx, y: c.y - ry * 0.62), control2: CGPoint(x: c.x - rx * 0.62, y: c.y - ry))
        p.closeSubpath()
        return p
    }
}
