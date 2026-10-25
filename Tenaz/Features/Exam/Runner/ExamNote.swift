/// Per-task notes kept with the attempt (`exam_progress.notes`).
enum ExamNote {
    /// Speech could not play, so the listening text was shown instead.
    static let readInstead = "readInstead"
    /// No microphone: the speaking answer was typed.
    static let typedInstead = "typedInstead"
    static let spoken = "spoken"
}
