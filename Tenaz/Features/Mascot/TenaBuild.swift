import CoreGraphics

/// How a growth stage changes the rig (rules §3): stages differ by proportion, not zoom. Sizes are in
/// the 200-unit construction grid; Juvenile is the reference. The rig fits the result into its box.
struct TenaBuild {
    enum GillShape: Equatable {
        /// Short rounded stubs (egg, hatchling, metamorph).
        case nub
        /// Tapered tubes with a few short notches on the upper edge (larva, and every stage at Small size).
        case tube(notches: Int)
        /// Tapered fronds with filament fingers on the upper edge.
        case fringe(Int)
    }

    enum Limbs { case none, buds, front, all }

    var head: CGSize
    var body: CGSize
    var eyeScale: Double
    /// Top, mid and low frond length as a share of head width.
    var gillLengths: [Double]
    var gillShape: GillShape
    /// Elder: the last 25 % of every frond and the fin edge turn amber.
    var amberTips = false
    /// Degrees the fans sweep further back (Elder).
    var gillSweep: Double = 0
    var limbs: Limbs
    /// Tail length as a share of body width.
    var tail: Double
    /// Upward curl of the tail tip in degrees.
    var tailCurl: Double = 0
    /// Height of the fin frill along the tail and the back (0 = no fin).
    var dorsal: Double
    /// Freckles in mark pink besides the crown (which is always there).
    var freckles: Int
    /// Metamorph: raised, bulging eyes, no fin, longer standing legs, deeper marks.
    var landForm = false
    /// Limb length multiplier (longer forearms on adults, standing legs on the metamorph).
    var limbLength: Double = 1

    /// Top-frond length; mid and low follow the 1 : 0.88 : 0.7 hierarchy.
    private static func gills(_ top: Double) -> [Double] { [top, top * 0.88, top * 0.7] }

    static func `for`(_ stage: TenaStage) -> TenaBuild {
        switch stage {
        case .egg:
            TenaBuild(head: CGSize(width: 56, height: 36), body: CGSize(width: 40, height: 30), eyeScale: 1.2,
                      gillLengths: gills(0.12), gillShape: .nub, limbs: .none, tail: 0.5, dorsal: 0, freckles: 0)
        case .hatchling:
            TenaBuild(head: CGSize(width: 120, height: 84), body: CGSize(width: 50, height: 34), eyeScale: 1.25,
                      gillLengths: gills(0.16), gillShape: .nub, limbs: .none, tail: 0.5, tailCurl: 10, dorsal: 3, freckles: 0)
        case .larva:
            TenaBuild(head: CGSize(width: 122, height: 82), body: CGSize(width: 58, height: 40), eyeScale: 1.15,
                      gillLengths: gills(0.24), gillShape: .tube(notches: 2), limbs: .buds, tail: 0.8, dorsal: 4, freckles: 0)
        case .juvenile:
            TenaBuild(head: CGSize(width: 124, height: 80), body: CGSize(width: 72, height: 52), eyeScale: 1,
                      gillLengths: gills(0.34), gillShape: .fringe(4), limbs: .all, tail: 1, dorsal: 6, freckles: 0)
        case .subAdult:
            TenaBuild(head: CGSize(width: 126, height: 78), body: CGSize(width: 80, height: 60), eyeScale: 0.92,
                      gillLengths: gills(0.40), gillShape: .fringe(5), limbs: .all, tail: 1.15, tailCurl: 22, dorsal: 7,
                      freckles: 4, limbLength: 1.08)
        case .adult:
            TenaBuild(head: CGSize(width: 128, height: 76), body: CGSize(width: 86, height: 66), eyeScale: 0.86,
                      gillLengths: gills(0.46), gillShape: .fringe(5), limbs: .all, tail: 1.3, tailCurl: 18, dorsal: 10,
                      freckles: 6, limbLength: 1.18)
        case .elder:
            TenaBuild(head: CGSize(width: 128, height: 76), body: CGSize(width: 86, height: 66), eyeScale: 0.86,
                      gillLengths: gills(0.52), gillShape: .fringe(5), amberTips: true, gillSweep: 8, limbs: .all,
                      tail: 1.3, tailCurl: 18, dorsal: 10, freckles: 6, limbLength: 1.18)
        case .metamorph:
            TenaBuild(head: CGSize(width: 118, height: 78), body: CGSize(width: 88, height: 76), eyeScale: 0.95,
                      gillLengths: gills(0.12), gillShape: .nub, limbs: .all, tail: 0.8, tailCurl: 8, dorsal: 0,
                      freckles: 9, landForm: true, limbLength: 1.3)
        }
    }
}
