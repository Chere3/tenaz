import Foundation

/// Pure exam typing telemetry (PLAN F5 Exam Mode, thresholds [unverified, calibrate]). Feed it every edit of
/// an answer field; it never sees the text, only counts.
public struct TypingMonitor: Sendable {
    public var maxInsertion = 8
    public var maxWPM = 150.0
    /// A pause longer than this starts a new burst.
    public var burstGap: TimeInterval = 2
    /// Bursts shorter than this are too small to judge a speed from.
    public var minBurstDuration: TimeInterval = 10

    private var burstStart: TimeInterval?
    private var lastEdit: TimeInterval = 0
    private var characters = 0
    private var backspaces = 0
    private var flaggedBurst = false

    public init() {}

    /// `at` is seconds on any monotonic clock; `isIME` is true while an input method is composing.
    public mutating func record(at: TimeInterval, inserted: Int, deleted: Int, isIME: Bool) -> TypingFlag? {
        if inserted > maxInsertion && !isIME { return .largeInsertion(characters: inserted) }

        if burstStart == nil || at - lastEdit > burstGap {
            burstStart = at
            characters = 0
            backspaces = 0
            flaggedBurst = false
        }
        lastEdit = at
        characters += inserted
        backspaces += deleted

        guard let start = burstStart, !flaggedBurst, backspaces == 0, at - start >= minBurstDuration else { return nil }
        let wpm = Double(characters) / 5 / ((at - start) / 60)
        guard wpm > maxWPM else { return nil }
        flaggedBurst = true
        return .fastTyping(wpm: Int(wpm))
    }
}
