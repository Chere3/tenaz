import SwiftUI

/// The section clock: an ink band that drains, a minute notch per minute, and the time as
/// digits. In the last two minutes it turns orange and says so once, calmly; it never flashes.
struct ExamTimer: View {
    let runner: ExamRunner

    private var readout: String {
        let s = max(0, Int(runner.remaining.components.seconds))
        return "\(s / 60):\(String(s % 60).leftPad(2))"
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            InkBand(remaining: runner.remainingFraction, notches: min(Int(runner.section?.minutes ?? 0), 15), readout: readout)
            Group {
                if runner.phase != .task {
                    Text("Timer starts when you start the section")
                } else if runner.isLastTwoMinutes {
                    Text("About 2 minutes left. Finish this one calmly.")
                        .foregroundStyle(Tokens.accentText)
                } else {
                    Text("\(Int(runner.section?.minutes ?? 0)) min for this section")
                }
            }
            .font(Typography.caption)
            .foregroundStyle(Tokens.brand)
        }
    }
}

extension String {
    /// "7" -> "07" for clock digits.
    func leftPad(_ width: Int, with pad: Character = "0") -> String {
        count >= width ? self : String(repeating: pad, count: width - count) + self
    }
}
