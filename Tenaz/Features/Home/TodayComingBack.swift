import Foundation

/// Words in a learning step that come back later today (a missed or new word waits 1-10 min).
struct TodayComingBack: Equatable {
    var count: Int
    var at: Date
}
