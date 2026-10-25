import SwiftUI

/// Only missed words are left and none is due yet: the countdown is the hero, the wait is drawn as a
/// draining band, and the session goes on by itself when the next word is ready. A natural place to stop.
struct ReviewWaitingView: View {
    let until: Date
    let stop: () -> Void
    /// Something useful for the wait (the Write sheet, which also counts for the daily minimum).
    var write: () -> Void = {}
    var now: Date = .now
    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        if isSnapshot {
            pause(at: now)
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                pause(at: context.date)
            }
        }
    }

    private func pause(at date: Date) -> some View {
        let seconds = max(0, Int(until.timeIntervalSince(date).rounded(.up)))
        let readout = Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
        return ReviewPause(hero: readout, heroFont: Typography.numberHero, caption: "until a word you missed comes back",
                           line: "Seeing it again helps you remember. Stop here, or write one sentence while you wait.",
                           primaryTitle: "Write one sentence", primary: write,
                           secondaryTitle: "Stop here", secondary: stop)
        {
            InkBand(remaining: min(1, Double(seconds) / (seconds <= 60 ? 60 : 600)))
                .frame(maxWidth: 360)
                .accessibilityValue(readout)
        }
    }
}
