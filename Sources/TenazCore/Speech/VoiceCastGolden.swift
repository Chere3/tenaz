import Foundation

/// `voice-cast-golden.json` (written by `scripts/tts/cast.py --write-golden`): inputs and the
/// expected voices and cache keys. The Swift tests, the Python tests and `--tenaz-selftest audio`
/// all check their rule against it.
public struct VoiceCastGolden: Decodable, Sendable {
    public struct Case: Decodable, Sendable {
        public var name: String
        public var lines: [VoiceCast.Line]
        /// Decimal string: a UInt64 does not survive every JSON parser as a number.
        public var offset: String
        public var voices: [String]
        public var keys: [String]
    }

    public var model: String
    public var speed: String
    public var female: [String]
    public var male: [String]
    public var cases: [Case]

    public static func load(_ url: URL) throws -> VoiceCastGolden {
        try JSONDecoder().decode(VoiceCastGolden.self, from: Data(contentsOf: url))
    }

    /// One message per disagreement with `VoiceCast`; empty when the rule matches.
    public func mismatches() -> [String] {
        var out: [String] = []
        if model != VoiceCast.model { out.append("model \(model) != \(VoiceCast.model)") }
        if speed != VoiceCast.speed { out.append("speed \(speed) != \(VoiceCast.speed)") }
        if female != VoiceCast.female { out.append("female pool differs") }
        if male != VoiceCast.male { out.append("male pool differs") }
        for c in cases {
            if String(VoiceCast.offset(c.lines)) != c.offset { out.append("\(c.name): offset") }
            let voices = VoiceCast.voices(c.lines)
            if voices != c.voices { out.append("\(c.name): voices \(voices) != \(c.voices)") }
            if zip(c.lines, voices).map({ VoiceCast.cacheKey(voice: $1, text: $0.text) }) != c.keys { out.append("\(c.name): keys") }
        }
        return out
    }
}
