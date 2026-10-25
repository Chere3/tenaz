import SwiftUI
import TenazCore

/// Where a speaking answer goes. Typed by default; with the microphone already set up (from the
/// Placement or Exams page) "Record" transcribes on this Mac. Permission is never asked in here:
/// the system prompt would sit under the full-screen panel. Not set up, denied or unavailable just keeps typing.
struct SpeakingAnswerPanel: View {
    let runner: ExamRunner
    let task: ExamTask
    @Binding var text: String
    let multiline: Bool
    @State private var recorder: SpeechRecorder?
    @Environment(\.isSnapshot) private var isSnapshot

    private var recording: Bool { recorder?.status == .recording }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            HStack(spacing: Tokens.Space.s) {
                Label(recording ? "Listening… speak now" : "Type what you would say",
                      systemImage: recording ? "waveform" : "keyboard")
                    .font(Typography.title)
                    .foregroundStyle(Tokens.ink)
                Spacer()
                MicrophoneButton(status: recorder?.status ?? .notAsked, action: micAction)
            }
            ExamTextField(text: $text, prompt: multiline ? "I would say that…" : "Type the sentence you heard",
                          multiline: multiline, fontSize: multiline ? 21 : 28, isFocused: !recording,
                          actions: ExamTextActions(submit: runner.next, commandSubmit: runner.next,
                                                   edit: runner.recordTyping, pasteBlocked: runner.pasteBlocked))
                .padding(Tokens.Space.xl)
                .frame(maxWidth: .infinity, minHeight: multiline ? nil : 96, maxHeight: multiline ? .infinity : nil,
                       alignment: .topLeading)
                .examSheet()
            Text(statusLine)
                .font(Typography.label)
                .foregroundStyle(Tokens.ink.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
            if !multiline { Spacer(minLength: 0) }
        }
        .onAppear {
            guard !isSnapshot, !LaunchArguments.current.isAutomation, recorder == nil else { return }
            recorder = SpeechRecorder()
        }
        .onDisappear(perform: stopRecording)
        // Interview: a new question must never inherit the running transcript of the last one.
        .onChange(of: runner.draft.questionIndex) {
            guard recording else { return }
            stopRecording()
            runner.note(ExamNote.spoken, for: task.id)
        }
        .onChange(of: text) { _, new in
            guard !recording, !new.isEmpty, runner.notes[task.id] == nil else { return }
            runner.note(ExamNote.typedInstead, for: task.id)
        }
        .onChange(of: recorder?.transcript ?? "") { _, transcript in
            guard recording, !transcript.isEmpty else { return }
            text = transcript
        }
    }

    private var statusLine: String {
        switch recorder?.status ?? .notAsked {
        case .notAsked, .asking: "Typed answers count."
        case .denied: "The microphone is off for Tenaz. Typing is fine. (System Settings → Privacy can turn it on.)"
        case let .unavailable(reason): "\(reason) Typing is fine."
        case .ready: "Press the microphone, speak, then press it again to stop."
        case .recording: "Tenaz is writing down what you say. Press Stop when you finish."
        }
    }

    private func micAction() {
        guard let recorder else { return }
        switch recorder.status {
        case .ready:
            recorder.start()
            runner.usingMicrophone = recorder.status == .recording
        case .recording:
            stopRecording()
            runner.note(ExamNote.spoken, for: task.id)
        case .notAsked, .asking, .denied, .unavailable:
            break
        }
    }

    private func stopRecording() {
        recorder?.stop()
        runner.usingMicrophone = false
    }
}

/// "Use microphone" / "Record" / "Stop" as an ink pill; hidden behind a lock glyph when denied.
private struct MicrophoneButton: View {
    let status: SpeechRecorder.Status
    let action: () -> Void

    private var title: String {
        switch status {
        case .notAsked, .asking: "Microphone not set up"
        case .ready: "Record"
        case .recording: "Stop"
        case .denied: "Microphone off"
        case .unavailable: "No microphone"
        }
    }

    private var symbol: String {
        switch status {
        case .recording: "stop.circle.fill"
        case .notAsked, .asking, .denied, .unavailable: "mic.slash"
        default: "mic.fill"
        }
    }

    var body: some View {
        Button(title, systemImage: symbol, action: action)
            .buttonStyle(InkTextButtonStyle(tint: status == .recording ? Tokens.wrong : Tokens.brand))
            .disabled(status != .ready && status != .recording)
    }
}

extension SpeechRecorder.Status {
    var isUnavailable: Bool { if case .unavailable = self { true } else { false } }
}
