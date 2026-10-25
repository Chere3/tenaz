import Foundation
import TenazCore

extension SelfTest {
    /// `--tenaz-selftest audio`: the voice-cast rule against the bundled golden vectors (the same file
    /// `scripts/tts/test_cast.py` checks), and how many spoken lines have neural audio in this build's
    /// cache. Plays nothing. Fails only on a cast mismatch; an empty cache is reported, not an error.
    static func audio(environment env: AppEnvironment) -> Int32 {
        var failed = false
        if let url = Bundle.main.url(forResource: "voice-cast-golden", withExtension: "json") {
            do {
                let golden = try VoiceCastGolden.load(url)
                let problems = golden.mismatches()
                print("cast golden: \(golden.cases.count) cases, \(problems.isEmpty ? "all match" : "MISMATCH")")
                problems.forEach { print("  \($0)") }
                failed = !problems.isEmpty
            } catch {
                print("cast golden: unreadable (\(error))")
                failed = true
            }
        } else {
            print("cast golden: not bundled")
            failed = true
        }

        let cache = env.paths.audioCache
        var lines = 0, cachedLines = 0, groups = 0, cachedGroups = 0
        var perType: [String: (lines: Int, cached: Int)] = [:]
        for item in env.content.items {
            let questions = item.type == .interview ? (item.interviewQuestions ?? []).indices.map { $0 } : [0]
            for q in questions {
                let spoken = ExamScript.lines(for: item, question: q)
                guard !spoken.isEmpty else { continue }
                let names = VoiceCast.fileNames(spoken.map(\.castLine))
                let have = names.filter { FileManager.default.fileExists(atPath: cache.appendingPathComponent($0).path) }.count
                lines += spoken.count
                cachedLines += have
                groups += 1
                if have == spoken.count { cachedGroups += 1 }
                perType[item.type.rawValue, default: (0, 0)].lines += spoken.count
                perType[item.type.rawValue, default: (0, 0)].cached += have
            }
        }
        let percent = lines == 0 ? 0 : cachedLines * 100 / lines
        print("neural audio: \(cachedLines)/\(lines) lines cached (\(percent)%), \(cachedGroups)/\(groups) scripts play neural, "
            + "the rest use the system voice; cache \(cache.path)")
        for (type, n) in perType.sorted(by: { $0.key < $1.key }) { print("  \(type): \(n.cached)/\(n.lines)") }
        return failed ? 1 : 0
    }
}
