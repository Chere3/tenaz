/// Tivra's read-only witness, as the intro and the exam footer show it.
enum ExamWitness: Equatable {
    case checking
    /// Tivra is capturing: the result can count for promotion if nothing is flagged.
    case watching
    /// Tivra is not capturing (or not installed): the exam still runs; the result gives a level
    /// estimate but is marked unverified.
    case notWatching(String)

    var isWatching: Bool { self == .watching }

    var title: String {
        switch self {
        case .checking: "Checking Tivra…"
        case .watching: "Tivra is watching"
        case .notWatching: "Tivra is not watching"
        }
    }

    var detail: String {
        switch self {
        case .checking: "Looking at Tivra's records on this Mac."
        case .watching: "Your result can count as verified."
        case let .notWatching(reason): "You still get a level. It will be marked unverified (\(reason))."
        }
    }

    var systemImage: String {
        switch self {
        case .checking: "hourglass"
        case .watching: "eye.fill"
        case .notWatching: "eye.slash"
        }
    }
}
