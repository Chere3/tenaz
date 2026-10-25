import TenazCore

/// Title, length and one-line purpose of each exam kind.
struct ExamCardInfo {
    let kind: ExamKind

    init(_ kind: ExamKind) { self.kind = kind }

    var title: String {
        switch kind {
        case .placement: "Placement"
        case .daily: "Daily Check"
        case .weekly: "Weekly Mock"
        case .monthly: "Monthly Mock"
        }
    }

    var length: String {
        switch kind {
        case .placement: "about 52 min"
        case .daily: "5-8 min"
        case .weekly: "about 45 min"
        case .monthly: "about 90 min"
        }
    }

    var purpose: String {
        switch kind {
        case .placement: "Your starting level in all five skills."
        case .daily: "Quick adaptive check. Moves your daily estimate."
        case .weekly: "Reading, listening, writing, speaking. Thursday to Sunday."
        case .monthly: "The full mock. Two verified ones raise your official level."
        }
    }

    var symbol: String {
        switch kind {
        case .placement: "flag.checkered"
        case .daily: "sun.max.fill"
        case .weekly: "calendar"
        case .monthly: "trophy.fill"
        }
    }
}
