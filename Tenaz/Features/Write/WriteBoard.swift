import SwiftUI

/// Today's writing on the `.turn` flood: the prompt, the words to use (ticked as they appear), a
/// paste-proof paper sheet, the live word count as one quiet line, and Done (⌘Return). After saving the
/// field turns `.good`: Tena's thanks and the XP.
struct WriteBoard: View {
    let prompt: TodayWritePrompt?
    @Binding var text: String
    var result: WriteResult?
    var stage: TenaStage = .juvenile
    var save: () -> Void = {}
    var close: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var check: WriteCheck { WriteCheck(text: text, prompt: prompt) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let result {
                WriteDoneView(result: result, close: close)
                    .transition(.opacity)
            } else {
                writing
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 36)
        .padding(.bottom, 32)
        .frame(width: 760, height: Self.height(for: prompt))
        .background {
            if let result {
                BleedTena(mood: result.dayQualified ? .proud : .happy, stage: stage, corner: .bottomTrailing,
                          heightShare: 0.7, rays: result.dayQualified, textEdge: WriteDoneView.textEdge)
                    .transition(.opacity)
            }
        }
        .clipped()
        .animation(Motion.animation(.pop, reduceMotion: reduceMotion), value: result)
        .flood(result == nil ? .turn : .good)
    }

    /// Taller when the kind brings a text to work on, so the text and the sheet both fit.
    static func height(for prompt: TodayWritePrompt?) -> CGFloat { prompt?.text == nil ? 560 : 720 }

    @ViewBuilder private var writing: some View {
        Text(prompt?.prompt ?? "Write two sentences about your day.")
            .font(Typography.display(prompt?.text == nil ? 30 : 26, weight: 800))
            .foregroundStyle(Tokens.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.trailing, Tokens.Space.xl)
        if let instruction = prompt?.instruction {
            Text(instruction)
                .font(Typography.title)
                .foregroundStyle(Tokens.ink)
                .padding(.top, Tokens.Space.xs)
        }
        if let text = prompt?.text {
            TaskTextBlock(text: text, kind: prompt?.kind ?? .personal, maxHeight: 170)
                .padding(.top, Tokens.Space.m)
        }
        if !check.targets.isEmpty {
            HStack(spacing: Tokens.Space.s) {
                Text("Try to use")
                    .foregroundStyle(Tokens.brand)
                ForEach(check.targets, id: \.0) { target, used in
                    HStack(spacing: 4) {
                        if used { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)) }
                        Text(target)
                    }
                    .foregroundStyle(used ? Tokens.ink : Tokens.brand)
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(used ? "used" : "not used yet")
                }
            }
            .font(Typography.labelBold)
            .padding(.top, Tokens.Space.s)
        }
        WritingInput(text: $text, placeholder: prompt?.kind.placeholder ?? "Start with one sentence. You can write more.", onCancel: close)
            .padding(Tokens.Space.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: Tokens.Radius.sheet, style: .continuous).fill(Tokens.paper))
            .padding(.top, Tokens.Space.l)
        HStack(spacing: Tokens.Space.m) {
            if check.looksEnglish {
                Text("\(check.words) of \(check.goal) words · one sentence is enough")
                    .font(Typography.numeric(14))
                    .foregroundStyle(Tokens.brand)
                    .lineLimit(1)
                    .layoutPriority(1)
                    .contentTransition(.numericText())
            } else {
                Label("Write it in English, please.", systemImage: "exclamationmark.circle")
                    .font(Typography.labelBold)
                    .foregroundStyle(Tokens.ink)
            }
            Spacer(minLength: Tokens.Space.s)
            Button(action: close) {
                HStack(spacing: 6) {
                    Text("Not now")
                    KeyCap("esc")
                }
            }
            .buttonStyle(.ink)
            .keyboardShortcut(.cancelAction)
            .fixedSize()
            Button(action: save) {
                HStack(spacing: Tokens.Space.s) {
                    Text("Done")
                    KeyCap("⌘Return")
                }
            }
            .buttonStyle(.fat)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!check.canSubmit)
            .fixedSize()
        }
        .padding(.top, Tokens.Space.l)
    }
}
