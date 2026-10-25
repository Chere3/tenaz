import SwiftUI

/// Three fronds per side (rules §1.2): roots on the head contour at polar 40/20/2°, axes at
/// 58/30/6° above horizontal, top longest. Each frond tapers and carries its filaments on the
/// upper edge only, in gill deep (never ink).
extension TenaRig {
    static let rootPolar: [Double] = [40, 20, 2]
    static let axis: [Double] = [58, 30, 6]

    var gillShape: TenaBuild.GillShape {
        switch lod {
        case .hero, .standard: build.gillShape
        case .small: build.gillShape == .nub ? .nub : .tube(notches: 2)
        case .glyph: build.gillShape == .nub ? .nub : .tube(notches: 0)
        }
    }

    struct FrondOptions {
        var lengthScale: CGFloat = 1
        /// Regrows the top-left frond (limbless stages): 0.35 ... 1 of its length, belly pink until whole.
        var regrowTopLeft: Double?
        /// Wraps the top-left frond (limbless Sick).
        var bandageTopLeft = false
    }

    /// Frond parts in head-local units, back to front, plus a bandage wrap when asked.
    func fronds(head: HeadShape, pose: TenaPose, time t: Double, options: FrondOptions = FrondOptions()) -> (parts: [TenaFigure.Part], wrap: TenaFigure.Part?) {
        var parts: [TenaFigure.Part] = []
        var wrap: TenaFigure.Part?
        let w = head.size.width
        let shape = gillShape
        let (rootW, tipW): (CGFloat, CGFloat) = switch shape {
        case .nub: (0.105 * w, 0.085 * w)
        case .tube: lod == .glyph ? (0.125 * w, 0.06 * w) : (0.09 * w, 0.042 * w)
        case .fringe: (0.10 * w, 0.034 * w)
        }
        for side in [CGFloat(-1), 1] {
            for i in 0 ..< 3 {
                var alpha = 30 + (Self.axis[i] - 30) * pose.gills.spread + pose.gills.lift[i] - build.gillSweep
                if side > 0 { alpha += pose.gills.asymmetry }
                alpha += wiggle(i, side: side, pose: pose, t: t)
                let regrowing = i == 0 && side < 0 ? options.regrowTopLeft : nil
                var length = w * CGFloat(build.gillLengths[i] * pose.gills.length) * options.lengthScale
                if let p = regrowing { length *= CGFloat(0.35 + 0.65 * p) }
                let edge = head.contour(polar: Self.rootPolar[i], side: side)
                let ray = (edge - head.center).normalized
                let root = edge - ray * (0.035 * w)
                let d = CGPoint.heading(alpha, side: side)
                let d2 = CGPoint.heading(alpha + 10 - pose.gills.curl, side: side)
                let p0 = root - d * 5
                let c = root + d * (length * 0.5)
                let p2 = c + d2 * (length * 0.5)
                let spine = (0 ... 14).map { Curve.quad(p0, c, p2, CGFloat($0) / 14) }
                // A paddle: full at the root, a slight belly at a third, tapering to a round tip.
                let halfWidth: (CGFloat) -> CGFloat = { s in
                    (rootW / 2 * (1 - s) + tipW / 2 * s) * (1 + 0.16 * sin(.pi * min(1, s / 0.7)))
                }
                let outline = Curve.ribbon(spine, halfWidth: halfWidth)

                func frame(_ s: CGFloat) -> (p: CGPoint, tangent: CGPoint, upper: CGPoint) {
                    let p = Curve.quad(p0, c, p2, s)
                    let tangent = ((c - p0) * (2 * (1 - s)) + (p2 - c) * (2 * s)).normalized
                    let upper = side > 0 ? CGPoint(x: tangent.y, y: -tangent.x) : CGPoint(x: -tangent.y, y: tangent.x)
                    return (p, tangent, upper)
                }

                // Amber on the last 40 % (Elder): a half-plane across the frond, so it reads at 64 pt.
                var amber: Path?
                if build.amberTips {
                    let f = frame(0.6)
                    var plane = Path()
                    plane.move(to: f.p + f.upper * 80)
                    plane.addLine(to: f.p - f.upper * 80)
                    plane.addLine(to: f.p - f.upper * 80 + f.tangent * 120)
                    plane.addLine(to: f.p + f.upper * 80 + f.tangent * 120)
                    plane.closeSubpath()
                    amber = plane
                }

                let fill: TenaFigure.Fill = regrowing.map { $0 < 1 ? .belly : .gill } ?? .gill
                let fingerFill: TenaFigure.Fill = fill == .belly ? .belly : .gillDeep
                // Filaments (or short notches) along the upper edge: each leaves the frond at ~52° and
                // sweeps back toward the tip, tapering to a round cap; long near the root, short at the tip.
                let fingers: [(s: CGFloat, length: CGFloat, width: CGFloat)]
                switch shape {
                case .nub: fingers = []
                case let .tube(notches):
                    fingers = (0 ..< notches).map { j in
                        let s = 0.45 + 0.27 * CGFloat(j)
                        return (s, 0.13 * length, halfWidth(s) * 1.1)
                    }
                case let .fringe(n):
                    fingers = (0 ..< n).map { j in
                        let u = CGFloat(j) / CGFloat(max(n - 1, 1))
                        let s = 0.28 + 0.62 * u
                        return (s, length * (0.32 - 0.18 * u), max(2.2, halfWidth(s) * 0.74))
                    }
                }
                let lift = 52 * CGFloat.pi / 180, sweep = 22 * CGFloat.pi / 180
                for finger in fingers {
                    let f = frame(finger.s)
                    let base = f.p + f.upper * (halfWidth(finger.s) * 0.3)
                    let out = (f.tangent * cos(lift) + f.upper * sin(lift)).normalized
                    let back = (f.tangent * cos(sweep) + f.upper * sin(sweep)).normalized
                    let a = base - out * (finger.width * 0.4)
                    let c = base + out * (finger.length * 0.55)
                    let b = c + back * (finger.length * 0.5)
                    let spine = (0 ... 8).map { Curve.quad(a, c, b, CGFloat($0) / 8) }
                    let half = finger.width / 2
                    let strand = Curve.ribbon(spine, halfWidth: { t in half * (1 - 0.42 * t) })
                    var decor: [TenaFigure.Decor] = []
                    if let amber { decor.append(.init(path: amber, fill: .amber)) }
                    parts.append(TenaFigure.Part(path: strand, fill: fingerFill, decor: decor))
                }

                var decor: [TenaFigure.Decor] = []
                if fill == .gill, shape != .nub || lod == .hero || lod == .standard {
                    decor.append(.init(path: Curve.ellipse(root, 0.2 * length + 5, 0.2 * length + 5), fill: .gillDeep))
                }
                if let amber { decor.append(.init(path: amber, fill: .amber)) }
                parts.append(TenaFigure.Part(path: outline, fill: fill, decor: decor))

                if options.bandageTopLeft, i == 0, side < 0 {
                    let f = frame(0.5)
                    let hw = halfWidth(0.5) + 1.8
                    var band = Path()
                    band.move(to: f.p + f.upper * hw - f.tangent * 3.2)
                    band.addLine(to: f.p + f.upper * hw + f.tangent * 3.2)
                    band.addLine(to: f.p - f.upper * hw + f.tangent * 3.2)
                    band.addLine(to: f.p - f.upper * hw - f.tangent * 3.2)
                    band.closeSubpath()
                    wrap = TenaFigure.Part(path: band, fill: .highlight)
                }
            }
        }
        return (parts, wrap)
    }
}
