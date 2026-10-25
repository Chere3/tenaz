import Foundation

/// The one primary action on Today (and in the popover), chosen by state. The placement test comes
/// first: until it is taken, Tenaz does not know the learner's level, so nothing else is offered as primary.
enum HomePrimary: Equatable {
    /// Placement not taken yet (or started and not finished).
    case placement(minutes: Int, inProgress: Bool)
    /// Today's set has cards left.
    case review(count: Int)
    /// Today's set is answered, but words in a learning step come back later today.
    case comeBack(count: Int, at: Date)
    /// Nothing left in today's set.
    case allDone

    static func decide(placementTaken: Bool, placementInProgress: Bool, placementMinutes: Int, todaySetCount: Int,
                       comingBack: TodayComingBack? = nil) -> HomePrimary
    {
        if !placementTaken { return .placement(minutes: placementMinutes, inProgress: placementInProgress) }
        if todaySetCount > 0 { return .review(count: todaySetCount) }
        if let comingBack { return .comeBack(count: comingBack.count, at: comingBack.at) }
        return .allDone
    }

    var title: String {
        switch self {
        case let .placement(_, inProgress): inProgress ? "Continue your placement test" : "Take your placement test"
        case let .review(count): count == 1 ? "Review 1 word" : "Review \(count) words"
        case let .comeBack(count, at): "\(count) \(count == 1 ? "word" : "words") back at \(at.formatted(date: .omitted, time: .shortened))"
        case .allDone: "All done for today"
        }
    }

    /// Short form for the menu-bar popover.
    var shortTitle: String {
        switch self {
        case let .placement(_, inProgress): inProgress ? "Continue placement" : "Placement test"
        case let .review(count): count == 1 ? "Review 1 word" : "Review \(count) words"
        case let .comeBack(_, at): "Back at \(at.formatted(date: .omitted, time: .shortened))"
        case .allDone: "All done today"
        }
    }

    var systemImage: String {
        switch self {
        case .placement: "flag.checkered"
        case .review: "play.fill"
        case .comeBack: "clock.arrow.circlepath"
        case .allDone: "checkmark.seal.fill"
        }
    }

    var isActionable: Bool { self != .allDone }

    /// A stable name for logs and the `home-state` self-test.
    var debugName: String {
        switch self {
        case let .placement(minutes, inProgress): "placement(minutes: \(minutes), inProgress: \(inProgress))"
        case let .review(count): "review(count: \(count))"
        case let .comeBack(count, at): "comeBack(count: \(count), in: \(Int(at.timeIntervalSinceNow))s)"
        case .allDone: "allDone"
        }
    }
}
