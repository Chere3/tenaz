import SwiftUI

/// Tena's two meters (0-100). Vitality drops with missed days; Spirit with wrong answers and idle days.
enum MeterKind {
    case vitality, spirit

    var title: String {
        switch self {
        case .vitality: "Vitality"
        case .spirit: "Spirit"
        }
    }

    var systemImage: String {
        switch self {
        case .vitality: "heart.fill"
        case .spirit: "sparkles"
        }
    }

    var fill: Color {
        switch self {
        case .vitality: Tokens.correct
        case .spirit: Tokens.gold
        }
    }
}
