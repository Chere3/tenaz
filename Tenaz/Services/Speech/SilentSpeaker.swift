import Foundation

/// Silent stand-in for automation: reports success at once without making a sound.
@MainActor
final class SilentSpeaker: ExamSpeaking {
    func speak(_ lines: [SpeechLine]) async -> Bool { true }
    func stop() {}
    func voiceLabel(for lines: [SpeechLine]) -> String? { nil }
}
