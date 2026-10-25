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
    /// The stage x where the text column begins (leading corner) or ends (trailing corner); her far gill
    /// fan keeps 3 % of the stage width from it. Nil on a leading corner means the standard column at
    /// `columnShare`; nil on a trailing corner sets no limit.
    var textEdge: CGFloat?

    /// Where the text column starts beside her, as a share of the content width.
    static let columnShare: CGFloat = 0.45

    var body: some View {
        GeometryReader { proxy in
            let place = placement(in: proxy.size)
            ZStack {
                if rays {
                    Sunburst()
                        .frame(width: proxy.size.width * 2.4, height: proxy.size.width * 2.4)
                        .position(x: place.x, y: place.y - place.size * 0.06)
                }
                TenaView(mood: mood, stage: stage, size: place.size)
                    .position(x: place.x, y: place.y)
            }
        }
        .allowsHitTesting(false)
    }

    /// Her frame side and centre in the stage, per mood. By default the frame centre sits 32 % of its side
    /// from the corner edge, which cuts her near gill fan and never a hand, an elbow or her head: when they
    /// reach that far (Ecstatic's fists, Proud's elbows, Focused's leaning head and headset) she moves in
    /// until 4.5 % of the window clears them. Her far side never reaches further than that default, nor
    /// within 3 % of the text column (`textEdge`); she shrinks instead. The bottom edge crops her at
    /// `TenaInk.bottomCut`, with 4.5 % of the window clear below her lowest hand.
    private func placement(in stage: CGSize) -> (size: CGFloat, x: CGFloat, y: CGFloat) {
        let margin = 0.045 * stage.height
        let ink = TenaInk.bounds(stage: self.stage, mood: mood)
        let full = stage.height * heightShare
        let rig = TenaRig(mood: mood, stage: self.stage, time: 0, size: full)
        let leading = corner == .bottomLeading
        // Measured from the corner edge inwards, so both corners share one rule.
        let inkFar = leading ? ink.maxX : 1 - ink.minX
        // The side edge may cut her gills and tail, never a hand, an elbow or her head.
        let keep = [rig.armFrame, rig.headFrame].compactMap(\.self)
        let keepNear = keep.map { leading ? $0.minX : 1 - $0.maxX }.min() ?? 0.5
        let text = textEdge ?? (leading ? stage.width * Self.columnShare : nil)
        let textReach = text.map { (leading ? $0 : stage.width - $0) - 0.03 * stage.width } ?? .infinity
        let reach = min(full * (inkFar - 0.18), textReach)
        var size = min(full, reach / (inkFar - 0.18))
        var centre = size * 0.32
        if centre < margin + size * (0.5 - keepNear) {
            size = min(full, (reach - margin) / (inkFar - keepNear))
            centre = margin + size * (0.5 - keepNear)
        }
        let x = leading ? centre : stage.width - centre
        let cut = TenaInk.bottomCut(stage: self.stage, mood: mood, size: size, margin: margin)
        return (size, x, stage.height - cut * size + size * 0.5)
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
