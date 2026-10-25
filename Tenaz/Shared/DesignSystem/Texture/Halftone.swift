import SwiftUI

/// Riso halftone: dots on a hexagonal grid whose radius follows a coverage function (0...1).
/// Drawn with Canvas paths (no Metal), so ImageRenderer snapshots match the screen.
enum Halftone {
    static func dots(in rect: CGRect, spacing: CGFloat, coverage: (CGPoint) -> CGFloat) -> Path {
        var path = Path()
        // A tiny cell inset past zero becomes CGRect.null (origin +inf), and inf + spacing never
        // passes maxX: the loops would spin forever on the main thread.
        guard spacing > 0, !rect.isEmpty, rect.minX.isFinite, rect.minY.isFinite,
              rect.maxX.isFinite, rect.maxY.isFinite else { return path }
        let rowHeight = spacing * 0.866
        var row = 0
        var y = rect.minY
        while y <= rect.maxY + rowHeight {
            var x = rect.minX + (row.isMultiple(of: 2) ? 0 : spacing / 2)
            while x <= rect.maxX + spacing {
                let point = CGPoint(x: x, y: y)
                let c = min(1, max(0, coverage(point)))
                if c > 0.04 {
                    let r = spacing * 0.56 * c
                    path.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                }
                x += spacing
            }
            y += rowHeight
            row += 1
        }
        return path
    }

    /// Coverage that ramps linearly from `from` (0) to `to` (1) along the segment between them.
    static func ramp(from start: CGPoint, to end: CGPoint, low: CGFloat = 0, high: CGFloat = 1) -> (CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length2 = max(0.0001, dx * dx + dy * dy)
        return { p in
            let t = ((p.x - start.x) * dx + (p.y - start.y) * dy) / length2
            return low + (high - low) * min(1, max(0, t))
        }
    }
}
