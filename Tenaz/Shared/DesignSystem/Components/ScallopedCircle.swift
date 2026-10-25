import SwiftUI

/// A stamp edge: a circle with `scallops` soft bumps.
struct ScallopedCircle: Shape {
    var scallops = 18
    /// Bump depth as a fraction of the radius.
    var depth: CGFloat = 0.06

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        let steps = scallops * 12
        for i in 0 ... steps {
            let angle = Double(i) / Double(steps) * 2 * .pi
            let r = radius * (1 - depth + depth * CGFloat(abs(cos(angle * Double(scallops) / 2))))
            let p = CGPoint(x: center.x + r * CGFloat(cos(angle)), y: center.y + r * CGFloat(sin(angle)))
            i == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        path.closeSubpath()
        return path
    }
}
