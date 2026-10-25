/// Growth stages 0-7 (PLAN F8). Raw values are the stage numbers.
enum TenaStage: Int, CaseIterable, Identifiable, Sendable {
    case egg = 0, hatchling, larva, juvenile, subAdult, adult, elder, metamorph

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .egg: "Egg"
        case .hatchling: "Hatchling"
        case .larva: "Larva"
        case .juvenile: "Juvenile"
        case .subAdult: "Sub-adult"
        case .adult: "Adult"
        case .elder: "Elder"
        case .metamorph: "Metamorph"
        }
    }
}
