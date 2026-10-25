import AVFoundation
import TenazCore

/// Plays listening scripts with the Kokoro neural voices pre-rendered by `scripts/tts/render.py`
/// into the audio cache (one `<sha256>.m4a` per line, voices from `VoiceCast`), 0.35 s apart.
/// When any line of the item has no file, the whole item goes to the system voice instead, so one
/// script never mixes the two. Never used in automation (ExamRunner keeps `SilentSpeaker` there).
@MainActor
final class NeuralSpeaker: NSObject, ExamSpeaking {
    private let cache: URL
    private let fallback: SystemSpeaker
    private var player: AVAudioPlayer?
    private var queue: [AVAudioPlayer] = []
    private var continuation: CheckedContinuation<Bool, Never>?
    private var watchdog: Task<Void, Never>?
    private var gap: Task<Void, Never>?

    init(cache: URL = Paths.forApp(bundleIdentifier: Bundle.main.bundleIdentifier).audioCache,
         fallback: SystemSpeaker = SystemSpeaker()) {
        self.cache = cache
        self.fallback = fallback
        super.init()
    }

    /// The cached file of every line, or nil when any is missing.
    static func files(for lines: [SpeechLine], in cache: URL) -> [URL]? {
        guard !lines.isEmpty else { return nil }
        let urls = VoiceCast.fileNames(lines.map(\.castLine)).map { cache.appendingPathComponent($0) }
        return urls.allSatisfy { FileManager.default.fileExists(atPath: $0.path) } ? urls : nil
    }

    func voiceLabel(for lines: [SpeechLine]) -> String? {
        Self.files(for: lines, in: cache) != nil ? "neural voices" : "system voice"
    }

    func speak(_ lines: [SpeechLine]) async -> Bool {
        stop()
        guard let urls = Self.files(for: lines, in: cache),
              let players = try? urls.map({ try AVAudioPlayer(contentsOf: $0) }) else {
            return await fallback.speak(lines)
        }
        for p in players {
            p.delegate = self
            p.prepareToPlay()
        }
        // If playback never reports back (no output device), give up so the caller shows the transcript.
        let audio: TimeInterval = players.reduce(0) { $0 + $1.duration }
        let gaps: TimeInterval = Double(players.count) * 0.35
        let limit = Duration.seconds(audio + gaps + 10)
        return await withCheckedContinuation { cont in
            continuation = cont
            queue = players
            watchdog = Task { [weak self] in
                try? await Task.sleep(for: limit)
                guard !Task.isCancelled, let self, self.continuation != nil else { return }
                self.finish(false)
            }
            playNext()
        }
    }

    func stop() {
        fallback.stop()
        finish(false)
    }

    private func playNext() {
        guard continuation != nil else { return }
        guard !queue.isEmpty else { return finish(true) }
        let next = queue.removeFirst()
        player = next
        if !next.play() { finish(false) }
    }

    fileprivate func lineFinished(_ id: ObjectIdentifier, ok: Bool) {
        // A callback from a player already stopped (stop(), a newer speak) is stale.
        guard let player, ObjectIdentifier(player) == id, continuation != nil else { return }
        guard ok else { return finish(false) }
        guard !queue.isEmpty else { return finish(true) }
        gap = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            self?.playNext()
        }
    }

    private func finish(_ ok: Bool) {
        watchdog?.cancel()
        watchdog = nil
        gap?.cancel()
        gap = nil
        player?.stop()
        player = nil
        queue = []
        continuation?.resume(returning: ok)
        continuation = nil
    }
}

extension NeuralSpeaker: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let id = ObjectIdentifier(player)
        Task { @MainActor in self.lineFinished(id, ok: flag) }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        let id = ObjectIdentifier(player)
        Task { @MainActor in self.lineFinished(id, ok: false) }
    }
}

extension SpeechLine {
    var castLine: VoiceCast.Line { VoiceCast.Line(text: text, voice: voice, speaker: speaker) }
}
