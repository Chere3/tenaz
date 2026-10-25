import Foundation
import TenazCore

/// `--tenaz-selftest placement-flow`: drives the real exam view models through every placement
/// section with simulated answers (seeded, deterministic), pauses between sections 2 and 3 and
/// resumes by replay, submits, sends ONE real writing task to Claude through the app's shared queue (or prints
/// "claude unavailable"), runs the Tivra witness read-only, credits gamification, and prints the
/// result model. Runs on the automation in-memory database; touches no real data.
extension SelfTest {
    static func placementFlow(environment env: AppEnvironment) async -> Int32 {
        guard let blueprint = env.blueprints.blueprint(for: .placement), let database = env.database else {
            print("placement-flow: no placement blueprint or database")
            return 1
        }
        let store = ExamStore(database: database)
        let voices = VoicePicker.candidates()
        print("listening: Kokoro neural voices from the audio cache (--tenaz-selftest audio for coverage); system fallback: "
            + "english voices: \(voices.count); best \(VoicePicker.bestVoiceDescription() ?? "none (listening falls back to text)"); "
            + "cast for A/B: \(VoicePicker.cast(for: [SpeechLine(text: "", voice: "female", speaker: "A"), SpeechLine(text: "", voice: "male", speaker: "B")]).mapValues(\.name).sorted { $0.key < $1.key })")
        do {
            var runner = try ExamRunner.begin(blueprint, library: env.content, store: store, examMode: true, seed: 42,
                                              clock: TestClock())
            configure(runner)
            var learner = SimulatedLearner(theta: 0.0, seed: 7)
            var wroteEmail = false
            var steps = 0
            var paused = false
            while runner.phase != .finished, steps < 400 {
                steps += 1
                switch runner.phase {
                case .intro:
                    if runner.sectionNumber == 3, !paused {
                        let expected = runner.task?.id
                        runner.pauseBetweenSections()
                        runner = try ExamRunner.resume(runner.session.id, catalog: env.blueprints, library: env.content, store: store)
                        configure(runner)
                        paused = true
                        print("paused before section 3, resumed by replay: \(runner.task?.id == expected ? "same task" : "MISMATCH")")
                        guard runner.task?.id == expected else { return 1 }
                    }
                    print("section \(runner.sectionNumber): \(runner.section?.title ?? "?") (\(runner.session.sectionLength) tasks, \(Int(runner.section?.minutes ?? 0)) min)")
                    runner.startSection()
                case .task:
                    guard let task = runner.task else { return 1 }
                    if ExamTaskKind(task) == .writing, !wroteEmail, task.item?.type == .writeEmail {
                        runner.draft.text = fixtureEmail
                        wroteEmail = true
                    } else if ExamTaskKind(task) == .writing || ExamTaskKind(task) == .interview {
                        // Left empty on purpose: scored 0 locally, no Claude call (one real call only).
                    } else {
                        fill(&runner.draft, task: task, with: learner.answer(task))
                    }
                    for _ in 0..<runner.questionCount(task) where runner.phase == .task && runner.task?.id == task.id {
                        runner.next()
                    }
                default:
                    print("unexpected phase \(runner.phase)")
                    return 1
                }
            }
            guard runner.phase == .finished, let outcome = runner.outcome else {
                print("placement-flow: did not finish (\(steps) steps)")
                return 1
            }
            let attemptId = runner.session.id
            print("submitted \(runner.session.tasks.count) tasks in \(Set(runner.session.tasks.map(\.sectionId)).count) sections; "
                + "pending grades: \(outcome.pendingSkills.map(\.rawValue)) (about-you and interview left empty: no Claude call)")

            if env.claude.isAvailable {
                let report = await env.grading.drainNow()
                print(report.graded.isEmpty ? "claude unavailable (\(report))" : "claude graded \(report.graded.count) job(s)")
            } else {
                print("claude unavailable (no CLI at \(env.claude.executable.path))")
            }

            let model = ExamResultModel(attemptId: attemptId, kind: .placement, store: store)
            await model.verifyIntegrity(store: store, denyList: ExamCenter.loadDenyList(), reader: TivraReader())
            model.credit(store: store, gamification: env.gamification)
            model.reload()
            printResult(model)
            let evidence = try env.gamification?.stageEvidence()
            print("stage evidence: placementDone \(evidence?.placementDone ?? false) placementBand \(evidence?.placementBand.map { BandWords.format($0) } ?? "nil")")
            let ok = model.overall != nil && model.integrity != nil && (evidence?.placementDone ?? false)
            print(ok ? "placement-flow OK" : "placement-flow FAIL")
            return ok ? 0 : 1
        } catch {
            print("placement-flow error: \(error)")
            return 1
        }
    }

    private static func configure(_ runner: ExamRunner) {
        runner.autoTick = false
        runner.speaker = SilentSpeaker()
    }

    /// Puts a simulated answer into the draft the way the item views would.
    private static func fill(_ draft: inout ExamDraft, task: ExamTask, with answer: ExamAnswer) {
        switch answer {
        case let .choices(c): draft.choices = c
        case let .gaps(g): draft.gaps = g
        case let .texts(t): draft.texts = t
        case let .text(sentence):
            guard let chunks = task.item?.chunks, task.item?.type == .buildSentence else {
                draft.text = sentence
                return
            }
            draft.order = order(of: chunks, in: sentence)
        }
    }

    /// Chunk indices in the order they appear in `sentence` (greedy, left to right).
    private static func order(of chunks: [String], in sentence: String) -> [Int] {
        var rest = Substring(sentence)
        var used: [Int] = []
        while !rest.isEmpty {
            rest = rest.drop { $0 == " " }
            guard let i = chunks.indices.first(where: { !used.contains($0) && rest.hasPrefix(chunks[$0]) }) else { break }
            used.append(i)
            rest = rest.dropFirst(chunks[i].count)
        }
        return used.count == chunks.count ? used : Array(chunks.indices.reversed())
    }

    private static func printResult(_ m: ExamResultModel) {
        let band = m.overall ?? 0
        print("RESULT placement: overall \(BandWords.format(band)) (\(BandWords.format(m.overallLow ?? band)) to \(BandWords.format(m.overallHigh ?? band))) "
            + "\(BandWords.label(band)) \(m.provisional ? "provisional" : "final") \(BandWords.ielts(band))")
        for s in m.skills {
            let text = s.pending ? "pending" : s.band.map { "\(BandWords.format($0)) \(BandWords.label($0))" } ?? "none"
            print("  \(s.skill.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0)) \(text)\(s.failed ? " (objective only)" : "")")
        }
        print("  integrity \(m.integrity?.rawValue ?? "nil") problems \(m.integrityProblems) timeline \(m.timeline.count)")
        print("  corrections \(m.corrections.map { "\($0.span) -> \($0.correction)" })")
        print("  feedback \(m.feedback ?? "-") xp \(m.xpGained.map(String.init) ?? "-") stageAdvanced \(m.stageAdvanced)")
    }

    static let fixtureEmail = """
    Dear Elena,

    I hope you are well. Two weeks ago I sent you my proposal for the new reporting tool, and I wanted to \
    follow up because I didn't receive any answer yet. The tool automate the weekly reports, so our team \
    could save around five hours every week. A decision before the budget meeting next week would help us \
    to plan the work for the next quarter. If it is useful, I can present the main points in a short \
    meeting of fifteen minutes. Please let me know what time works for you.

    Best regards,
    Sam
    """
}
