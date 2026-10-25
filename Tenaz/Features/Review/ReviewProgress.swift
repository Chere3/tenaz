/// The session so far, for the top bar.
struct ReviewProgress: Equatable {
    var answered = 0
    var correct = 0
    /// Cards still to show (queue, relearning and the one on screen).
    var remaining = 0
    var xp = 0
    var combo = 0
    /// Right answers today across all sessions (the daily minimum counts these).
    var correctToday = 0

    var total: Int { answered + remaining }
    var fraction: Double { total > 0 ? Double(answered) / Double(total) : 0 }
}
