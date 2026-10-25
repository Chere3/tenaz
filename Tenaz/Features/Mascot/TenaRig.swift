import SwiftUI
import TenazCore

/// Draws Tena ("Ink & Smile"): flat pink body, red gills with filament fringes, one warm wine ink
/// contour around the unioned silhouette, bead eyes that act with lids, and the wide axolotl smile.
/// Geometry is built in the 200 x 200 construction grid (docs: Tena rules v2), then fitted into the
/// frame from the stage's resting silhouette. `time` drives the idle loop; 0 is the resting pose.
struct TenaRig {
    let mood: TenaMood
    let stage: TenaStage
    /// Seconds; 0 = the resting pose.
    let time: Double
    /// Rendered side in points (sets the ink weight and the level of detail).
    let size: CGFloat
    /// Night scheme: gills switch to the night tokens; the Sick wash lifts toward a pale rose.
    var dark = false
    /// Kept for source compatibility. Tena has no ground shadow.
    var ground = false
    /// Mood props (headset, sign, bandage, medal, z). Off for the QA silhouettes.
    var props = true
    /// The word on Nagging's sign; nil draws a blank card.
    var word: String?
    /// Task progress for Regenerating (the limb regrows from 35 % to full).
    var progress: Double = 0.4
    /// Coral and orange floods: the gill fill steps down to gill deep (the one per-flood exception).
    var warmFlood = false
    /// Every fill in solid ink, no face: the silhouette test.
    var silhouette = false

    enum Detail { case hero, standard, small, glyph }

    /// Level of detail from the rendered size (rules §10).
    var lod: Detail {
        switch size {
        case 400...: .hero
        case 120...: .standard
        case 56...: .small
        default: .glyph
        }
    }

    var pose: TenaPose { TenaPose.for(mood) }
    var build: TenaBuild { TenaBuild.for(stage) }

    /// Tier-1 ink weight in points: no low cap, a 1.4 pt floor.
    var tier1Points: CGFloat { max(1.4, size * 0.0095) }

    struct Weights {
        /// Silhouette, face lines, props.
        var t1: CGFloat
        /// Toe splits, nostrils, creases (dropped at Small).
        var t2: CGFloat
    }

    func draw(in context: inout GraphicsContext) {
        let unit = size / 200
        context.scaleBy(x: unit, y: unit)
        let live = figure(pose: livePose, time: time)
        let (scale, offset) = placement(still: figure(pose: livePose, time: 0))
        var ctx = context
        ctx.translateBy(x: offset.x, y: offset.y)
        ctx.scaleBy(x: scale, y: scale)
        let t1 = tier1Points / (unit * scale)
        let weights = Weights(t1: t1, t2: max(0.9 / (unit * scale), t1 * 0.55))
        render(live, in: ctx, weights: weights)
    }

    /// Scale and offset (grid units) that place the resting figure in the frame.
    func placement(still: TenaFigure) -> (CGFloat, CGPoint) {
        let unit = size / 200
        return lod == .glyph && stage != .egg
            ? bustFit(figure: still.bounds, unit: unit)
            : fit(rest: figure(pose: restPose, time: 0).bounds, mood: still.bounds, unit: unit)
    }

    /// Her arms and hands at rest (ink included), as unit fractions of the frame; nil when no arm shows
    /// (limbless stages, the bust, the egg, the lying Asleep pose). Hero crops keep their edges clear of it.
    var armFrame: CGRect? {
        let still = figure(pose: livePose, time: 0)
        guard !still.armBounds.isNull else { return nil }
        let (scale, offset) = placement(still: still)
        let ink = tier1Points / (size / 200) / scale
        let r = still.armBounds.insetBy(dx: -ink, dy: -ink)
        return CGRect(x: (r.minX * scale + offset.x) / 200, y: (r.minY * scale + offset.y) / 200,
                      width: r.width * scale / 200, height: r.height * scale / 200)
    }

    /// The pose with level-of-detail rules applied (lid quantisation at Small, no props at Glyph).
    var livePose: TenaPose {
        var p = pose
        if !props || lod == .glyph || stage == .egg { p.prop = nil }
        if lod == .small || lod == .glyph {
            p.eye.lid = Self.quantised(p.eye.lid)
            if var r = p.rightEye { r.lid = Self.quantised(r.lid); p.rightEye = r }
        }
        if lod == .glyph {
            // The bust has only face and gills to act with: push the gill posture and the mouth.
            p.gills.lift = p.gills.lift.map { $0 * 1.6 }
            p.gills.asymmetry *= 1.5
            p.mouth.skew *= 1.5
            p.mouth.curve = max(-1, min(1, p.mouth.curve * 1.3))
            if p.mouth.width >= 0.5 { p.mouth.width = min(0.66, p.mouth.width * 1.08) }
        }
        return p
    }

    /// The bust (Glyph tier): the head is 78 % of the frame whatever the gills do, so the face carries the
    /// mood at 36 pt. The fans may run off the frame edge (the frame crops them; they never shrink).
    func bustFit(figure: CGRect, unit: CGFloat) -> (CGFloat, CGPoint) {
        let head = HeadShape(center: CGPoint(x: 100, y: 80), size: build.head)
        let margin = 2 + tier1Points / unit
        let scale = 156 / build.head.width
        let dx = 100 - head.center.x * scale
        // Centre the bust vertically, but keep the chin inside the frame.
        var dy = 100 - figure.midY * scale
        dy = min(dy, 200 - margin - (head.chin + 2) * scale)
        dy = max(dy, margin - figure.minY * scale - 12)
        return (scale, CGPoint(x: dx, y: dy))
    }

    /// The silhouette every mood of this stage is fitted against (Neutral at rest).
    var restPose: TenaPose { TenaPose.for(.neutral) }

