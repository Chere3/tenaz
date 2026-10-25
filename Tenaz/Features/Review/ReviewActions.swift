/// What the review screen's buttons and keys do.
struct ReviewActions {
    /// Recognition: pick option 0-3 (number keys 1-4).
    var choose: (Int) -> Void = { _ in }
    /// Typed cards: Return.
    var submit: () -> Void = {}
    /// "I don't know": shows the answer, graded as a miss.
    var reveal: () -> Void = {}
    /// Return on feedback, "Keep going" on the checkpoint.
    var next: () -> Void = {}
    /// Esc: end the session now.
    var stop: () -> Void = {}
    var write: () -> Void = {}
    var home: () -> Void = {}
}
