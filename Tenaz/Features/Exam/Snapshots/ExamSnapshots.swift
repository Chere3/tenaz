import Foundation
import SwiftUI
import TenazCore

/// Deterministic exam screens for `--tenaz-snapshot`: real blueprints and real bank items on a
/// throwaway in-memory database, a test clock, and drafts filled in as if mid-answer.
enum ExamSnapshots {
    static let examSize = CGSize(width: 1440, height: 900)
    static let windowSize = CGSize(width: 1180, height: 760)

    // MARK: Runner screens

    /// A placement (or daily) runner positioned on the first task of `kind` in section `sectionId`.
    static func runner(_ env: AppEnvironment, exam: ExamKind = .placement, section sectionId: String, kind: ExamTaskKind,
                       skip: Int = 0, elapsed: TimeInterval = 150, start: Bool = true,
                       fill: (inout ExamDraft, ExamTask) -> Void = { _, _ in }) -> ExamRunner? {
        guard let blueprint = env.blueprints.blueprint(for: exam), let db = try? TenazDatabase.inMemory() else { return nil }
        let store = ExamStore(database: db)
        let clock = TestClock()
        var session = ExamSession(blueprint: blueprint, library: env.content, priors: (try? store.priors(for: exam)) ?? [:],
                                  seed: 2026, clock: clock)
        try? store.begin(session)
        while let section = session.currentSection, section.id != sectionId { session.endSection() }
        var skipped = 0
        while let task = session.currentTask, ExamTaskKind(task) != kind || skipped < skip {
            if ExamTaskKind(task) == kind { skipped += 1 }
            session.answer(nil)
        }
        let runner = ExamRunner(session: session, store: store, clock: clock, examMode: exam != .daily)
        runner.autoTick = false
        runner.speaker = SilentSpeaker()
        runner.witness = .watching
        guard start else { return runner }
        runner.startSection()
        clock.advance(by: elapsed)
        runner.tick()
        if let task = runner.task { fill(&runner.draft, task) }
        return runner
    }

    static func runnerView(_ runner: ExamRunner?) -> AnyView {
        guard let runner else { return AnyView(Text("no content")) }
        return AnyView(ExamRunnerView(runner: runner))
    }

    static func completeWords(_ env: AppEnvironment) -> AnyView {
        runnerView(runner(env, section: "reading", kind: .completeWords, elapsed: 95) { draft, task in
            let gaps = CompleteWordsParser.gaps(task.item?.passage ?? "")
            for i in 0..<min(4, gaps.count) { draft.gaps[i] = gaps[i].hidden }
            if gaps.count > 4 { draft.gaps[4] = String(gaps[4].hidden.prefix(1)) }
        })
    }

    static func reading(_ env: AppEnvironment) -> AnyView {
        runnerView(runner(env, section: "reading", kind: .reading, elapsed: 260) { draft, task in
            draft.choices[0] = task.item?.questions?.first?.answer
            draft.questionIndex = min(1, draft.choices.count - 1)
        })
    }

    /// The intro card before the reading section (timer stopped, Tena focused).
    static func sectionIntro(_ env: AppEnvironment) -> AnyView {
        runnerView(runner(env, section: "reading", kind: .completeWords, start: false))
    }

    static func listening(_ env: AppEnvironment) -> AnyView {
        runnerView(runner(env, section: "listening", kind: .listening, elapsed: 330) { draft, _ in
            draft.plays = 1
            draft.choices[0] = 2
        })
    }

    static func buildSentence(_ env: AppEnvironment) -> AnyView {
        runnerView(runner(env, section: "grammar", kind: .buildSentence, skip: 1, elapsed: 70) { draft, task in
            guard let item = task.item, let chunks = item.chunks, let answer = item.answer?.text else { return }
            // Place the first two pieces of the right answer, in order.
            let ordered = chunks.indices.sorted { a, b in
                (answer.range(of: chunks[a])?.lowerBound ?? answer.endIndex) < (answer.range(of: chunks[b])?.lowerBound ?? answer.endIndex)
            }
            draft.order = Array(ordered.prefix(2))
        })
    }

    static func writing(_ env: AppEnvironment) -> AnyView {
        runnerView(runner(env, section: "email", kind: .writing, elapsed: 205) { draft, _ in
            draft.text = """
            Dear Elena,

            I hope you are well. Two weeks ago I sent you my proposal for the new reporting tool. It helps \
            our team build the weekly reports automatically, so we save around five hours every week.

            I'm writing again because the budget discussion is next week, and a decision before then would
            """
        })
    }

