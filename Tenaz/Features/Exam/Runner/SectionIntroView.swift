import SwiftUI
import TenazCore

/// Before each section: what it is, how long, how many tasks, and how to answer. The timer is
/// stopped here; Return starts the section. In Exam Mode the learner may also stop and finish later.
struct SectionIntroView: View {
    let runner: ExamRunner

    private var spec: SectionSpec? { runner.section }

    private var howTo: String {
        switch spec?.skill {
        case .reading: "Read each text, then pick answers with 1-4. Return goes on."
        case .listening: "Each audio plays up to 2 times. Pick answers with 1-4."
        case .writing: "Write in your own words. Command-Return hands it in."
        case .speaking: "Say your answer, or type what you would say."
        case .grammar, nil: "Pick with 1-4, or tap the pieces. Return goes on."
        }
    }

    /// One calm tip per section, shown here once instead of beside every task.
    private var tip: String? {
        switch spec?.skill {
        case .reading: "Read the whole text first. In the gap words, each gap finishes a common word."
        case .listening: "Listen for the main idea first, details second."
        case .writing: "Cover every point. Clear and polite beats long."
        case .speaking: "Talk like in a meeting: answer, give a reason, add an example."
        case .grammar: "Say the sentence in your head with each option. Trust your ear."
        case nil: nil
        }
    }

    private static let tenaSize: CGFloat = 380

    private var resumedHere: Bool { runner.resumed && runner.session.sectionPosition > 0 }

    var body: some View {
        HStack(alignment: .center, spacing: Tokens.Space.xxl) {
            VStack(alignment: .leading, spacing: Tokens.Space.m) {
                Text(resumedHere ? "Welcome back" : "Next up")
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
                Text(spec?.title ?? "")
                    .font(Typography.displayL)
                    .foregroundStyle(Tokens.ink)
                Text(introFacts)
                    .font(Typography.title)
                    .foregroundStyle(Tokens.ink)
                Text(resumedHere ? "You stopped in the middle of this section. Your answers are saved. The timer goes on from where it was." : howTo)
                    .font(Typography.body)
                    .foregroundStyle(Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 440, alignment: .leading)
                if !resumedHere, let tip {
                    Text(tip)
                        .font(Typography.label)
                        .foregroundStyle(ResultInk.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 440, alignment: .leading)
                }
                if runner.examMode {
                    Button("Pause here and finish later", systemImage: "pause.circle", action: runner.pauseBetweenSections)
                        .buttonStyle(.ink)
                        .keyboardShortcut("p", modifiers: .command)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .overlay(alignment: .bottomTrailing) {
            // Tena in her headband, whole and standing on the stage's floor: the footer rule below the stage
            // is an inner edge, and an inner edge never crops her.
            let ink = TenaInk.bounds(stage: .juvenile, mood: .focused)
            TenaView(mood: .focused, stage: .juvenile, size: Self.tenaSize)
                .environment(\.mascotStill, true)
                .offset(x: (1 - ink.maxX) * Self.tenaSize, y: (1 - ink.maxY) * Self.tenaSize - Tokens.Space.l)
                .accessibilityHidden(true)
        }
    }

    private var introFacts: String {
        var facts = ["\(Int(spec?.minutes ?? 0)) min", taskCountText]
        if spec?.fallback == .transcript { facts.append("audio") }
        if spec?.skill == .listening, let task = runner.task,
           let voice = runner.speaker.voiceLabel(for: ExamScript.lines(for: task)) { facts.append(voice) }
        if spec?.fallback == .typed { facts.append("typing is OK") }
        return facts.joined(separator: " · ")
    }

    private var taskCountText: String {
        let n = runner.session.sectionLength
        return n == 1 ? "1 task" : "\(n) tasks"
    }
}
