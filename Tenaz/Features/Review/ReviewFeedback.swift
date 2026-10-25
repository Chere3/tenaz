import Foundation

/// The result shown right after an answer (tier S on right, the penalty tier on wrong).
struct ReviewFeedback: Equatable {
    var correct: Bool
    /// One letter off: graded Hard, shown as right with a spelling note.
    var nearMiss = false
    /// Recognition: the option the learner picked.
    var chosenOption: Int?
    /// Typed cards: what the learner typed.
    var typed = ""
    var xp = 0
    /// When the card comes back in this session ("Back in 1 min"), nil if not today.
    var backIn: TimeInterval?
    var combo = 0

    var backInText: String {
        guard let backIn else { return "Back later" }
        let minutes = max(1, Int((backIn / 60).rounded()))
        return "Back in \(minutes) min"
    }
}
