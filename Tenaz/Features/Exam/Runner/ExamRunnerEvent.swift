import Foundation

/// What the runner tells its host (Exam Mode controller or the main window).
enum ExamRunnerEvent: Equatable {
    /// A section began; Exam Mode resets its watchdog to the section time + 10 min.
    case sectionStarted(Duration)
    case sectionEnded
    case pausedForLater
    case finished(String)
    case voided(String)
}
