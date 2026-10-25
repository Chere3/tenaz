import SwiftUI

extension SelfTest {
    /// `--tenaz-selftest mascot`: the rig's guarantees that the snapshots and crops rely on. Every idle
    /// channel is zero at time 0 (all moods and stages); the cached resting layout matches a fresh build;
    /// arm frames and the bare head sit inside her ink and inside the frame; the time-0 geometry is
    /// identical on every build. `--tenaz-selftest mascot-dump` prints the resting frames per mood instead.
    static func mascot(dump: Bool = false) -> Int32 {
        if dump {
            for size in [CGFloat(160), 520, 1100] {
                for mood in TenaMood.allCases {
                    let rig = TenaRig(mood: mood, stage: .juvenile, time: 0, size: size)
                    let r = rig.rest
                    func f(_ v: CGFloat?) -> String { v.map { String(format: "%.3f", $0) } ?? "-" }
                    print("\(Int(size)) \(mood.rawValue) ink y \(f(r.ink.minY))-\(f(r.ink.maxY)) x \(f(r.ink.minX))-\(f(r.ink.maxX)) "
                        + "arms y-max \(f(r.arms?.maxY)) head y \(f(r.head?.minY))-\(f(r.head?.maxY)) feet \(f(r.feet)) "
                        + "cut(4.5%) \(f(TenaInk.bottomCut(stage: .juvenile, mood: mood, size: size, margin: 0.045 * size / 0.74)))")
                }
            }
            return 0
        }
        var checks: [(String, Bool)] = []
        var still = true, inside = true
        for stage in TenaStage.allCases {
            for mood in TenaMood.allCases {
                let rig = TenaRig(mood: mood, stage: stage, time: 0, size: 160)
                let pose = rig.livePose
                let channels = [rig.wiggle(0, side: 1, pose: pose, t: 0), rig.blink(0), rig.envelope(0), rig.sway(0),
                                rig.gazeDrift(0).dx, rig.gazeDrift(0).dy, Double(rig.hop(0).lift), rig.breath(0, rate: pose.breathRate)]
                if channels.contains(where: { $0 != 0 }) || rig.hop(0).squash != CGSize(width: 1, height: 1) {
                    still = false
                    print("FAIL moving at t=0: \(stage.title) \(mood.rawValue) \(channels)")
                }
                let frame = CGRect(x: 0, y: 0, width: 1, height: 1).insetBy(dx: -0.001, dy: -0.001)
                let ink = rig.inkFrame.insetBy(dx: -0.001, dy: -0.001)
                for (name, r) in [("arms", rig.armFrame), ("head", rig.rest.skull)] {
                    guard let r, !(frame.contains(r) && ink.contains(r)) else { continue }
                    inside = false
                    print("FAIL \(name) frame outside: \(stage.title) \(mood.rawValue) \(r) ink \(rig.inkFrame)")
                }
            }
        }
        checks.append(("idleChannelsZeroAtTimeZero", still))
        checks.append(("armAndHeadFramesInsideInk", inside))

        // The cache returns what a fresh build gives (sizes on both sides of the 1.4 pt ink floor).
        var cached = true
        for size in [CGFloat(64), 160, 520] {
            for mood in TenaMood.allCases {
                let rig = TenaRig(mood: mood, stage: .adult, time: 0, size: size)
                let a = rig.rest, b = rig.measureRest()
                if a.ink != b.ink || a.scale != b.scale || a.offset != b.offset || a.arms != b.arms || a.skull != b.skull { cached = false }
            }
        }
        checks.append(("restLayoutStable", cached))

        // The geometry at time 0 is the same on every build (no clock, no random, no string hashes). Pixels
        // are compared across processes instead (two `--tenaz-snapshot mascot-qa` runs, same md5): in one
        // process the GPU rasteriser varies a few antialiased pixels between passes, Tena or not.
        var same = true
        for stage in TenaStage.allCases {
            for mood in TenaMood.allCases {
                for size in [CGFloat(36), 64, 160, 520] {
                    let rig = TenaRig(mood: mood, stage: stage, time: 0, size: size, word: "levera")
                    func trace() -> String {
                        let f = rig.figure(pose: rig.livePose, time: 0)
                        return (f.groups + f.front).flatMap(\.parts).map(\.path.description).joined()
                            + f.inkLines.map(\.description).joined()
                    }
                    if trace() != trace() {
                        same = false
                        print("FAIL geometry differs: \(stage.title) \(mood.rawValue) \(Int(size))")
                    }
                }
            }
        }
        checks.append(("geometryDeterministicAtTimeZero", same))

        for (name, ok) in checks { print("\(ok ? "ok  " : "FAIL") \(name)") }
        return checks.allSatisfy(\.1) ? 0 : 1
    }
}
