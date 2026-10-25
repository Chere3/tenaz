/// Why the Exam Mode panel closed.
enum ExamModeExit: Equatable {
    case finished(String)
    case voided(String)
    /// "Pause here and finish later" between sections.
    case pausedForLater
    /// A meeting signal: the exam is paused, resumable from the main window.
    case meeting
    /// The section watchdog (section time + 10 min) or the panel's hard cap fired.
    case watchdog
}
