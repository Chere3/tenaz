import Foundation

/// The idle loop (rules §13). Every channel is exactly zero at time 0, so snapshots show the resting pose.
/// Jitter is seeded from a fixed number per mood and the stage, never from string hashes (those change
/// per process) or the enum's case order (reordering `allCases` must not move a blink).
extension TenaRig {
    var seed: Double { Self.moodSeed(mood) + Double(stage.rawValue) * 0.37 }

    static func moodSeed(_ mood: TenaMood) -> Double {
        switch mood {
        case .ecstatic: 0
        case .happy: 1
        case .focused: 2
        case .curious: 3
        case .neutral: 4
        case .hungry: 5
        case .nagging: 6
        case .sad: 7
        case .sick: 8
        case .regenerating: 9
        case .proud: 10
        case .asleep: 11
        }
    }

    /// Ramps the oscillators in over the first 0.6 s so time 0 is still.
    func envelope(_ t: Double) -> Double { min(1, max(0, t / 0.6)) }

    /// 0 ... 1, period 2.8 s times the mood rate.
    func breath(_ t: Double, rate: Double) -> Double { (1 - cos(2 * .pi * t / 2.8 * rate)) / 2 }

    /// Gill wiggle in degrees for frond `i` (0 = top, which leads), quarter-cycle offsets.
    func wiggle(_ i: Int, side: CGFloat, pose: TenaPose, t: Double) -> Double {
        let amp = pose.wiggle * (1 - pose.gills.stiffness)
        guard amp > 0, t > 0 else { return 0 }
        let phase = 2 * .pi * (0.55 * pose.breathRate * t - Double(i) * 0.25) + (side > 0 ? 0.5 : 0)
        return amp * envelope(t) * sin(phase)
    }

    /// Head sway: 1.5° over 5.2 s.
    func sway(_ t: Double) -> Double { 1.5 * sin(2 * .pi * t / 5.2) }

    /// Gaze drift: ±0.06 of the eye radius, slow.
    func gazeDrift(_ t: Double) -> CGVector {
        CGVector(dx: 0.06 * sin(2 * .pi * t / 9.1), dy: 0.04 * sin(2 * .pi * t / 7.3))
    }

    private func hash(_ k: Double, _ salt: Double) -> Double {
        let v = sin(k * 12.9898 + seed * 78.233 + salt * 37.719) * 43758.5453
        return v - floor(v)
    }

    /// 0 = open, 1 = shut. Close 90 ms, hold 40 ms, open 120 ms; every 3.2-6.0 s; double blink 15 %.
    func blink(_ t: Double) -> Double {
        guard t > 0 else { return 0 }
        let slot = 4.6
        let k = floor(t / slot)
        func shape(_ d: Double) -> Double {
            switch d {
            case ..<0: 0
            case ..<0.09: d / 0.09
            case ..<0.13: 1
            case ..<0.25: 1 - (d - 0.13) / 0.12
            default: 0
            }
        }
        var best = 0.0
        for j in [k - 1, k] where j >= 0 {
            let start = j * slot + 0.6 + 1.4 * hash(j, 1)
            best = max(best, shape(t - start))
            if hash(j, 2) < 0.15 { best = max(best, shape(t - start - 0.32)) }
        }
        return best
    }

    /// Ecstatic hops 6 units every 1.4 s and lands with an 80 ms squash.
    func hop(_ t: Double) -> (lift: CGFloat, squash: CGSize) {
        guard t > 0, mood == .ecstatic else { return (0, CGSize(width: 1, height: 1)) }
        let phase = (t / 1.4).truncatingRemainder(dividingBy: 1)
        if phase < 0.5 { return (CGFloat(6 * sin(.pi * phase / 0.5)), CGSize(width: 1, height: 1)) }
        if phase < 0.557 { return (0, CGSize(width: 1.06, height: 0.92)) }
        return (0, CGSize(width: 1, height: 1))
    }
}
