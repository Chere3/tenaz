import SwiftUI

// Small vector maths and curve builders for the rig (200-unit grid, y down).

extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
    static func * (a: CGPoint, k: CGFloat) -> CGPoint { CGPoint(x: a.x * k, y: a.y * k) }
    var length: CGFloat { hypot(x, y) }
    var normalized: CGPoint { let l = max(length, 0.0001); return CGPoint(x: x / l, y: y / l) }
    /// Rotated by `degrees` (positive = clockwise on screen, since y points down).
    func rotated(_ degrees: Double) -> CGPoint {
        let a = CGFloat(degrees * .pi / 180)
        let c = cos(a), s = sin(a)
        return CGPoint(x: x * c - y * s, y: x * s + y * c)
    }
    func lerp(_ b: CGPoint, _ t: CGFloat) -> CGPoint { CGPoint(x: x + (b.x - x) * t, y: y + (b.y - y) * t) }
    /// The unit vector at `degrees` above the horizontal, pointing right (side +1) or left (side -1).
    static func heading(_ degrees: Double, side: CGFloat) -> CGPoint {
        let a = CGFloat(degrees * .pi / 180)
        return CGPoint(x: side * cos(a), y: -sin(a))
    }
}

enum Curve {
    /// A closed smooth path through `points` (Catmull-Rom turned into cubic Béziers).
    static func closed(_ points: [CGPoint]) -> Path {
        var path = Path()
        let n = points.count
        guard n > 2 else { return path }
        path.move(to: points[0])
        for i in 0 ..< n {
            let p0 = points[(i - 1 + n) % n], p1 = points[i], p2 = points[(i + 1) % n], p3 = points[(i + 2) % n]
            path.addCurve(to: p2, control1: p1 + (p2 - p0) * (1 / 6), control2: p2 - (p3 - p1) * (1 / 6))
        }
        path.closeSubpath()
        return path
    }

    /// An open smooth path through `points`.
    static func open(_ points: [CGPoint]) -> Path {
        var path = Path()
        let n = points.count
        guard n > 1 else { return path }
        path.move(to: points[0])
        for i in 0 ..< n - 1 {
            let p0 = points[max(i - 1, 0)], p1 = points[i], p2 = points[i + 1], p3 = points[min(i + 2, n - 1)]
            path.addCurve(to: p2, control1: p1 + (p2 - p0) * (1 / 6), control2: p2 - (p3 - p1) * (1 / 6))
        }
        return path
    }

    static func quad(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        let u = 1 - t
        return a * (u * u) + c * (2 * u * t) + b * (t * t)
    }

    static func cubic(_ a: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        let u = 1 - t
        return a * (u * u * u) + c1 * (3 * u * u * t) + c2 * (3 * u * t * t) + b * (t * t * t)
    }

    /// A tapered ribbon around a centreline: `halfWidth(t)` per sample, a round cap at the far end when
    /// `capEnd`, the near end left open-flat (it is buried in the part it grows from).
    static func ribbon(_ spine: [CGPoint], halfWidth: (CGFloat) -> CGFloat, capEnd: Bool = true) -> Path {
        let n = spine.count
        guard n > 1 else { return Path() }
        var left: [CGPoint] = [], right: [CGPoint] = []
        for i in 0 ..< n {
            let t = CGFloat(i) / CGFloat(n - 1)
            let tangent = (spine[min(i + 1, n - 1)] - spine[max(i - 1, 0)]).normalized
            let normal = CGPoint(x: -tangent.y, y: tangent.x)
            let w = halfWidth(t)
            left.append(spine[i] + normal * w)
            right.append(spine[i] - normal * w)
        }
        var outline = left
        if capEnd {
            let end = spine[n - 1]
            let tangent = (spine[n - 1] - spine[n - 2]).normalized
            let normal = CGPoint(x: -tangent.y, y: tangent.x)
            let w = halfWidth(1)
            for k in 1 ..< 5 {
                let phi = CGFloat(k) / 5 * .pi
                outline.append(end + normal * (w * cos(phi)) + tangent * (w * sin(phi)))
            }
        }
        outline.append(contentsOf: right.reversed())
        return closed(outline)
    }

