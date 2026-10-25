import AVFoundation

/// Speaks listening scripts, a different voice per speaker: `NeuralSpeaker` (Kokoro audio cache) by
/// default, `SystemSpeaker` as its fallback. Never plays in automation (snapshots, smokes, self-tests).
@MainActor
protocol ExamSpeaking: AnyObject {
    /// Plays the lines in order; false when speech could not play (no English voice, cancelled).
    func speak(_ lines: [SpeechLine]) async -> Bool
    func stop()
    /// What these lines will sound like ("neural voices", "system voice"); nil when silent.
    func voiceLabel(for lines: [SpeechLine]) -> String?
}

/// The best installed English voices (premium, then enhanced), used when no neural audio is cached.

@MainActor
final class SystemSpeaker: NSObject, ExamSpeaking {
    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Bool, Never>?
    private var remaining = 0
    private var watchdog: Task<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ lines: [SpeechLine]) async -> Bool {
        stop()
        let voices = VoicePicker.cast(for: lines)
        guard !lines.isEmpty, !voices.isEmpty else { return false }
        // If the synthesizer never reports back (no output device, an engine error), give up so the
        // caller can show the transcript instead of a play button stuck on "Playing".
        // Measured: the standard Samantha voice takes about 58 ms per character at this rate; slower
        // premium voices need room, so allow 100 ms per character plus each line's pause.
        let characters = lines.map(\.text.count).reduce(0, +)
        let limit = Duration.milliseconds(characters * 100 + lines.count * 350 + 15_000)
        return await withCheckedContinuation { cont in
            continuation = cont
            remaining = lines.count
            watchdog = Task { [weak self] in
                try? await Task.sleep(for: limit)
                guard !Task.isCancelled, let self, self.continuation != nil else { return }
                self.synthesizer.stopSpeaking(at: .immediate)
                self.finish(false)
            }
            for line in lines {
                let utterance = AVSpeechUtterance(string: line.text)
                utterance.voice = voices[VoicePicker.key(line)] ?? voices.values.first
                utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
                utterance.postUtteranceDelay = 0.35
                synthesizer.speak(utterance)
            }
        }
    }

    func voiceLabel(for lines: [SpeechLine]) -> String? { "system voice" }

    func stop() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        finish(false)
    }

    fileprivate func utteranceFinished() {
        remaining -= 1
        if remaining <= 0 { finish(true) }
    }

    fileprivate func finish(_ ok: Bool) {
        watchdog?.cancel()
        watchdog = nil
        continuation?.resume(returning: ok)
        continuation = nil
        remaining = 0
    }
}

extension SystemSpeaker: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.utteranceFinished() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finish(false) }
    }
}
