import SwiftUI

/// Tena big and cropped by the bottom edge (never framed), for full-bleed hero screens. Put it in the
/// background of a clipped stage: it sizes itself from the stage height and hangs off the corner.
/// `rays` adds the event sunburst behind her (only on `.good` / `.celebrate` moments).
struct BleedTena: View {
    enum Corner { case bottomLeading, bottomTrailing }

    let mood: TenaMood
    let stage: TenaStage
    var corner: Corner = .bottomLeading
    /// Share of the stage height Tena's frame takes (the spec asks for 60-75 %).
    var heightShare: CGFloat = 0.74
    var rays = false

    /// Where the text column starts beside her, as a share of the content width.
    static let columnShare: CGFloat = 0.45

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size.height * heightShare
            let x = corner == .bottomLeading ? size * 0.32 : proxy.size.width - size * 0.32
            // TenaRig draws her from ~30 % to ~85 % of the frame plus a ground shadow; pushing the
            // frame 20 % below the edge crops the shadow and her feet, so she sits on the window edge.
            let y = proxy.size.height - size * 0.5 + size * 0.2
            ZStack {
                if rays {
                    Sunburst()
                        .frame(width: proxy.size.width * 2.4, height: proxy.size.width * 2.4)
                        .position(x: x, y: y - size * 0.06)
                }
                TenaView(mood: mood, stage: stage, size: size)
                    .position(x: x, y: y)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Event rays: alternating wedges of ink at 7 % from the centre.
struct Sunburst: View {
    var count = 18

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = max(size.width, size.height)
            let step = Double.pi * 2 / Double(count)
            var path = Path()
            for i in 0 ..< count {
                let start = Double(i) * step + step * 0.3
                let end = start + step * 0.5
                path.move(to: center)
                path.addLine(to: CGPoint(x: center.x + radius * cos(start), y: center.y + radius * sin(start)))
                path.addLine(to: CGPoint(x: center.x + radius * cos(end), y: center.y + radius * sin(end)))
                path.closeSubpath()
            }
            context.fill(path, with: .color(Tokens.ink.opacity(0.07)))
        }
        .accessibilityHidden(true)
    }
}

/// A 4-point sparkle in ink, for event screens only.
struct Sparkle: View {
    var size: CGFloat = 18

    var body: some View {
        SparkleShape()
            .fill(Tokens.ink)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let waist = r * 0.22
        var path = Path()
        path.move(to: CGPoint(x: c.x, y: c.y - r))
        path.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + waist, y: c.y - waist))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + waist, y: c.y + waist))
        path.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - waist, y: c.y + waist))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - waist, y: c.y - waist))
        path.closeSubpath()
        return path
    }
}
