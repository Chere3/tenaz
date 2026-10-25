import SwiftUI
import TenazCore

/// The player for listening and repeat tasks: a big play key (Space), plays left, and the honest
/// transcript rule: hidden while audio works, shown (and the item marked) when speech can't play.
struct AudioCard: View {
    let runner: ExamRunner
    let task: ExamTask
    let title: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var transcriptShown: Bool { runner.isTranscriptShown }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            Text(title)
                .font(Typography.displayS)
                .foregroundStyle(Tokens.ink)
            HStack(spacing: Tokens.Space.l) {
                Button(action: runner.play) {
                    ZStack {
                        Circle().fill(runner.playsLeft > 0 ? Tokens.ink : Tokens.ink.opacity(0.12))
                        Image(systemName: runner.isPlaying ? "waveform" : "play.fill")
                            .font(.system(size: 26, weight: .black))
                            .foregroundStyle(runner.playsLeft > 0 ? Tokens.paper : Tokens.brand)
                            .symbolEffect(.variableColor.iterative, isActive: runner.isPlaying && !reduceMotion)
                    }
                    .frame(width: 64, height: 64)
                }
                .buttonStyle(.plain)
                .disabled(runner.playsLeft == 0 || runner.isPlaying)
                .accessibilityLabel(runner.isPlaying ? "Playing" : "Play audio, \(runner.playsLeft) plays left")
                VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                    Text(runner.isPlaying ? "Playing…" : runner.playsLeft == 2 ? "Press play when ready" : "Played")
                        .font(Typography.title)
                        .foregroundStyle(Tokens.ink)
                    HStack(spacing: Tokens.Space.xs) {
                        KeyCap("Space")
                        Text(runner.playsLeft == 1 ? "1 play left" : "\(runner.playsLeft) plays left")
                            .font(Typography.labelBold)
                            .foregroundStyle(Tokens.brand)
                    }
                }
            }
            if transcriptShown {
                TranscriptView(lines: ExamScript.transcript(for: task))
            } else {
                Label("No text here: listen like in a real call.", systemImage: "eye.slash")
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// Shown only when speech could not play: the script, marked "read instead" in the results.
private struct TranscriptView: View {
    let lines: [(speaker: String?, text: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Label("Audio didn't play, so here is the text. This item is marked \"read instead\".",
                  systemImage: "text.alignleft")
                .font(Typography.labelBold)
                .foregroundStyle(Tokens.accentText)
            SnapshotSafeScroll(hug: true) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(lines.indices, id: \.self) { i in
                        Text(lines[i].speaker.map { "\($0): \(lines[i].text)" } ?? lines[i].text)
                            .font(.system(size: 16, design: .rounded))
                            .foregroundStyle(Tokens.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
