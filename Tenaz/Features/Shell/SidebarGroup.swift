/// The sidebar's three groups, in order.
enum SidebarGroup: String, CaseIterable, Identifiable {
    case learn = "Learn"
    case progress = "Progress"
    case setup = "Setup"

    var id: String { rawValue }

    var routes: [Route] {
        switch self {
        case .learn: [.home, .review, .placement, .exams, .library]
        case .progress: [.quests, .achievements, .weeklyReview]
        case .setup: [.contract, .settings]
        }
    }

    /// Every route in sidebar order (arrow keys and ⌘1-⌘9 follow it).
    static var orderedRoutes: [Route] { allCases.flatMap(\.routes) }
}
