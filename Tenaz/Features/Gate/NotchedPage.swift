import SwiftUI

/// The gate's page: the whole screen except the top-right notification band, which stays see-through
/// so an incoming call banner is never hidden (PLAN F2, critique #1).
struct NotchedPage: Shape {
    var notch = CGSize(width: OverlayLayoutBand.width, height: OverlayLayoutBand.height)
    var radius: CGFloat = 28

    func path(in rect: CGRect) -> Path {
        let nx = rect.maxX - notch.width
        let ny = rect.minY + notch.height
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: nx - radius, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: nx, y: rect.minY + radius), control: CGPoint(x: nx, y: rect.minY))
        p.addLine(to: CGPoint(x: nx, y: ny - radius))
        p.addQuadCurve(to: CGPoint(x: nx + radius, y: ny), control: CGPoint(x: nx, y: ny))
        p.addLine(to: CGPoint(x: rect.maxX, y: ny))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// The notification band the gate and poster leave uncovered (menu bar excluded).
enum OverlayLayoutBand {
    nonisolated static let width: CGFloat = 400
    nonisolated static let height: CGFloat = 184
}
