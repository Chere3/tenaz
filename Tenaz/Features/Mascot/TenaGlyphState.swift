/// The menu-bar glyph's states, told apart by shape, never by colour (PLAN F8, F12).
enum TenaGlyphState: CaseIterable {
    case normal, due, hungry, sick, asleep

    init(mood: TenaMood, dueCount: Int) {
        switch mood {
        case .asleep: self = .asleep
        case .sick: self = .sick
        case .hungry, .nagging: self = .hungry
        default: self = dueCount > 0 ? .due : .normal
        }
    }
}
