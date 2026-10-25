import SwiftUI
import TenazCore

/// Write an Email / Academic Discussion / About You: the task on the left, a paste-proof page on
/// the right with a live word count against the minimum and the section time.
struct WritingItemView: View {
    @Bindable var runner: ExamRunner
    let task: ExamTask

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Space.xl) {
            VStack(alignment: .leading, spacing: Tokens.Space.l) {
                WritingPromptCard(item: task.item)
                Spacer(minLength: 0)
            }
            .frame(width: 400)
            .frame(maxHeight: .infinity, alignment: .top)
            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                ExamTextField(text: $runner.draft.text, prompt: "Start writing here…", multiline: true, fontSize: 21,
                              actions: ExamTextActions(commandSubmit: runner.next, edit: runner.recordTyping,
                                                       pasteBlocked: runner.pasteBlocked))
                    .padding(Tokens.Space.xl)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .examSheet()
                WordCountBar(text: runner.draft.text, minWords: task.item?.minWords ?? 80, remaining: runner.remaining)
            }
        }
    }
}

/// What to write: the situation and bullet tasks, the discussion posts, or the life question.
private struct WritingPromptCard: View {
    let item: ExamItem?

    var body: some View {
        SnapshotSafeScroll(hug: true) {
            VStack(alignment: .leading, spacing: Tokens.Space.m) {
                if let item {
                    switch item.type {
                    case .writeEmail:
                        PromptBlock(kicker: "The situation", text: item.situation ?? "")
                        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                            Text("In your email")
                                .font(Typography.labelBold).foregroundStyle(Tokens.brand)
                            ForEach(Array((item.tasks ?? []).enumerated()), id: \.offset) { i, line in
                                HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
                                    Text("\(i + 1)")
                                        .font(Typography.labelBold)
                                        .foregroundStyle(Tokens.paper)
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(Tokens.ink))
                                    Text(line)
                                        .font(.system(size: 16, design: .rounded))
                                        .foregroundStyle(Tokens.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    case .writeDiscussion:
                        PromptBlock(kicker: "Your professor asks", text: item.professor ?? "")
                        PromptBlock(kicker: "Classmates wrote", text: item.studentA ?? "", small: true)
                        PromptBlock(kicker: nil, text: item.studentB ?? "", small: true)
                        Text("Add your own idea. Don't just repeat theirs.")
                            .font(Typography.labelBold)
                            .foregroundStyle(Tokens.brand)
                    default:
                        let kind = item.writingKind ?? .personal
                        PromptBlock(kicker: kind == .personal ? "About you" : kind.instructionLine(under: item.prompt ?? ""),
                                    text: item.prompt ?? "")
                        if let text = item.text, !text.isEmpty {
                            TaskTextBlock(text: text, kind: kind, maxHeight: 260)
                        }
                        if let must = item.mustUse, !must.isEmpty {
                            Text("Try to use")
                                .font(Typography.labelBold).foregroundStyle(Tokens.brand)
                            FlowLayout(spacing: Tokens.Space.xs, lineSpacing: Tokens.Space.xs) {
                                ForEach(must, id: \.self) { Chip($0, systemImage: "text.badge.star") }
                            }
                        }
                    }
                    Label("Paste is off in exams. Your own words only.", systemImage: "hand.raised.fill")
                        .font(Typography.label)
                        .foregroundStyle(Tokens.brand)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PromptBlock: View {
    let kicker: String?
    let text: String
    var small = false

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            if let kicker {
                Text(kicker).font(Typography.labelBold).foregroundStyle(Tokens.brand)
            }
            Text(text)
                .font(.system(size: small ? 16 : 19, weight: small ? .regular : .medium, design: .rounded))
                .foregroundStyle(Tokens.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// "62 / 120 words" with ten cells that fill toward the minimum, plus the time left.
private struct WordCountBar: View {
    let text: String
    let minWords: Int
    let remaining: Duration

    private var words: Int { text.split { $0.isWhitespace || $0.isNewline }.count }

    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: words >= minWords ? "checkmark.circle.fill" : "text.word.spacing")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(words >= minWords ? Tokens.correct : Tokens.brand)
            Text(words >= minWords ? "\(words) words. Enough!" : "\(words) of \(minWords) words")
                .font(Typography.numeric(15))
                .foregroundStyle(Tokens.ink)
            MeterCells(fraction: Double(words) / Double(max(minWords, 1)), fill: words >= minWords ? Tokens.correct : Tokens.brand)
                .frame(width: 180, height: 14)
            Spacer()
            Label("\(Int(remaining.components.seconds) / 60) min left", systemImage: "timer")
                .font(Typography.labelBold)
                .foregroundStyle(Tokens.brand)
        }
        .accessibilityElement(children: .combine)
    }
}