    static func ellipse(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2))
    }
}

/// The axolotl head (rules §1.3): a split superellipse, widest at the cheek line 6 units below the
/// centre, flatter on top (exponent 2.6) than below (2.2).
struct HeadShape {
    var center: CGPoint
    var size: CGSize

    var a: CGFloat { size.width / 2 }
    var cheekDrop: CGFloat { 6 * size.height / 80 }
    var cheekY: CGFloat { center.y + cheekDrop }
    var top: CGFloat { size.height / 2 + cheekDrop }
    var bottom: CGFloat { size.height / 2 - cheekDrop }
    static let topExponent: CGFloat = 2.6
    static let bottomExponent: CGFloat = 2.2

    var chin: CGFloat { cheekY + bottom }

    func point(_ t: Double) -> CGPoint {
        let c = CGFloat(cos(t)), s = CGFloat(sin(t))
        let up = s < 0
        let n = up ? Self.topExponent : Self.bottomExponent
        let x = a * (c < 0 ? -1 : 1) * pow(abs(c), 2 / n)
        let y = (up ? -top : bottom) * pow(abs(s), 2 / n)
        return CGPoint(x: center.x + x, y: cheekY + y)
    }

    var path: Path {
        Curve.closed((0 ..< 72).map { point(Double($0) / 72 * 2 * .pi) })
    }

    func contains(_ p: CGPoint) -> Bool {
        let dx = abs(p.x - center.x) / a
        let dy = p.y - cheekY
        let up = dy < 0
        let n = up ? Self.topExponent : Self.bottomExponent
        let ny = abs(dy) / (up ? top : bottom)
        return pow(dx, n) + pow(ny, n) < 1
    }

    /// Where a ray from the head centre at `degrees` above horizontal (to the right for side +1)
    /// crosses the contour.
    func contour(polar degrees: Double, side: CGFloat) -> CGPoint {
        let d = CGPoint.heading(degrees, side: side)
        var lo: CGFloat = 0, hi = size.width
        for _ in 0 ..< 24 {
            let mid = (lo + hi) / 2
            if contains(center + d * mid) { lo = mid } else { hi = mid }
        }
        return center + d * lo
    }

    /// Half-width of the head at height `y` (0 outside it).
    func halfWidth(at y: CGFloat) -> CGFloat {
        let dy = y - cheekY
        let up = dy < 0
        let n = up ? Self.topExponent : Self.bottomExponent
        let ny = abs(dy) / (up ? top : bottom)
        guard ny < 1 else { return 0 }
        return a * pow(1 - pow(ny, n), 1 / n)
    }
}

/// The body bean: a superellipse, a little wider and flatter at the bottom where she sits.
struct BeanShape {
    var center: CGPoint
    var size: CGSize

    func point(_ t: Double) -> CGPoint {
        let c = CGFloat(cos(t)), s = CGFloat(sin(t))
        let n: CGFloat = s > 0 ? 2.6 : 2.2
        let y = size.height / 2 * (s < 0 ? -1 : 1) * pow(abs(s), 2 / n)
        let widen = 0.94 + 0.06 * (y / (size.height / 2) + 1) / 2
        let x = size.width / 2 * widen * (c < 0 ? -1 : 1) * pow(abs(c), 2 / n)
        return CGPoint(x: center.x + x, y: center.y + y)
    }

    var path: Path { Curve.closed((0 ..< 56).map { point(Double($0) / 56 * 2 * .pi) }) }
    var top: CGFloat { center.y - size.height / 2 }
    var bottom: CGFloat { center.y + size.height / 2 }
}

/// Colour maths on palette hex values (the rig blends for the Sick wash, so it never stacks layers).
struct RGB {
    var r: Double, g: Double, b: Double

    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }

    func mix(_ o: RGB, _ t: Double) -> RGB { RGB(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t) }

    /// Halfway (or `amount`) toward its own luminance grey.
    func desaturated(_ amount: Double) -> RGB {
        let l = 0.299 * r + 0.587 * g + 0.114 * b
        return mix(RGB(r: l, g: l, b: l), amount)
    }

    var grey: RGB { desaturated(1) }
    var color: Color { Color(.sRGB, red: r, green: g, blue: b) }
}
