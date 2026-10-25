import AppKit
import Foundation
import TenazCore

/// `--tenaz-smoke exam`: Exam Mode with a 3-item fake section (grammar items from the bank) on the
/// automation in-memory database, closed by the panel's 3 s hard cap through the watchdog path.
/// Live meeting probes are off in automation, so a terminal's Calendar/Microphone grants can't
/// change the result. Writes an intrusion_log row, prints it and exits 0 only for the watchdog.
enum ExamSmoke {
    static let controller = ExamModeController()

    static let blueprintJSON = """
    {"id": "smoke-v1", "kind": "weekly", "title": "Smoke Exam",
     "sections": [{"id": "smoke", "title": "Grammar", "skill": "grammar", "minutes": 1,
                   "picks": [{"types": ["grammarMC"], "count": 3}]}]}
    """

    static func run(environment env: AppEnvironment) {
        guard let database = env.database,
              let blueprint = try? JSONDecoder().decode(ExamBlueprint.self, from: Data(blueprintJSON.utf8)),
              let runner = try? ExamRunner.begin(blueprint, library: env.content, store: ExamStore(database: database),
                                                 examMode: true, seed: 3) else {
            print("smoke exam: could not build the fake section")
            exit(1)
        }
        runner.speaker = SilentSpeaker()
        runner.witness = .watching
        var start = Date()
        controller.onClose = { exitReason in
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            try? database.writer.write { db in
                try db.execute(sql: """
                    INSERT INTO intrusion_log (ts, surface, trigger, decision, reason, outcome, durationMs)
                    VALUES (?, 'exam', 'smoke', 'allow', ?, 'timeout', ?)
                    """, arguments: [Int(start.timeIntervalSince1970 * 1000), "\(exitReason)", ms])
            }
            let rows = (try? database.reader.read { try Int.fetchOne($0, sql: "SELECT count(*) FROM intrusion_log") }) ?? nil
            let status = (try? ExamStore(database: database).progress(runner.session.id)?.pausedBetweenSections) ?? nil
            print("smoke exam closed by \(exitReason) after \(ms) ms with \(runner.session.tasks.count) tasks; "
                + "attempt kept for resume: \(status == true); intrusion_log rows: \(rows ?? 0)")
            // Only the watchdog path proves the escape works; a meeting close or a lost attempt fails.
            let ok = exitReason == .watchdog && status == true && ms <= 3_500
            if !ok { print("smoke exam FAILED: expected the watchdog within 3.5 s with the attempt kept") }
            exit(ok ? 0 : 1)
        }
        start = Date()
        controller.present(runner, denyList: DenyList(), hardCap: .milliseconds(2400))
        runner.startSection()
        runner.choose(1)
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            let key = NSApp.keyWindow
            print("exam panel key: \(key.map { String(describing: type(of: $0)) } ?? "none"); first responder: "
                + "\(key?.firstResponder.map { String(describing: type(of: $0)) } ?? "none"); chosen option \(runner.draft.choices.first.flatMap { $0 }.map(String.init) ?? "none")")
        }
    }
}
