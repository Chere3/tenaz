import SwiftUI

/// Speaking parts, type or talk, as one quiet line: asks for Microphone and Speech Recognition here
/// in the main window, before Exam Mode covers the screen (a system prompt there would be hidden
/// under the panel).
struct MicrophoneSetupRow: View {
    @State private var recorder: SpeechRecorder?
    @Environment(\.isSnapshot) private var isSnapshot

    private var status: SpeechRecorder.Status { recorder?.status ?? .notAsked }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(line)
                .font(Typography.label)
                .foregroundStyle(Tokens.ink.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
            if status == .notAsked || status == .asking {
                Button {
                    guard let recorder else { return }
                    Task { await recorder.requestAccess() }
                } label: {
                    Text(status == .asking ? "Waiting for macOS…" : "Set up microphone")
                        .font(Typography.labelBold)
                        .underline()
                        .foregroundStyle(Tokens.ink)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(status == .asking || recorder == nil)
                .help("macOS asks twice: Microphone, then Speech Recognition.")
                .accessibilityLabel(status == .asking ? "Waiting for macOS" : "Set up microphone")
            }
        }
        .onAppear {
            guard !isSnapshot, !LaunchArguments.current.isAutomation, recorder == nil else { return }
            recorder = SpeechRecorder()
        }
    }

    private var line: String {
        switch status {
        case .notAsked: "Speaking parts: type, or talk."
        case .asking: "macOS is asking for Microphone and Speech Recognition."
        case .ready, .recording: "Microphone ready: press Record in the speaking parts, or just type."
        case .denied: "The microphone is off for Tenaz, so you'll type. System Settings → Privacy can turn it on."
        case let .unavailable(reason): "\(reason) You'll type instead."
        }
    }
}