    static func quantised(_ lid: Double) -> Double {
        lid < 0.2 ? 0 : (lid < 0.55 ? 0.4 : 0.7)
    }

    func figure(pose: TenaPose, time: Double) -> TenaFigure {
        if stage == .egg { return eggFigure(pose: pose, time: time) }
        if lod == .glyph { return bustFigure(pose: pose, time: time) }
        if pose.body.preset == .curled { return curledFigure(pose: pose, time: time) }
        return uprightFigure(pose: pose, time: time)
    }

    /// Fits the resting silhouette into the box with a 4-unit margin (plus the ink), then makes sure
    /// this mood's own silhouette fits too: one scale per stage, so moods never jump in size.
    func fit(rest: CGRect, mood: CGRect, unit: CGFloat) -> (CGFloat, CGPoint) {
        let margin = 4 + tier1Points / unit
        let room = 200 - 2 * margin
        var scale = min(room / rest.width, room / rest.height)
        scale = min(scale, room / mood.width, room / mood.height)
        var dx = 100 - rest.midX * scale
        var dy = 100 - rest.midY * scale
        let minX = mood.minX * scale + dx, maxX = mood.maxX * scale + dx
        let minY = mood.minY * scale + dy, maxY = mood.maxY * scale + dy
        if minX < margin { dx += margin - minX } else if maxX > 200 - margin { dx -= maxX - (200 - margin) }
        if minY < margin { dy += margin - minY } else if maxY > 200 - margin { dy -= maxY - (200 - margin) }
        return (scale, CGPoint(x: dx, y: dy))
    }

    // MARK: Colour

    var palette: Palette { dark ? .nightPress : .paper }

    func rgb(_ hex: HexColor) -> RGB { RGB(hex.value) }

    var ink: Color { rgb(palette.tenaOutline).color }

    /// Sick wash target: paper on light, a pale rose on dark.
    var wash: RGB { dark ? RGB(0xEEC4C2) : rgb(palette.background) }

    func color(_ fill: TenaFigure.Fill) -> Color {
        if silhouette || fill == .ink { return ink }
        let p = palette
        var c: RGB
        var gillLike = false
        switch fill {
        case .body: c = rgb(p.tenaPink)
        case .belly: c = rgb(p.tenaBelly)
        case .shade: c = rgb(p.tenaShade)
        case .mark: c = build.landForm ? rgb(p.tenaMark).mix(rgb(p.tenaGillDeep), 0.3) : rgb(p.tenaMark)
        case .highlight: c = RGB(0xFFF7EE)
        case .window: c = rgb(p.tenaBelly).mix(RGB(0xFFF7EE), 0.35)
        case .amber: c = rgb(p.tenaAmber)
        case .gill:
            c = warmFlood ? rgb(p.tenaGillDeep) : rgb(p.tenaGill)
            gillLike = true
        case .gillDeep:
            c = warmFlood ? rgb(p.tenaGillDeep).mix(RGB(0x7A1F35), 0.45) : rgb(p.tenaGillDeep)
            gillLike = true
        case .ink: c = rgb(p.tenaOutline)
        }
        let fade = livePose.fade
        if fade > 0 {
            // Sick gills fade toward the body pink (not grey, which reads as rot) and lose a little
            // saturation; the gill-deep root band keeps its step, so they still read as gills.
            if gillLike { c = c.mix(rgb(p.tenaPink), 0.3).desaturated(0.15) }
            c = c.mix(wash, fade)
        }
        return c.color
    }

    // MARK: Render

    func render(_ figure: TenaFigure, in ctx: GraphicsContext, weights: Weights) {
        for group in figure.groups { draw(group, in: ctx, weights: weights) }
        if !silhouette, let face = figure.face {
            var head = ctx
            head.concatenate(figure.headTransform)
            drawFace(face, in: head, weights: weights)
        }
        for group in figure.front { draw(group, in: ctx, weights: weights) }
        if !silhouette, let box = figure.signBox { drawSignText(box, in: ctx, weights: weights) }
        // Floating marks sit on the flood, not on her, so on dark floods they take the light belly pink.
        let mark = dark && !silhouette ? color(.belly) : ink
        for line in figure.inkLines {
            ctx.stroke(line, with: .color(mark), style: StrokeStyle(lineWidth: weights.t1, lineCap: .round, lineJoin: .round))
        }
    }

    func draw(_ group: TenaFigure.Group, in context: GraphicsContext, weights: Weights) {
        var ctx = context
        if let clip = group.clip { ctx.clip(to: clip) }
        let contour = StrokeStyle(lineWidth: weights.t1 * 2, lineCap: .round, lineJoin: .round)
        let inkShading = GraphicsContext.Shading.color(ink)
        if let erase = group.erase {
            ctx.drawLayer { layer in
                for part in group.parts where part.contour { layer.stroke(part.path, with: inkShading, style: contour) }
                if let clip = group.eraseClip { layer.clip(to: clip) }
                layer.blendMode = .destinationOut
                layer.fill(erase, with: .color(.black))
            }
        } else {
            for part in group.parts where part.contour { ctx.stroke(part.path, with: inkShading, style: contour) }
        }
        for part in group.parts {
            ctx.fill(part.path, with: .color(color(part.fill)))
            guard !part.decor.isEmpty, !silhouette else { continue }
            var inner = ctx
            inner.clip(to: part.path)
            for decor in part.decor {
                if decor.line {
                    inner.stroke(decor.path, with: .color(color(decor.fill)), style: StrokeStyle(lineWidth: weights.t2, lineCap: .round, lineJoin: .round))
                } else {
                    inner.fill(decor.path, with: .color(color(decor.fill)))
                }
            }
        }
    }
}