    static func speakingTyped(_ env: AppEnvironment) -> AnyView {
        runnerView(runner(env, section: "interview", kind: .interview, elapsed: 50) { draft, _ in
            draft.texts[0] = "Yes, a few years ago I wanted to start a small company that builds dashboards for clinics. The idea was that doctors could see their patients data in one place, because "
        })
    }

    static func dailyQuestion(_ env: AppEnvironment) -> AnyView {
        guard let blueprint = env.blueprints.blueprint(for: .daily),
              let mixed = blueprint.sections.first(where: { $0.adaptive != nil }) else { return AnyView(Text("no content")) }
        let runner = runner(env, exam: .daily, section: mixed.id, kind: .grammar, elapsed: 40) { draft, _ in
            draft.choices[0] = 1
        } ?? runner(env, exam: .daily, section: mixed.id, kind: .vocab, elapsed: 40)
        return runnerView(runner)
    }

    // MARK: Main-window screens

    static func placementIntro(_ env: AppEnvironment) -> AnyView {
        let state = PlacementEntryState.load(blueprint: env.blueprints.blueprint(for: .placement), store: nil)
        return AnyView(PlacementIntroView(state: state, witness: .watching, pledged: true))
    }

    static func results(_ env: AppEnvironment) -> AnyView {
        let fixes = decode([GradeError].self, """
        [{"span": "depends of the topic", "category": "preposition", "correction": "depends on the topic",
          "rule_short": "We say depend ON something, not depend of (Spanish: depender de)."},
         {"span": "My job consist in automate", "category": "verb_pattern", "correction": "My job consists of automating",
          "rule_short": "After a preposition, use the -ing form. Add -s for he/she/it."},
         {"span": "Is very interesting", "category": "missing_subject", "correction": "It is very interesting",
          "rule_short": "English needs a subject: start with It."}]
        """) ?? []
        let start: Int64 = 1_792_000_000_000 - 47 * 60_000
        let timeline = decode([IntegrityTimelineEntry].self, """
        [{"startTs": \(start + 12 * 60_000), "endTs": \(start + 12 * 60_000 + 1_000), "kind": "focusLoss", "label": "Finder (hidden)", "severity": "info"}]
        """) ?? []
        let skills: [ExamResultModel.SkillRow] = [
            .init(skill: .reading, band: 4.0, low: 3.5, high: 4.5),
            .init(skill: .listening, band: 3.5, low: 3.0, high: 4.0),
            .init(skill: .writing, band: 3.5, low: 3.0, high: 4.0),
            .init(skill: .speaking, pending: true),
            .init(skill: .grammar, band: 4.0, low: 3.5, high: 4.5),
        ]
        let model = ExamResultModel(fixture: .placement, overall: 3.5, low: 3.5, high: 4.0, skills: skills, corrections: fixes,
                                    integrity: .clean, timeline: timeline, grading: .running, provisional: true, minutes: 47)
        return AnyView(ExamResultsView(model: model))
    }

    static func history(_ env: AppEnvironment) -> AnyView {
        let day: TimeInterval = 86_400
        let now = Date(timeIntervalSince1970: 1_794_400_000)
        func at(_ days: Double, _ hour: Double) -> Date { now.addingTimeInterval(-days * day + hour * 3600) }
        var state = ExamsOverviewState()
        state.history = [
            ExamAttemptSummary(id: "w1", kind: .weekly, startedAt: at(1, 10), status: "done", overall: 4.0, low: 3.5, high: 4.0,
                               integrity: .warning, integrityConfirmed: true,
                               skillBands: [.reading: 4.0, .listening: 4.0, .writing: 3.5, .speaking: 3.5]),
            ExamAttemptSummary(id: "d3", kind: .daily, startedAt: at(2, 9), status: "done", overall: 4.0, integrity: .clean,
                               skillBands: [.reading: 4.0, .listening: 3.5]),
            ExamAttemptSummary(id: "d2", kind: .daily, startedAt: at(4, 13), status: "void"),
            ExamAttemptSummary(id: "d1", kind: .daily, startedAt: at(6, 8.5), status: "done", overall: 3.5, integrity: .clean,
                               skillBands: [.reading: 3.5, .listening: 3.5]),
            ExamAttemptSummary(id: "p1", kind: .placement, startedAt: at(9, 8), status: "done", overall: 3.5, low: 3.5, high: 4.0,
                               integrity: .clean, skillBands: [.reading: 4.0, .listening: 3.5, .writing: 3.5, .speaking: 3.0]),
        ]
        state.placementDone = at(9, 8)
        state.weekly = .open
        state.monthly = .locked("opens Nov 20")
        return AnyView(ExamsOverview(state: state))
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ json: String) -> T? {
        try? JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
}
