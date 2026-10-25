import Foundation
import Testing
@testable import TenazCore

/// The cast rule against the golden vectors `scripts/tts/test_cast.py` also checks, so the app and
/// the renderer always agree on which voice (and which cache file) a line gets.
struct VoiceCastTests {
    func golden() throws -> VoiceCastGolden {
        let url = try #require(Bundle.module.url(forResource: "voice-cast-golden", withExtension: "json", subdirectory: "Fixtures"))
        return try VoiceCastGolden.load(url)
    }

    @Test func matchesGoldenVectors() throws {
        let g = try golden()
        #expect(g.cases.count >= 10)
        #expect(g.mismatches() == [])
    }

    @Test func mismatchesAreReported() throws {
        var g = try golden()
        g.cases[0].voices = ["nobody"]
        g.cases[1].keys = ["0"]
        #expect(g.mismatches().count == 2)
    }

    @Test func speakersNeverShareAVoice() throws {
        for c in try golden().cases {
            let cast = VoiceCast.cast(c.lines)
            #expect(Set(cast.values).count == cast.count, "\(c.name)")
        }
    }

    @Test func gendersComeFromTheirPools() {
        let lines = [VoiceCast.Line(text: "Hi.", voice: "female", speaker: "A"),
                     VoiceCast.Line(text: "Hello.", voice: "male", speaker: "B"),
                     VoiceCast.Line(text: "Narrator here.")]
        let cast = VoiceCast.cast(lines)
        #expect(VoiceCast.female.contains(cast["A"]!))
        #expect(VoiceCast.male.contains(cast["B"]!))
        #expect(VoiceCast.female.contains(cast["narrator"]!))
    }

    @Test func differentItemsRotateVoices() {
        let picks = Set((0..<40).map { VoiceCast.voices([VoiceCast.Line(text: "Sentence number \($0).", voice: "female")])[0] })
        #expect(picks.count == VoiceCast.female.count)
    }

    @Test func fileNameIsKeyPlusM4A() {
        let name = VoiceCast.fileName(voice: "af_heart", text: "Hello.")
        #expect(name.hasSuffix(".m4a"))
        #expect(name.count == 64 + 4)
    }
}
