import Foundation

/// CEFR proficiency bands, with "plus" steps so progress between levels is visible.
public enum CEFRLevel: Int, Codable, CaseIterable, Comparable, Sendable {
    case a1 = 0, a2, b1, b1Plus, b2, b2Plus, c1, c2

    public var label: String {
        switch self {
        case .a1: "A1"
        case .a2: "A2"
        case .b1: "B1"
        case .b1Plus: "B1+"
        case .b2: "B2"
        case .b2Plus: "B2+"
        case .c1: "C1"
        case .c2: "C2"
        }
    }

    public init?(label: String) {
        guard let match = CEFRLevel.allCases.first(where: { $0.label == label.uppercased() }) else { return nil }
        self = match
    }

    public static func < (lhs: CEFRLevel, rhs: CEFRLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}
