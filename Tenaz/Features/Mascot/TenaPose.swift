/// Everything the rig needs to draw one mood: face parts, props, and how the gills and body carry it.
struct TenaPose {
    var eyes: TenaEyes
    var brows: TenaBrows
    var mouth: TenaMouth
    var extras: [TenaExtra] = []
    var blush = true
    /// Gill tilt in degrees: positive = perked up, negative = drooping.
    var gillLift: Double = 0
    /// Gill wiggle amplitude (degrees) and speed.
    var wiggle: Double = 5
    var breathRate: Double = 1
    /// Head tilt in degrees.
    var tilt: Double = 0
    /// Bounce height multiplier for the idle float.
    var bounce: Double = 1
    /// 0 = full ink, 1 = faded (sick).
    var fade: Double = 0

    static func `for`(_ mood: TenaMood) -> TenaPose {
        switch mood {
        case .ecstatic:
            TenaPose(eyes: .happy, brows: .raised, mouth: .grin, extras: [.sparkles], gillLift: 14, wiggle: 9, breathRate: 1.6, bounce: 2)
        case .happy:
            TenaPose(eyes: .sparkle, brows: .none, mouth: .smile, gillLift: 6, wiggle: 6)
        case .focused:
            TenaPose(eyes: .focused, brows: .focused, mouth: .flat, extras: [.headband], wiggle: 3, breathRate: 0.9, bounce: 0.5)
        case .curious:
            TenaPose(eyes: .sparkle, brows: .quizzical, mouth: .open, extras: [.question], gillLift: 4, tilt: -9)
        case .neutral:
            TenaPose(eyes: .open, brows: .none, mouth: .smile, blush: false, wiggle: 4)
        case .hungry:
            TenaPose(eyes: .open, brows: .worried, mouth: .open, extras: [.drool, .growl], gillLift: -4, wiggle: 4)
        case .nagging:
            TenaPose(eyes: .open, brows: .angry, mouth: .wobble, extras: [.alarm], blush: false, gillLift: 12, wiggle: 8, breathRate: 1.4, tilt: 5)
        case .sad:
            TenaPose(eyes: .droopy, brows: .worried, mouth: .frown, extras: [.tear], blush: false, gillLift: -16, wiggle: 2, breathRate: 0.7, bounce: 0.4)
        case .sick:
            TenaPose(eyes: .swirl, brows: .worried, mouth: .wobble, extras: [.bandage], blush: false, gillLift: -20, wiggle: 1.5, breathRate: 0.6, bounce: 0.3, fade: 0.35)
        case .regenerating:
            TenaPose(eyes: .happy, brows: .none, mouth: .smile, extras: [.regrowth, .bandage], gillLift: -4, wiggle: 3, breathRate: 0.8)
        case .proud:
            TenaPose(eyes: .happy, brows: .raised, mouth: .smile, extras: [.medal], gillLift: 10, wiggle: 5, tilt: 4)
        case .asleep:
            TenaPose(eyes: .sleepy, brows: .none, mouth: .flat, extras: [.sleepZ], gillLift: -10, wiggle: 1.5, breathRate: 0.5, bounce: 0.6)
        }
    }
}
