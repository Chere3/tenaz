import SwiftUI

/// Builds the figure: one unioned silhouette (fin, tail, legs, body, neck fillet, gills, head),
/// then the front limbs and props as their own contoured groups.
extension TenaRig {
    typealias Part = TenaFigure.Part
    typealias Decor = TenaFigure.Decor

    /// `m` applied about `p`.
    func about(_ p: CGPoint, _ m: CGAffineTransform) -> CGAffineTransform {
        CGAffineTransform(translationX: -p.x, y: -p.y).concatenating(m).concatenating(CGAffineTransform(translationX: p.x, y: p.y))
    }

    func moved(_ part: Part, _ t: CGAffineTransform) -> Part {
        var p = part
        p.path = part.path.applying(t)
        p.decor = part.decor.map { Decor(path: $0.path.applying(t), fill: $0.fill, line: $0.line) }
        return p
    }

    var showsDetail: Bool { lod == .hero || lod == .standard }

    /// Bead radius in head-local units (eyes ×1.3 at Small, face ×1.4 in the bust).
    var beadRadius: CGSize {
        let k = CGFloat(build.eyeScale) * (lod == .small ? 1.3 : (lod == .glyph ? 1.4 : 1))
        return CGSize(width: 6.5 * k, height: 7 * k)
    }

    func faceAnchors(head: HeadShape, pose: TenaPose) -> TenaFigure.Face {
        let w = head.size.width
        let eyeY = head.center.y + 2
        let raised: CGFloat = build.landForm ? 10 : 0
        let mouthY = eyeY + 0.22 * head.size.height
        let cx = head.center.x
        let eyeDX: CGFloat = 0.25 * w
        let eyes = [CGPoint(x: cx - eyeDX, y: eyeY - raised), CGPoint(x: cx + eyeDX, y: eyeY - raised)]
        let noseDX: CGFloat = 7 * w / 124
        let nostrils = [CGPoint(x: cx - noseDX, y: eyeY + 8), CGPoint(x: cx + noseDX, y: eyeY + 8)]
        let mouthX: CGFloat = cx + CGFloat(pose.mouth.offset) * w
        let mouthW: CGFloat = CGFloat(pose.mouth.width) * w
        return TenaFigure.Face(head: head, eyes: eyes, eyeRadius: beadRadius, mouthCenter: CGPoint(x: mouthX, y: mouthY),
                               mouthWidth: mouthW, mouthHeightLimit: 0.28 * head.size.height, nostrils: nostrils)
    }

    /// The crown: three mark-pink dots in a shallow arc above and between the eyes (centre dot 10 % larger).
    func crown(head: HeadShape) -> [Decor] {
        let sx = head.size.width / 124, sy = head.size.height / 80
        let k: CGFloat = lod == .glyph ? 1.25 : (lod == .small ? 1.15 : 1)
        let c = head.center
        let lift: CGFloat = build.landForm ? -4 : 0
        let dots: [(CGFloat, CGFloat, CGFloat)] = [(-8, -16, 2.4), (0, -18, 2.8), (8, -16, 2.4)]
        return dots.map { dx, dy, r in
            let p = CGPoint(x: c.x + dx * sx * k, y: c.y + dy * sy + lift)
            return Decor(path: Curve.ellipse(p, r * k, r * k), fill: .mark)
        }
    }

    // MARK: Upright

