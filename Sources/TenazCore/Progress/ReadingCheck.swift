/// The 3-question comprehension self-check after a reading session (research 08 §1.2), and the
/// words-per-minute rule: only sessions understood at 70% or more count towards pace.
public enum ReadingCheck {
    public static let questions = [
        "Could you tell someone what this part was about?",
        "Did you understand most sentences without a dictionary?",
        "Could you explain one idea from it at work?",
    ]
    public static let minimumComprehension = 0.7
    /// A printed page of an adult paperback, roughly.
    public static let wordsPerPage = 280

    public static func comprehension(yes: Int) -> Double {
        Double(max(0, min(questions.count, yes))) / Double(questions.count)
    }

    public static func wpm(words: Int?, minutes: Int, comprehension: Double?) -> Double? {
        guard let words, words > 0, minutes > 0, let comprehension, comprehension >= minimumComprehension else { return nil }
        return Double(words) / Double(minutes)
    }
}
