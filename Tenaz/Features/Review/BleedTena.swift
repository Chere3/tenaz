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

    /// Her frame side and centre in the stage, per mood. The side edge cuts her near gill fan and never a
    /// hand or an elbow: when her arms reach that far (Ecstatic's fists, Proud's elbows) she moves in
    /// until 4.5 % of the window clears them, and shrinks so her far side gets no closer to the text than
    /// the default placement. The bottom edge crops her through the hips (86 % of her measured ink height;
    /// 80 % for the lying Asleep pose), and never higher than 4.5 % of the window below her lowest hand
    /// (Proud's hands on her hips, Sad's and Sick's hanging arms push it down); a hand that hangs to the
    /// feet shows her whole instead.
    private func placement(in stage: CGSize) -> (size: CGFloat, x: CGFloat, y: CGFloat) {
        let margin = 0.045 * stage.height
        let ink = TenaInk.bounds(stage: self.stage, mood: mood)
        let full = stage.height * heightShare
        let arms = TenaRig(mood: mood, stage: self.stage, time: 0, size: full).armFrame
        let leading = corner == .bottomLeading
        var size = full
        var x: CGFloat
        if leading {
            // Default: the frame centre at 32 % of its side from the edge.
            let a = arms?.minX ?? 0.5
            let far = full * (0.32 - 0.5 + ink.maxX)
            if full * 0.32 < margin + full * (0.5 - a) {
                size = min(full, (far - margin) / (ink.maxX - a))
                x = margin + size * (0.5 - a)
            } else {
                x = full * 0.32
            }
        } else {
            let b = arms?.maxX ?? 0.5
            let far = full * (0.32 + 0.5 - ink.minX)
            if full * 0.32 < margin + full * (b - 0.5) {
                size = min(full, (far - margin) / (b - ink.minX))
                x = stage.width - margin - size * (b - 0.5)
            } else {
                x = stage.width - full * 0.32
            }
        }
        let hands = arms.map { $0.maxY + margin / size } ?? 0
        let cut = min(ink.maxY, max(ink.minY + ink.height * (mood == .asleep ? 0.8 : 0.86), hands))
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
