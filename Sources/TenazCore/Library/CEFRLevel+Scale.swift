public extension CEFRLevel {
    /// The numeric scale of research 08 §6.1: B1 = 3, B1+ = 3.5, B2 = 4, C1 = 5.
    var scaleValue: Double {
        switch self {
        case .a1: 1
        case .a2: 2
        case .b1: 3
        case .b1Plus: 3.5
        case .b2: 4
        case .b2Plus: 4.5
        case .c1: 5
        case .c2: 6
        }
    }
}
