import CryptoKit
import Foundation

/// Which Kokoro voice says each line of one spoken item, and the file name of its pre-rendered
/// audio. `scripts/tts/cast.py` mirrors this exactly; both are checked against
/// `Tests/TenazCoreTests/Fixtures/voice-cast-golden.json` so they cannot drift.
///
/// Rule: speakers in order of first appearance (key = speaker, else voice, else "narrator");
/// "male" lines take the male pool, everything else the female pool. Each item gets a rotation
/// offset from the sha256 of its line texts, so different items get different voices and accents;
/// the n-th speaker of a gender takes `pool[(offset % count + n) % count]`, skipping voices already
/// used in the item, so two speakers never share a voice.
public enum VoiceCast {
    public struct Line: Codable, Hashable, Sendable {
        public var text: String
        public var voice: String?
        public var speaker: String?

        public init(text: String, voice: String? = nil, speaker: String? = nil) {
            self.text = text
            self.voice = voice
            self.speaker = speaker
        }
    }

    public static let model = "kokoro-v1.0"
    /// A string so both languages hash the same bytes (no float formatting).
    public static let speed = "0.95"
    /// Best-rated Kokoro English voices, US and UK interleaved so neighbours differ in accent.
    public static let female = ["af_heart", "bf_emma", "af_bella", "bf_isabella", "af_aoede", "af_sarah"]
    public static let male = ["am_michael", "bm_george", "am_fenrir", "bm_fable", "am_puck"]

    public static func speakerKey(_ line: Line) -> String { line.speaker ?? line.voice ?? "narrator" }

    /// First 8 bytes (big-endian) of sha256 of the line texts joined by "\n".
    public static func offset(_ lines: [Line]) -> UInt64 {
        let digest = SHA256.hash(data: Data(lines.map(\.text).joined(separator: "\n").utf8))
        return digest.prefix(8).reduce(0) { $0 << 8 | UInt64($1) }
    }

    /// Speaker key → Kokoro voice name.
    public static func cast(_ lines: [Line]) -> [String: String] {
        let shift = offset(lines)
        var cast: [String: String] = [:]
        var used: Set<String> = []
        var femaleCount = 0
        var maleCount = 0
        for line in lines where cast[speakerKey(line)] == nil {
            let isMale = line.voice == "male"
            let pool = isMale ? male : female
            let other = isMale ? female : male
            let start = (Int(shift % UInt64(pool.count)) + (isMale ? maleCount : femaleCount)) % pool.count
            let otherStart = Int(shift % UInt64(other.count))
            let pick = rotated(pool, from: start).first { !used.contains($0) }
                ?? rotated(other, from: otherStart).first { !used.contains($0) }
                ?? pool[start]
            if isMale { maleCount += 1 } else { femaleCount += 1 }
            used.insert(pick)
            cast[speakerKey(line)] = pick
        }
        return cast
    }

    /// The voice of every line, in order.
    public static func voices(_ lines: [Line]) -> [String] {
        let assigned = cast(lines)
        return lines.map { assigned[speakerKey($0)]! }
    }

    /// sha256 hex of "kokoro-v1.0|<voice>|0.95|<text>".
    public static func cacheKey(voice: String, text: String) -> String {
        let digest = SHA256.hash(data: Data("\(model)|\(voice)|\(speed)|\(text)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func fileName(voice: String, text: String) -> String { cacheKey(voice: voice, text: text) + ".m4a" }

    /// The cache file of every line, in order.
    public static func fileNames(_ lines: [Line]) -> [String] {
        zip(lines, voices(lines)).map { fileName(voice: $1, text: $0.text) }
    }

    private static func rotated(_ pool: [String], from start: Int) -> [String] {
        Array(pool[start...] + pool[..<start])
    }
}
