import SwiftUI

/// A postage stamp: a rounded square, optionally with perforated (scalloped) edges cut out of it.
struct StampShape: InsettableShape {
    var perforated: Bool
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        guard perforated else {
            return Path(roundedRect: r, cornerRadius: r.width * 0.12, style: .continuous)
        }
        // Teeth: semicircle bites along every edge.
        let bites = 7
        let radius = r.width / CGFloat(bites) / 3.2
        var path = Path(roundedRect: r, cornerRadius: radius)
        var holes = Path()
        for i in 0..<bites {
            let t = (CGFloat(i) + 0.5) / CGFloat(bites)
            for center in [CGPoint(x: r.minX + r.width * t, y: r.minY), CGPoint(x: r.minX + r.width * t, y: r.maxY),
                           CGPoint(x: r.minX, y: r.minY + r.height * t), CGPoint(x: r.maxX, y: r.minY + r.height * t)] {
                holes.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            }
        }
        path = path.subtracting(holes)
        return path
    }

    func inset(by amount: CGFloat) -> StampShape {
        StampShape(perforated: perforated, inset: inset + amount)
    }
}
