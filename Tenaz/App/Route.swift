import Foundation

/// Every destination in the main window. Builders add their screen's view in MainWindow's switch.
enum Route: String, CaseIterable, Identifiable, Hashable {
    case home, review, placement, exams, library, achievements, quests, weeklyReview, contract, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Today"
        case .review: "Review"
        case .placement: "Placement test"
        case .exams: "Exams"
        case .library: "Library"
        case .achievements: "Achievements"
        case .quests: "Quests"
        case .weeklyReview: "Weekly review"
        case .contract: "Contract"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .home: "sun.max"
        case .review: "rectangle.stack"
        case .placement: "flag.checkered"
        case .exams: "checklist"
        case .library: "books.vertical"
        case .achievements: "rosette"
        case .quests: "scope"
        case .weeklyReview: "calendar"
        case .contract: "signature"
        case .settings: "gearshape"
        }
    }
}

/// Shared navigation state so the popover, Home and onboarding can jump to a screen.
@Observable
final class Navigator {
    var route: Route = .home
    var showOnboarding = false
    /// Today's writing sheet (from Home's Write card or the popover).
    var showWrite = false
}
