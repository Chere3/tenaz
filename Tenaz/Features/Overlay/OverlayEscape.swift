/// The escape ladder on every overlay (F1), always visible, in this order.
enum OverlayEscape: Equatable {
    /// Esc: skip this batch (costs Vitality only when the learner's contract turns Response cost on).
    case skip
    /// ⌃⌥⌘S: snooze 5 min, free, 3 a day.
    case snooze
    /// "I'm in a meeting": nothing for 60 min.
    case meeting
}
