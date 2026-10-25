import Foundation
import GRDB
import TenazCore

extension SelfTest {
    /// `--tenaz-selftest write`: the local writing checks, then one saved sentence on the in-memory
    /// database (a writing_entry row with a queued grade, and one production for today's minimum).
    static func write(environment env: AppEnvironment) -> Int32 {
        let prompt = TodaySummary.sample.write
        let english = WriteCheck(text: "Although I was nervous, I managed to explain the dashboard based on real data.", prompt: prompt)
        let spanish = WriteCheck(text: "Aunque estaba nervioso, logré explicar el tablero con datos reales de la empresa.", prompt: prompt)
        let short = WriteCheck(text: "It went well.", prompt: prompt)
        print("english: words \(english.words) targets \(english.targets.map { "\($0.0)=\($0.1)" }) canSubmit \(english.canSubmit) quality \(english.quality)")
        print("spanish: looksEnglish \(spanish.looksEnglish) canSubmit \(spanish.canSubmit)")
        print("short: words \(short.words) canSubmit \(short.canSubmit)")
        WriteSheet.store("Although I was nervous, I managed to explain the dashboard.", prompt: prompt, env: env)
        let effects = try? env.gamification?.handle(.productionDone(Production(refId: prompt?.id ?? "write", quality: english.quality, words: english.words)))
        let rows = (try? env.database?.reader.read { try Int.fetchOne($0, sql: "SELECT count(*) FROM writing_entry WHERE surface = 'write'") }) ?? nil
        // Queued for the app's one grading queue (not started in automation, so no Claude call here).
        let jobs = (try? env.database?.reader.read { try Int.fetchOne($0, sql: "SELECT count(*) FROM claude_job WHERE status = 'queued'") }) ?? nil
        let productions = (try? env.gamification?.state().today.productions) ?? 0
        print("writing_entry rows \(rows ?? 0) queued grades \(jobs ?? 0) productions today \(productions) xp \(effects?.xp ?? 0)")
        let ok = english.canSubmit && english.targets.allSatisfy(\.1) && !spanish.canSubmit && !short.canSubmit && rows == 1 && jobs == 1
            && productions == 1
        print(ok ? "write OK" : "write FAIL")
        return ok ? 0 : 1
    }
}
