import CoreGraphics

/// Everything the rig needs to draw one mood (rules §8-9): eye state, mouth, gill posture, body pose
/// and at most one prop. Every channel is numeric so moods can interpolate.
struct TenaPose {
    /// Bead eyes act only through lids (no brows, no size changes).
    struct EyeState {
        enum Closed { case up, down }
        enum Glyph { case star, ring }

        /// Upper-lid cover, 0 (wide) ... 0.7.
        var lid: Double = 0.1
        /// Degrees; + = inner corner down (cross), - = inner corner up (worried / sad).
        var lidAngle: Double = 0
        /// Lower-lid push from below, 0 ... 0.45 (smiling eyes).
        var lowerLid: Double = 0
        /// `.up` = ^ ^ arcs, `.down` = sleeping arcs.
        var closed: Closed?
        /// Bead shift as a share of the eye radius; +x right, +y down.
        var gaze = CGVector.zero
        /// Bead scale. Direction A keeps beads within 0.9 ... 1.1; a stare shrinks the gloss instead.
        var pupilScale: Double = 1
        /// Direction C only; A ignores it.
        var glyph: Glyph?
        /// A second, smaller gloss dot (Sad's wet eye).
        var wet = false
    }

    /// One 6-point path (two anchors, four controls), so every mouth interpolates into every other.
    struct MouthShape {
        /// Share of head width, 0.20 ... 0.62.
        var width: Double = 0.60
        /// -1 (corners down) ... +1 (corners up).
        var curve: Double = 0.3
        /// 0 = a line; 1 = fully open (filled interior).
        var open: Double = 0
        /// + lifts the right corner, drops the left.
        var skew: Double = 0
        var tongue = false
        /// 0 = D shape (flat upper lip), 1 = O shape (upper lip arches up).
        var round: Double = 0
        /// 0 = soft lower lip, 1 = squarish (the insisting Nagging mouth).
        var square: Double = 0
        /// Wave amplitude for the queasy Sick line, 0 ... 1.
        var wave: Double = 0
        /// Sideways shift as a share of head width (Curious looks toward the subject).
        var offset: Double = 0
    }

    struct GillPose {
        /// Degrees added to the top, mid and low frond axes (+ = perked up).
        var lift: [Double] = [0, 0, 0]
        /// Fan spread multiplier around the mid frond.
        var spread: Double = 1
        /// 0 = wiggles freely, 1 = rigid.
        var stiffness: Double = 0
        /// Degrees the tips curl down.
        var curl: Double = 0
        /// Degrees added to the right fan and taken from the left.
        var asymmetry: Double = 0
        /// Length multiplier (Sick hangs limp and short).
        var length: Double = 1
    }

    struct BodyPose {
        enum Preset { case sit, armsUp, leanForward, tiltReach, press, holdSign, slump, limp, regrow, hips, curled }

        var preset: Preset = .sit
        /// Sideways lean in degrees (+ = toward the right, where the content usually sits).
        var lean: Double = 0
        /// Lean toward (+) or away from (-) the viewer, in degrees: the head drops or lifts.
        var forward: Double = 0
        /// Width and height multipliers on the body.
        var squash = CGSize(width: 1, height: 1)
    }

    var eye = EyeState()
    /// The right eye when it differs (Curious near eye, Sick's mismatched lids).
    var rightEye: EyeState?
    var mouth = MouthShape()
    var gills = GillPose()
    var body = BodyPose()
    var prop: TenaProp?
    /// Gill wiggle amplitude in degrees.
    var wiggle: Double = 4
    var breathRate: Double = 1
    /// Head tilt in degrees (+ = clockwise, toward the right).
    var tilt: Double = 0
    /// 0 = full colour, 1 = washed out (Sick uses 0.35).
    var fade: Double = 0

