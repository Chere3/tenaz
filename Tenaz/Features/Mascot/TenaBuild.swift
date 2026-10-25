/// How a growth stage changes the rig: proportions, gill size, limbs, markings.
struct TenaBuild {
    var scale: Double
    var gillLength: Double
    var gillFilaments: Int
    var gillCount: Int
    var arms: Bool
    var legs: Bool
    var tailLength: Double
    var spots: Int
    var golden = false
    var landForm = false
    /// Head width multiplier (hatchlings are almost all head).
    var headWidth: Double = 1
    var bodySize: Double = 1
    var eyeSize: Double = 1

    static func `for`(_ stage: TenaStage) -> TenaBuild {
        switch stage {
        case .egg:
            TenaBuild(scale: 1, gillLength: 0.3, gillFilaments: 0, gillCount: 3, arms: false, legs: false, tailLength: 0.5, spots: 0)
        case .hatchling:
            TenaBuild(scale: 0.66, gillLength: 0.42, gillFilaments: 0, gillCount: 3, arms: false, legs: false, tailLength: 0.7, spots: 0, headWidth: 1.04, bodySize: 0.7, eyeSize: 1.35)
        case .larva:
            TenaBuild(scale: 0.76, gillLength: 0.6, gillFilaments: 2, gillCount: 3, arms: true, legs: false, tailLength: 0.95, spots: 0, bodySize: 0.85, eyeSize: 1.2)
        case .juvenile:
            TenaBuild(scale: 0.86, gillLength: 0.8, gillFilaments: 3, gillCount: 3, arms: true, legs: false, tailLength: 1, spots: 0, eyeSize: 1.1)
        case .subAdult:
            TenaBuild(scale: 0.93, gillLength: 0.95, gillFilaments: 3, gillCount: 3, arms: true, legs: true, tailLength: 1.05, spots: 3)
        case .adult:
            TenaBuild(scale: 1, gillLength: 1.1, gillFilaments: 4, gillCount: 3, arms: true, legs: true, tailLength: 1.15, spots: 6)
        case .elder:
            TenaBuild(scale: 1, gillLength: 1.25, gillFilaments: 5, gillCount: 3, arms: true, legs: true, tailLength: 1.2, spots: 7, golden: true)
        case .metamorph:
            TenaBuild(scale: 0.98, gillLength: 0.32, gillFilaments: 0, gillCount: 3, arms: true, legs: true, tailLength: 0.9, spots: 9, landForm: true, headWidth: 0.86, bodySize: 1.08, eyeSize: 1.25)
        }
    }
}