    func uprightFigure(pose: TenaPose, time t: Double) -> TenaFigure {
        let b = build
        let preset = pose.body.preset
        var headSize = b.head
        if preset == .press { headSize = CGSize(width: headSize.width * 1.03, height: headSize.height * 0.97) }
        let head = HeadShape(center: CGPoint(x: 100, y: 80), size: headSize)
        let bodySize = CGSize(width: b.body.width * pose.body.squash.width, height: b.body.height * pose.body.squash.height)
        let bodyTop = head.chin - 8
        let bean = BeanShape(center: CGPoint(x: 100, y: bodyTop + bodySize.height / 2), size: bodySize)
        let k = sqrt(b.body.width / 72)
        let legDrop: CGFloat = switch stage {
        case .juvenile: 8
        case .subAdult: 11
        case .adult, .elder: 12
        case .metamorph: 20
        default: 0
        }
        let feetY = bean.bottom + legDrop + 4

        // Transforms: breath on the body, the mood's lean about the feet, the head on its neck pivot.
        let br = CGFloat(breath(t, rate: pose.breathRate)) * 0.015
        let (lift, landing) = hop(t)
        let base = CGPoint(x: 100, y: feetY)
        let breathT = about(CGPoint(x: 100, y: bean.bottom), CGAffineTransform(scaleX: 1, y: 1 + br))
        let leanT = about(base, CGAffineTransform(rotationAngle: pose.body.lean * .pi / 180))
        let hopT = about(base, CGAffineTransform(scaleX: landing.width, y: landing.height))
            .concatenating(CGAffineTransform(translationX: 0, y: -lift))
        let bodyT = breathT.concatenating(leanT).concatenating(hopT)
        let pivot = CGPoint(x: 100, y: head.chin - 6)
        let forward = CGFloat(pose.body.forward)
        let drop = forward * 0.7 + (preset == .slump ? 4 : 0) - bodySize.height * br
        let grow = 1 + forward * 0.004
        let headLocal = about(pivot, CGAffineTransform(scaleX: grow, y: grow).rotated(by: (pose.tilt + sway(t)) * .pi / 180))
            .concatenating(CGAffineTransform(translationX: 0, y: drop))
        let headT = headLocal.concatenating(leanT).concatenating(hopT)

        var silhouette: [Part] = []
        let tail = tailParts(bean: bean, bodySize: bodySize, pose: pose, t: t)
        silhouette += tail.map { moved($0, bodyT) }
        silhouette += legParts(bean: bean, bodySize: bodySize, k: k, legDrop: legDrop).map { moved($0, bodyT) }
        if b.limbs == .none {
            for side in [CGFloat(-1), 1] {
                let c = CGPoint(x: 100 + side * 0.47 * bodySize.width, y: bean.center.y + 3)
                let flap = Curve.ellipse(.zero, 7.5, 4.4)
                    .applying(CGAffineTransform(rotationAngle: side * 0.55).concatenating(CGAffineTransform(translationX: c.x, y: c.y)))
                silhouette.append(moved(Part(path: flap, fill: .body), bodyT))
            }
        }
        let headInModel = head.path.applying(headT)
        // The head's cast shadow on the upper body. The light is upper-right, so it falls under the
        // left jaw only: a short crescent that follows the jaw curve and fades out at both ends
        // (never a full-width band, which reads as a collar).
        let chinModel = CGPoint(x: 100 - 0.17 * bodySize.width, y: head.chin - 2).applying(headT)
        let shadowReach = Curve.ellipse(chinModel, 0.22 * bodySize.width, 7.5)
        let shade = Decor(path: shadowReach.subtracting(headInModel), fill: .shade)
        var body = moved(Part(path: bean.path, fill: .body, decor: [
            Decor(path: Curve.ellipse(CGPoint(x: 99, y: bean.center.y + 0.15 * bodySize.height), 0.29 * bodySize.width, 0.32 * bodySize.height), fill: .belly),
        ]), bodyT)
        body.decor.append(shade)
        body.decor += freckles(on: .body, bean: bean, head: head).map { Decor(path: $0.applying(bodyT), fill: .mark) }
        silhouette.append(body)
        var neck = moved(Part(path: Curve.ellipse(CGPoint(x: 100, y: head.chin - 3), 0.36 * bodySize.width, 5), fill: .body), bodyT)
        neck.decor.append(shade)
        silhouette.append(neck)

        // Gills and head (head-local, then on the neck).
        let limblessRegrow = b.limbs == .none || b.limbs == .buds
        let options = FrondOptions(
            regrowTopLeft: preset == .regrow && limblessRegrow ? progress : nil,
            bandageTopLeft: pose.prop == .bandage && stage.rawValue <= 2
        )
        let gills = fronds(head: head, pose: pose, time: t, options: options)
        silhouette += gills.parts.map { moved($0, headT) }
        var headDecor = crown(head: head)
        if showsDetail { headDecor += freckles(on: .head, bean: bean, head: head).map { Decor(path: $0, fill: .mark) } }
        silhouette.append(moved(Part(path: head.path, fill: .body, decor: headDecor), headT))
        let face = faceAnchors(head: head, pose: pose)
        if b.landForm {
            for eye in face.eyes {
                let r = beadRadius
                silhouette.append(moved(Part(path: Curve.ellipse(CGPoint(x: eye.x, y: eye.y - 1), r.width * 1.95, r.height * 1.8), fill: .body), headT))
            }
        }

        var figure = TenaFigure()
        figure.groups = [TenaFigure.Group(parts: silhouette)]
        figure.face = face
        figure.headTransform = headT

        // Props on the body (behind the arms).
        if pose.prop == .sign {
            let limbless = b.limbs == .none
            let center = limbless
                ? CGPoint(x: 100 + 0.5 * bodySize.width, y: bean.center.y + 0.1 * bodySize.height)
                : CGPoint(x: 100, y: bean.center.y + 0.04 * bodySize.height)
            let cardSize = limbless ? CGSize(width: 50, height: 28) : CGSize(width: 0.92 * b.body.width + 6, height: 0.6 * b.body.height)
            let angle: Double = limbless ? 10 : -4
            let card = Path(roundedRect: CGRect(x: -cardSize.width / 2, y: -cardSize.height / 2, width: cardSize.width, height: cardSize.height), cornerRadius: 3.5)
                .applying(CGAffineTransform(rotationAngle: angle * .pi / 180).concatenating(CGAffineTransform(translationX: center.x, y: center.y)))
            figure.front.append(TenaFigure.Group(parts: [moved(Part(path: card, fill: .highlight), bodyT)]))
            if lod != .small { figure.signBox = (center.applying(bodyT), cardSize, angle + pose.body.lean) }
        }
        if pose.prop == .medal, showsDetail {
            let chin = CGPoint(x: 100, y: head.chin).applying(headT)
            let medal = CGPoint(x: 100, y: bodyTop + 0.56 * bodySize.height).applying(bodyT)
            var ribbon = Path()
            ribbon.move(to: CGPoint(x: chin.x - 0.16 * bodySize.width, y: chin.y - 2))
            ribbon.addLine(to: CGPoint(x: medal.x, y: medal.y - 4))
            ribbon.addLine(to: CGPoint(x: chin.x + 0.16 * bodySize.width, y: chin.y - 2))
            let strap = ribbon.strokedPath(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            let r = 6.8 * k
            figure.front.append(TenaFigure.Group(parts: [
                Part(path: strap, fill: .ink, contour: false),
                Part(path: Curve.ellipse(medal, r, r), fill: .amber, decor: [
                    Decor(path: Curve.ellipse(medal, r * 0.58, r * 0.58), fill: .ink, line: true),
                    Decor(path: Curve.ellipse(CGPoint(x: medal.x + r * 0.45, y: medal.y - r * 0.45), r * 0.2, r * 0.2), fill: .highlight),
                ]),
            ]))
        }

        if b.limbs != .none {
            let arms = armParts(bean: bean, bodySize: bodySize, head: head, pose: pose, k: k, signWidth: 0.92 * b.body.width + 6)
            let erase = arms.shoulders.applying(bodyT)
                        // Arm roots lose their contour only well inside the body, so the silhouette never breaks.
            let inset = BeanShape(center: bean.center, size: CGSize(width: bodySize.width - 14, height: bodySize.height - 14))
            figure.front.append(TenaFigure.Group(parts: arms.parts.map { moved($0, bodyT) }, erase: erase, eraseClip: inset.path.applying(bodyT)))
            if pose.prop == .bandage, let wrap = arms.wrap {
                figure.front.append(TenaFigure.Group(parts: [moved(wrap, bodyT)]))
            }
        }
        if let wrap = gills.wrap { figure.front.append(TenaFigure.Group(parts: [moved(wrap, headT)])) }
        if pose.prop == .headset {
            figure.front.append(TenaFigure.Group(parts: headset(head: head, face: face).map { moved($0, headT) }))
        }
        return figure
    }

    // MARK: Tail and fin

    func tailParts(bean: BeanShape, bodySize: CGSize, pose: TenaPose, t: Double) -> [Part] {
        let b = build
        let length = CGFloat(b.tail) * b.body.width * 0.74
        let base = CGPoint(x: 100 + 0.40 * bodySize.width, y: bean.center.y + 0.22 * bodySize.height)
        let swing = 4 * sin(2 * .pi * t / 3.1 * pose.breathRate) * envelope(t)
        let tip = base + CGPoint.heading(24 + swing, side: 1) * length
        let p0 = base - CGPoint(x: 10, y: 0)
        let c1 = base + CGPoint.heading(-4, side: 1) * (length * 0.35)
        let c2 = tip - CGPoint.heading(24 + b.tailCurl + swing, side: 1) * (length * 0.32)
        let spine = (0 ... 16).map { Curve.cubic(p0, c1, c2, tip, CGFloat($0) / 16) }
        let root = 0.2 * bodySize.height
        let halfWidth: (CGFloat) -> CGFloat = { s in root * pow(1 - s, 0.85) + 1.2 }
        var tailDecor: [Decor] = []
        if showsDetail {
            tailDecor = freckles(on: .tail, bean: bean, head: nil, tailSpine: spine, tailHalfWidth: halfWidth).map { Decor(path: $0, fill: .mark) }
        }
        let tail = Part(path: Curve.ribbon(spine, halfWidth: halfWidth), fill: .body, decor: tailDecor)
        guard b.dorsal > 0, !b.landForm else { return [tail] }

        // The fin frill: along the tail's upper edge, then up the back as a low crest.
        var outer: [CGPoint] = [], inner: [CGPoint] = []
        let n = spine.count
        let finH = CGFloat(b.dorsal)
        let crest = min(6, finH) * 0.8
        for i in stride(from: n - 2, through: 2, by: -1) {
            let s = CGFloat(i) / CGFloat(n - 1)
            let tangent = (spine[i + 1] - spine[i - 1]).normalized
            let up = CGPoint(x: tangent.y, y: -tangent.x)
            let edge = spine[i] + up * halfWidth(s)
            let rise = min(1, (1 - s) / 0.15)
            let h = (s > 0.45 ? finH : crest + (finH - crest) * s / 0.45) * rise
            outer.append(edge + up * h)
            inner.append(edge - up * 3)
        }
        for a in stride(from: -0.2, through: -0.9, by: -0.1) {
            let p = bean.point(a)
            let out = (p - bean.center).normalized
            let fadeOut = CGFloat(max(0.15, 1 - (-a - 0.2) / 0.75))
            outer.append(p + out * (crest * 0.7 * fadeOut))
            inner.append(p - out * 3)
        }
        let fin = Curve.closed(outer + inner.reversed())
        var finDecor: [Decor] = []
        if b.amberTips {
            let edge = Curve.open(outer).strokedPath(StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            finDecor.append(Decor(path: edge, fill: .amber))
        }
        if lod == .hero {
            var ribs = Path()
            for i in stride(from: 3, to: min(outer.count, 13), by: 2) {
                ribs.move(to: inner[i])
                ribs.addLine(to: inner[i].lerp(outer[i], 0.8))
            }
            finDecor.append(Decor(path: ribs, fill: .shade, line: true))
        }
        return [Part(path: fin, fill: .belly, decor: finDecor), tail]
    }

    // MARK: Legs

    func legParts(bean: BeanShape, bodySize: CGSize, k: CGFloat, legDrop: CGFloat) -> [Part] {
        guard build.limbs == .all else { return [] }
        var parts: [Part] = []
        let toes = lod == .hero ? 5 : (lod == .standard ? 4 : 0)
        for side in [CGFloat(-1), 1] {
            let hip = CGPoint(x: 100 + side * 0.36 * bodySize.width, y: bean.center.y + 0.42 * bodySize.height * 0.9)
            let foot = CGPoint(x: 100 + side * 0.47 * bodySize.width, y: bean.bottom + legDrop)
            var leg = Path()
            leg.move(to: hip)
            leg.addLine(to: foot)
            parts.append(Part(path: leg.strokedPath(StrokeStyle(lineWidth: 11 * k, lineCap: .round)), fill: .body))
            let sole = CGPoint(x: foot.x + side * 2 * k, y: foot.y)
            parts.append(Part(path: Curve.ellipse(sole, 7.6 * k, 4.6 * k), fill: .body))
            for j in 0 ..< toes {
                let spread = toes == 5 ? -6 + 3 * CGFloat(j) : -4.5 + 3 * CGFloat(j)
                let toe = CGPoint(x: sole.x + side * (spread + 1.2) * k, y: sole.y + 3.4 * k)
                parts.append(Part(path: Curve.ellipse(toe, 2.4 * k, 2.4 * k), fill: .body))
            }
        }
        return parts
    }

    // MARK: Front limbs

    struct ArmBuild {
        var parts: [Part]
        var shoulders: Path
        var wrap: Part?
    }

    /// Elbow and hand offsets from the shoulder (right side, x mirrors), per body preset.
    func armOffsets(_ preset: TenaPose.BodyPose.Preset, side: CGFloat) -> (elbow: CGPoint, hand: CGPoint) {
        let right = side > 0
        switch preset {
        case .sit: return (CGPoint(x: 7, y: 9), CGPoint(x: 9, y: 18))
        case .armsUp: return (CGPoint(x: 21, y: -5), CGPoint(x: 29, y: -27))
        case .leanForward: return (CGPoint(x: -4, y: 15), CGPoint(x: -21, y: 17))
        case .tiltReach: return right ? (CGPoint(x: 5, y: 15), CGPoint(x: -12, y: -6)) : (CGPoint(x: 7, y: 9), CGPoint(x: 9, y: 18))
        case .press: return (CGPoint(x: 17, y: -4), CGPoint(x: 22, y: -28))
        case .holdSign: return (CGPoint(x: 9, y: 8), CGPoint(x: 2, y: 13))
        case .slump: return (CGPoint(x: 3, y: 13), CGPoint(x: 2, y: 25))
        case .limp: return right ? (CGPoint(x: 3, y: 13), CGPoint(x: 2, y: 25)) : (CGPoint(x: 4, y: 8), CGPoint(x: 4, y: 14))
        case .regrow: return (CGPoint(x: 7, y: 9), CGPoint(x: 9, y: 18))
        case .hips: return (CGPoint(x: 23, y: 5), CGPoint(x: 6, y: 21))
        case .curled: return (CGPoint(x: 4, y: 6), CGPoint(x: 0, y: 10))
        }
    }

    func armParts(bean: BeanShape, bodySize: CGSize, head: HeadShape, pose: TenaPose, k: CGFloat, signWidth: CGFloat) -> ArmBuild {
        let buds = build.limbs == .buds
        let reach = (buds ? 0.6 : 1) * k * CGFloat(min(build.limbLength, 1.2))
        let tube = (buds ? 8 : 9) * k
        // Small (64 pt) keeps two notches per hand so the palms still read as hands.
        let fingers = showsDetail ? (buds ? 3 : 4) : (lod == .small && !buds ? 2 : 0)
        var parts: [Part] = []
        var shoulders = Path()
        var wrap: Part?
        for side in [CGFloat(-1), 1] {
            let shoulder = CGPoint(x: 100 + side * 0.42 * bodySize.width, y: bean.top + 0.38 * bodySize.height)
            shoulders.addPath(Curve.ellipse(shoulder, tube * 0.95, tube * 0.95))
            let preset = pose.body.preset
            let offsets = armOffsets(buds && preset == .limp ? .slump : preset, side: side)
            var elbow = shoulder + CGPoint(x: side * offsets.elbow.x, y: offsets.elbow.y) * reach
            var hand = shoulder + CGPoint(x: side * offsets.hand.x, y: offsets.hand.y) * reach
            if preset == .holdSign, pose.prop == .sign || !props {
                hand = CGPoint(x: 100 + side * (signWidth / 2 - 1), y: bean.center.y + 0.1 * bodySize.height)
                elbow = shoulder + CGPoint(x: side * 9, y: 6) * reach
            }
            var fill: TenaFigure.Fill = .body
            // Limbless and bud stages (0-2) injure and regrow the top-left gill instead.
            if preset == .regrow, side < 0, !buds {
                let f = CGFloat(0.35 + 0.65 * progress)
                elbow = shoulder.lerp(elbow, f)
                hand = shoulder.lerp(hand, f)
                if progress < 1 { fill = .belly }
            }
            var arm = Path()
            arm.move(to: shoulder)
            arm.addLine(to: elbow)
            arm.addLine(to: hand)
            parts.append(Part(path: arm.strokedPath(StrokeStyle(lineWidth: tube, lineCap: .round, lineJoin: .round)), fill: fill))
            let pressing = preset == .press
            let palm = (pressing ? 6.2 : 4.9) * k * (buds ? 0.8 : 1)
            parts.append(Part(path: Curve.ellipse(hand, palm, palm), fill: fill))
            let showFingers = fingers > 0 && preset != .hips && !(preset == .regrow && side < 0 && !buds && progress < 0.5)
            if showFingers {
                let dir = pressing ? CGPoint(x: side * 0.15, y: -1).normalized : (hand - elbow).normalized
                let fan: [Double] = switch fingers {
                case 2: [-30, 30]
                case 3: [-38, 0, 38]
                default: pressing ? [-54, -18, 18, 54] : [-48, -16, 16, 48]
                }
                let lobe = (pressing ? 3.3 : 3.1) * k
                for a in fan {
                    let c = hand + dir.rotated(a) * (palm + lobe * 0.35)
                    parts.append(Part(path: Curve.ellipse(c, lobe, lobe), fill: fill))
                }
            }
            if preset == .limp, side < 0, !buds {
                let mid = elbow.lerp(hand, 0.35)
                let along = (hand - elbow).normalized
                let across = CGPoint(x: -along.y, y: along.x)
                let hw = tube / 2 + 1.6
                var band = Path()
                band.move(to: mid + across * hw - along * 3.4)
                band.addLine(to: mid + across * hw + along * 3.4)
                band.addLine(to: mid - across * hw + along * 3.4)
                band.addLine(to: mid - across * hw - along * 3.4)
                band.closeSubpath()
                var crease = Path()
                crease.move(to: mid + across * hw)
                crease.addLine(to: mid - across * hw)
                wrap = Part(path: band, fill: .highlight, decor: showsDetail ? [Decor(path: crease, fill: .ink, line: true)] : [])
            }
        }
        return ArmBuild(parts: parts, shoulders: shoulders, wrap: wrap)
    }

    // MARK: Headset

    func headset(head: HeadShape, face: TenaFigure.Face) -> [Part] {
        var top: [CGPoint] = []
        for a in stride(from: 4.0, through: 90, by: 6) { top.append(head.contour(polar: a, side: 1)) }
        for a in stride(from: 84.0, through: 4, by: -6) { top.append(head.contour(polar: a, side: -1)) }
        let band = Curve.open(top.reversed().map { $0 - ($0 - head.center).normalized * 4.6 })
            .strokedPath(StrokeStyle(lineWidth: 4.2, lineCap: .round))
        var parts = [Part(path: band, fill: .amber)]
        var cups: [CGPoint] = []
        for side in [CGFloat(-1), 1] {
            let edge = head.contour(polar: -10, side: side)
            let cup = edge - (edge - head.center).normalized * 6
            cups.append(cup)
            parts.append(Part(path: Curve.ellipse(cup, 6, 8.4), fill: .amber))
        }
        if lod != .small {
            let cup = cups[1]
            let corner = CGPoint(x: face.mouthCenter.x + face.mouthWidth / 2 + 5, y: face.mouthCenter.y - 1)
            var boom = Path()
            boom.move(to: CGPoint(x: cup.x - 1, y: cup.y + 6))
            boom.addQuadCurve(to: corner, control: CGPoint(x: cup.x - 2, y: corner.y + 5))
            parts.append(Part(path: boom.strokedPath(StrokeStyle(lineWidth: 2.2, lineCap: .round)), fill: .ink, contour: false))
            parts.append(Part(path: Curve.ellipse(corner, 3.4, 3), fill: .amber))
        }
        return parts
    }

    // MARK: Freckles

    enum FreckleSite { case head, body, tail }

    /// Mark-pink spots by stage (4 / 6 / 9), on the tail, the flanks and the temples. Never on the face.
    func freckles(on site: FreckleSite, bean: BeanShape, head: HeadShape?, tailSpine: [CGPoint] = [], tailHalfWidth: ((CGFloat) -> CGFloat)? = nil) -> [Path] {
        let count = build.freckles
        guard count > 0, showsDetail else { return [] }
        // (site, a, b, r): tail → spine share + lift; body → offsets in body units; head → offsets in head units.
        let all: [(FreckleSite, CGFloat, CGFloat, CGFloat)] = [
            (.tail, 0.35, 0.25, 3.0), (.tail, 0.6, 0.1, 2.5), (.head, 0.36, -0.3, 2.6), (.head, -0.37, -0.28, 2.6),
            (.body, 0.36, -0.1, 2.4), (.tail, 0.8, 0.2, 1.9),
            (.head, -0.22, -0.4, 2.0), (.head, 0.24, -0.41, 1.9), (.body, -0.37, -0.04, 2.2),
        ]
        var out: [Path] = []
        for (spot, a, b, r) in all.prefix(count) where spot == site {
            switch site {
            case .tail:
                guard tailSpine.count > 2, let hw = tailHalfWidth else { continue }
                let i = Int(a * CGFloat(tailSpine.count - 1))
                let tangent = (tailSpine[min(i + 1, tailSpine.count - 1)] - tailSpine[max(i - 1, 0)]).normalized
                let up = CGPoint(x: tangent.y, y: -tangent.x)
                out.append(Curve.ellipse(tailSpine[i] + up * (hw(a) * b * 2), r, r * 0.9))
            case .body:
                out.append(Curve.ellipse(CGPoint(x: bean.center.x + a * bean.size.width, y: bean.center.y + b * bean.size.height), r, r * 0.9))
            case .head:
                guard let head else { continue }
                out.append(Curve.ellipse(CGPoint(x: head.center.x + a * head.size.width, y: head.center.y + b * head.size.height), r, r * 0.9))
            }
        }
        return out
    }

    // MARK: Bust (Glyph tier)

    /// Head and gills only, cut at the chin: the 28-55 pt tier reads the mood from eyes, mouth and gills.
    func bustFigure(pose: TenaPose, time t: Double) -> TenaFigure {
        let head = HeadShape(center: CGPoint(x: 100, y: 80), size: build.head)
        let headT = about(head.center, CGAffineTransform(rotationAngle: (pose.tilt * 0.6 + sway(t)) * .pi / 180))
        let gills = fronds(head: head, pose: pose, time: t, options: FrondOptions(lengthScale: 0.92))
        var parts = gills.parts.map { moved($0, headT) }
        parts.append(moved(Part(path: head.path, fill: .body, decor: crown(head: head)), headT))
        let face = faceAnchors(head: head, pose: pose)
        if build.landForm {
            for eye in face.eyes {
                parts.append(moved(Part(path: Curve.ellipse(CGPoint(x: eye.x, y: eye.y - 1), beadRadius.width * 1.95, beadRadius.height * 1.8), fill: .body), headT))
            }
        }
        var figure = TenaFigure()
        figure.groups = [TenaFigure.Group(parts: parts)]
        figure.face = face
        figure.headTransform = headT
        return figure
    }

    // MARK: Curled (Asleep)

    /// Lying on her side in a C-curl, head resting on the tail.
    func curledFigure(pose: TenaPose, time t: Double) -> TenaFigure {
        let b = build
        let head = HeadShape(center: CGPoint(x: 80, y: 108), size: b.head)
        let lying = CGSize(width: b.body.width * 1.25, height: b.body.height * 0.8)
        let bean = BeanShape(center: CGPoint(x: head.center.x + 0.42 * b.head.width + 0.18 * lying.width, y: head.chin - 0.3 * lying.height), size: lying)
        let br = CGFloat(breath(t, rate: pose.breathRate)) * 0.015
        let bodyT = about(CGPoint(x: bean.center.x, y: bean.bottom), CGAffineTransform(scaleX: 1, y: 1 + br))
        let headT = about(head.center, CGAffineTransform(rotationAngle: (-8 + sway(t) * 0.4) * .pi / 180))
            .concatenating(CGAffineTransform(translationX: 0, y: -lying.height * br))

        // The tail leaves the hip at the far end, arcs round the rump and back under the body, and its
        // tapered tip curls up in front of the chin, where her head rests on it.
        let reach = CGFloat(0.5 + 0.5 * min(b.tail, 1.3))
        let arcC = CGPoint(x: bean.center.x + 0.04 * lying.width, y: bean.center.y + 0.12 * lying.height)
        let arcR = CGSize(width: 0.5 * lying.width + 6 * reach, height: 0.5 * lying.height + 5)
        var spine: [CGPoint] = stride(from: -28.0, through: 150, by: 8).map { deg in
            let a = deg * .pi / 180
            return CGPoint(x: arcC.x + arcR.width * CGFloat(cos(a)), y: arcC.y + arcR.height * CGFloat(sin(a)))
        }
        let chin = CGPoint(x: head.center.x + 0.16 * b.head.width, y: head.chin + 5)
        let last = spine[spine.count - 1]
        spine.append(last.lerp(chin, 0.5) + CGPoint(x: 0, y: 3))
        spine.append(chin + CGPoint(x: -4, y: -2))
        spine = smoothed(smoothed(spine))
        let root = 0.125 * b.body.height
        let halfWidth: (CGFloat) -> CGFloat = { s in root * pow(1 - s, 1.1) + 0.7 }
        var front: [Part] = []
        if b.dorsal > 0, !b.landForm {
            var outer: [CGPoint] = [], inner: [CGPoint] = []
            for i in 1 ..< spine.count - 1 {
                let s = CGFloat(i) / CGFloat(spine.count - 1)
                let tangent = (spine[i + 1] - spine[i - 1]).normalized
                let out = CGPoint(x: -tangent.y, y: tangent.x)
                let edge = spine[i] + out * halfWidth(s)
                let h = CGFloat(b.dorsal) * 1.15 * min(1, s / 0.25) * pow(min(1, (1 - s) / 0.35), 0.8)
                outer.append(edge + out * h)
                inner.append(edge - out * 3)
            }
            var decor: [Decor] = []
            if b.amberTips {
                decor.append(Decor(path: Curve.open(outer).strokedPath(StrokeStyle(lineWidth: 5, lineCap: .round)), fill: .amber))
            }
            if showsDetail {
                // Two fin ribs in shade pink so the frill reads as a fin, not a rim.
                var ribs = Path()
                for k in [outer.count * 2 / 5, outer.count * 3 / 5] where k < outer.count {
                    ribs.move(to: inner[k])
                    ribs.addLine(to: inner[k].lerp(outer[k], 0.85))
                }
                decor.append(Decor(path: ribs, fill: .shade, line: true))
            }
            front.append(Part(path: Curve.closed(outer + inner.reversed()), fill: .belly, decor: decor))
        }
        // The tail sits behind the body, so the body rests in its curl with no cut root.
        front.append(Part(path: Curve.ribbon(spine, halfWidth: halfWidth), fill: .body))
        let back = front + [moved(Part(path: bean.path, fill: .body, decor: [
            Decor(path: Curve.ellipse(CGPoint(x: bean.center.x - 0.08 * lying.width, y: bean.bottom), lying.width * 0.34, lying.height * 0.32), fill: .belly),
        ]), bodyT)]
        let gills = fronds(head: head, pose: pose, time: t)
        var headParts = gills.parts.map { moved($0, headT) }
        headParts.append(moved(Part(path: head.path, fill: .body, decor: crown(head: head)), headT))
        let face = faceAnchors(head: head, pose: pose)
        if b.landForm {
            for eye in face.eyes {
                headParts.append(moved(Part(path: Curve.ellipse(CGPoint(x: eye.x, y: eye.y - 1), beadRadius.width * 1.95, beadRadius.height * 1.8), fill: .body), headT))
            }
        }
        var figure = TenaFigure()
        figure.groups = [TenaFigure.Group(parts: back), TenaFigure.Group(parts: headParts)]
        figure.face = face
        figure.headTransform = headT
        if pose.prop == .sleepZ, lod != .glyph {
            // One small z above her back, clear of the gills; it drifts up slowly.
            let rise = CGFloat((t / 4.0).truncatingRemainder(dividingBy: 1)) * 5 * CGFloat(envelope(t))
            let anchor = CGPoint(x: bean.center.x + 0.4 * lying.width, y: bean.top - 12 - rise)
            let s: CGFloat = 8
            var z = Path()
            z.move(to: anchor)
            z.addLine(to: CGPoint(x: anchor.x + s, y: anchor.y))
            z.addLine(to: CGPoint(x: anchor.x, y: anchor.y + s))
            z.addLine(to: CGPoint(x: anchor.x + s, y: anchor.y + s))
            figure.inkLines = [z]
        }
        return figure
    }

    /// One pass of corner cutting so a polyline spine bends smoothly.
    func smoothed(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count > 2 else { return points }
        var out = [points[0]]
        for i in 1 ..< points.count - 1 {
            out.append(points[i - 1].lerp(points[i], 0.5).lerp(points[i].lerp(points[i + 1], 0.5), 0.5))
        }
        out.append(points[points.count - 1])
        return out
    }
}