    static func `for`(_ mood: TenaMood) -> TenaPose {
        var p = TenaPose()
        switch mood {
        case .ecstatic:
            p.eye = EyeState(lid: 0, closed: .up)
            p.mouth = MouthShape(width: 0.60, curve: 0.55, open: 1, tongue: true)
            p.gills = GillPose(lift: [14, 14, 14], spread: 1.1)
            p.body = BodyPose(preset: .armsUp, squash: CGSize(width: 0.96, height: 1.06))
            p.wiggle = 9
            p.breathRate = 1.6
        case .happy:
            p.eye = EyeState(lid: 0, lowerLid: 0.45)
            p.mouth = MouthShape(width: 0.60, curve: 0.6)
            p.gills = GillPose(lift: [10, 10, 10])
            p.body = BodyPose(preset: .sit, lean: 4)
            p.wiggle = 6
        case .focused:
            p.eye = EyeState(lid: 0.4, gaze: CGVector(dx: 0, dy: 0.15))
            p.mouth = MouthShape(width: 0.50, curve: 0)
            p.gills = GillPose(lift: [-6, -6, -6], stiffness: 0.3)
            p.body = BodyPose(preset: .leanForward, forward: 6)
            p.prop = .headset
            p.wiggle = 3
            p.breathRate = 0.9
        case .curious:
            p.eye = EyeState(lid: 0, gaze: CGVector(dx: 0.2, dy: -0.2))
            var near = p.eye
            near.pupilScale = 1.1
            p.rightEye = near
            p.mouth = MouthShape(width: 0.25, curve: 0, open: 0.65, round: 1, offset: 0.06)
            p.gills = GillPose(asymmetry: 12)
            p.body = BodyPose(preset: .tiltReach, lean: 3)
            p.tilt = 10
            p.wiggle = 5
        case .neutral:
            p.wiggle = 4
        case .hungry:
            p.eye = EyeState(lid: 0.22, lidAngle: -12, gaze: CGVector(dx: 0, dy: -0.12))
            p.mouth = MouthShape(width: 0.40, curve: -0.45, open: 0.62, round: 0.35)
            p.gills = GillPose(lift: [-4, -4, -4])
            p.body = BodyPose(preset: .press, forward: 4)
            p.wiggle = 4
        case .nagging:
            p.eye = EyeState(lid: 0.3, lidAngle: 18, pupilScale: 0.45)
            p.mouth = MouthShape(width: 0.50, curve: -0.1, open: 0.55, square: 1)
            p.gills = GillPose(lift: [12, 12, 12], stiffness: 1)
            p.body = BodyPose(preset: .holdSign, forward: 8)
            p.prop = .sign
            p.wiggle = 0
            p.breathRate = 1.4
        case .sad:
            p.eye = EyeState(lid: 0.45, lidAngle: -20, gaze: CGVector(dx: 0, dy: 0.2), wet: true)
            p.mouth = MouthShape(width: 0.30, curve: -0.65)
            p.gills = GillPose(lift: [-24, -24, -24], spread: 0.9)
            p.body = BodyPose(preset: .slump, squash: CGSize(width: 1.06, height: 0.94))
            p.wiggle = 2
            p.breathRate = 0.7
        case .sick:
            p.eye = EyeState(lid: 0.5)
            var heavy = p.eye
            heavy.lid = 0.6
            p.rightEye = heavy
            p.mouth = MouthShape(width: 0.40, curve: -0.1, wave: 1)
            p.gills = GillPose(lift: [-20, -20, -20], curl: 10, length: 0.92)
            p.body = BodyPose(preset: .limp, squash: CGSize(width: 1.04, height: 0.96))
            p.prop = .bandage
            p.wiggle = 1.5
            p.breathRate = 0.6
            p.fade = 0.35
        case .regenerating:
            // Effort, eyes on the regrowing (left) limb: head tipped toward it, one mouth corner tucked up.
            p.eye = EyeState(lid: 0.25, gaze: CGVector(dx: -0.22, dy: 0.22))
            p.mouth = MouthShape(width: 0.54, curve: 0.05, skew: 0.65)
            p.tilt = -4
            p.gills = GillPose(lift: [4, 4, 4])
            p.body = BodyPose(preset: .regrow)
            p.wiggle = 3
            p.breathRate = 0.8
        case .proud:
            p.eye = EyeState(lid: 0.55, lowerLid: 0.3)
            p.mouth = MouthShape(width: 0.62, curve: 0.6, skew: 0.3)
            p.gills = GillPose(lift: [10, 10, 10], spread: 0.92)
            p.body = BodyPose(preset: .hips, forward: -5)
            p.prop = .medal
            p.wiggle = 5
        case .asleep:
            p.eye = EyeState(lid: 0, closed: .down)
            p.mouth = MouthShape(width: 0.20, curve: 0, open: 0.5, round: 1)
            p.gills = GillPose(lift: [-10, -10, -10], curl: 30)
            p.body = BodyPose(preset: .curled)
            p.prop = .sleepZ
            p.wiggle = 1.5
            p.breathRate = 0.5
        }
        return p
    }
}

/// Worn objects and actions (rules §12). Never emoji.
enum TenaProp {
    /// Focused: a tiny headset, band between the gill fans, boom to the mouth corner.
    case headset
    /// Nagging: a card with the due word, held at chest height.
    case sign
    /// Sick: a wrap on the injured limb (a gill on limbless stages), never the forehead.
    case bandage
    /// Proud: a small medal on a ribbon (Standard and Hero only).
    case medal
    /// Asleep: one small "z".
    case sleepZ
}
