import SwiftUI
import TenazCore

/// The unlock gate (F2, Full Bleed): a full-screen serious (indigo) field after unlock or wake, the
/// question as the hero, a paper sheet to write on, Tena cropped by the bottom edge. Not a security
/// boundary; the kill switch, Force Quit, the skip and the 5-minute limit always work.
struct GateView: View {
    @Bindable var model: GateModel
    var stage: TenaStage = .juvenile
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            GateBackdrop()
            VStack(alignment: .leading, spacing: 0) {
                GateTopBar(model: model)
                    .padding(.trailing, OverlayLayoutBand.width)
                    .frame(height: 60)
                Spacer(minLength: Tokens.Space.l)
                VStack(alignment: .leading, spacing: Tokens.Space.m) {
                    GateBubble(question: model.prompt.question)
                        .frame(maxWidth: 820, alignment: .leading)
                    if let instruction = model.prompt.kind.instructionLine(under: model.prompt.question) {
                        Text(instruction)
                            .font(Typography.title)
                            .foregroundStyle(Tokens.ink)
                    }
                    if let text = model.prompt.text {
                        TaskTextBlock(text: text, kind: model.prompt.kind, fontSize: 20, maxHeight: 150)
                            .frame(maxWidth: 860, alignment: .leading)
                    }
                    GateChunkLine(prompt: model.prompt, minWords: model.requirement.minWords, target: model.requirement.targetWords)
                        .padding(.bottom, Tokens.Space.xs)
                    ParagraphField(text: $model.text, placeholder: model.prompt.kind.placeholder ?? "Start typing in English…") { model.submit() }
                        .onChange(of: model.text) { _, new in model.textChanged(new) }
                        .frame(maxWidth: 860)
                    GateChecklist(checks: model.checks)
                        .frame(maxWidth: 860)
                    Button(action: { model.submit() }) {
                        HStack(spacing: Tokens.Space.s) {
                            Image(systemName: model.checks.passes ? "lock.open.fill" : "lock.fill")
                            Text("Unlock")
                            KeyCap("Return")
                        }
                    }
                    .buttonStyle(.fat)
                    .disabled(!model.checks.passes)
                    .frame(maxWidth: 360)
                    .padding(.top, Tokens.Space.xs)
                    .accessibilityHint(model.checks.passes ? "Opens your Mac" : "Finish the checks above first")
                }
                Spacer(minLength: Tokens.Space.l)
                HStack(spacing: Tokens.Space.m) {
                    Button("Joining a call", systemImage: "phone.arrow.up.right.fill", action: model.joiningCall)
                        .buttonStyle(.ink)
                        .help("Closes now, free. No gate for 60 minutes.")
                    Text("·").foregroundStyle(Tokens.brand)
                    Text("Turn everything off: \(KillSwitch.hotkeyLabel)")
                        .font(Typography.label)
                        .foregroundStyle(Tokens.brand)
                    Spacer()
                }
            }
            .padding(.horizontal, Tokens.Space.hero)
            .padding(.vertical, Tokens.Space.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(alignment: .bottomTrailing) {
                TenaView(mood: tenaMood, stage: stage, size: 640)
                    .offset(x: 100, y: 140)
            }
            .disabled(model.phase == .confirmingSkip || model.phase == .unlocked || model.phase == .later)
            if model.phase == .confirmingSkip {
                Color.black.opacity(0.35).ignoresSafeArea().clipShape(NotchedPage())
                GateSkipConfirm(price: model.price, keepWriting: model.cancelSkip) { model.confirmSkip(useMercy: $0) }
                    .transition(.opacity)
            }
            GateStamp(phase: model.phase)
        }
        .environment(\.colorScheme, Flood.serious.inkScheme)
        .animation(Motion.animation(.settle, reduceMotion: reduceMotion), value: model.phase)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tenaz unlock gate")
    }

    private var tenaMood: TenaMood {
        switch model.phase {
        case .unlocked: .ecstatic
        case .later: .neutral
        default: model.checks.passes ? .happy : .focused
        }
    }
}
