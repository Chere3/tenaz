import AVFoundation

/// Picks the installed English voices for a script: highest quality first (premium > enhanced >
/// default), US or UK English, never the novelty or Eloquence voices, and a different voice for
/// each speaker.
enum VoicePicker {
    static func key(_ line: SpeechLine) -> String { line.speaker ?? line.voice ?? "narrator" }

    static func candidates() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { ["en-US", "en-GB"].contains($0.language) }
            .filter { !$0.identifier.contains("speech.synthesis.voice") && !$0.identifier.contains("eloquence") }
            .sorted { a, b in
                if a.quality.rawValue != b.quality.rawValue { return a.quality.rawValue > b.quality.rawValue }
                if a.language != b.language { return a.language == "en-US" }
                return a.identifier < b.identifier
            }
    }

    /// One voice per speaker key, matching the requested gender when a voice of it exists.
    static func cast(for lines: [SpeechLine]) -> [String: AVSpeechSynthesisVoice] {
        let pool = candidates()
        guard !pool.isEmpty else { return [:] }
        var used: Set<String> = []
        var cast: [String: AVSpeechSynthesisVoice] = [:]
        for line in lines where cast[key(line)] == nil {
            let wanted: AVSpeechSynthesisVoiceGender? = switch line.voice {
            case "female": .female
            case "male": .male
            default: nil
            }
            let fresh = pool.filter { !used.contains($0.identifier) }
            let pick = fresh.first { wanted == nil || $0.gender == wanted }
                ?? pool.first { wanted == nil || $0.gender == wanted }
                ?? fresh.first ?? pool[0]
            used.insert(pick.identifier)
            cast[key(line)] = pick
        }
        return cast
    }

    /// For the intro screen: the best voice's name and quality, or nil when none is installed.
    static func bestVoiceDescription() -> String? {
        guard let v = candidates().first else { return nil }
        let quality = switch v.quality {
        case .premium: "premium"
        case .enhanced: "enhanced"
        default: "standard"
        }
        return "\(v.name) (\(quality))"
    }
}
