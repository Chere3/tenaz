extension IntegrityLevel {
    /// Whether an attempt with this verdict counts for promotion, XP and streaks (PLAN F5):
    /// CLEAN counts; WARNING counts once the learner confirms it in the review screen.
    public func counts(confirmed: Bool) -> Bool {
        self == .clean || (self == .warning && confirmed)
    }

    /// `exam_attempt.integrity` holds a raw value, or NULL while the Tivra witness hasn't run.
    static func counts(stored raw: String?, confirmed: Bool) -> Bool {
        raw.flatMap(IntegrityLevel.init(rawValue:))?.counts(confirmed: confirmed) ?? false
    }
}
