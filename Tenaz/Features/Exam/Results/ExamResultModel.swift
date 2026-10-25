import Foundation
import Observation
import TenazCore

/// Everything the results screen shows for one attempt, and the work that fills it after submit:
/// the Tivra witness verdict (read-only), Claude grading through the queue, and the gamification
/// credit (once per attempt). Snapshots build it from values and never call `start`.
@Observable
final class ExamResultModel {
    struct SkillRow: Identifiable, Equatable {
        var skill: ExamSkill
        var band: Double?
        var low: Double?
        var high: Double?
        /// Claude hasn't graded this skill yet.
        var pending = false
        /// Grading gave up (Claude failed 4 times): the band is the objective part only.
        var failed = false
        var id: ExamSkill { skill }
    }

    enum Grading: Equatable {
        case none
        case running
        case done
        /// Claude isn't reachable now; the jobs stay queued.
        case unavailable(String)
    }

    let attemptId: String
    let kind: ExamKind
    private(set) var startedAt: Date
    private(set) var endedAt: Date?
    private(set) var overall: Double?
    private(set) var overallLow: Double?
    private(set) var overallHigh: Double?
    /// The overall still includes a skill at its prior while a grade is pending.
    private(set) var provisional = false
    private(set) var skills: [SkillRow] = []
    private(set) var corrections: [GradeError] = []
    private(set) var feedback: String?
    private(set) var integrity: IntegrityLevel?
    private(set) var integrityConfirmed = false
    private(set) var timeline: [IntegrityTimelineEntry] = []
    private(set) var integrityProblems: [String] = []
    private(set) var grading: Grading = .none
    private(set) var readInstead = 0
    private(set) var typedSpeaking = 0
    private(set) var xpGained: Int?
    private(set) var stageAdvanced = false
    private(set) var loadProblem: String?

    @ObservationIgnored private let store: ExamStore?
    @ObservationIgnored private var work: Task<Void, Never>?
    /// Called once the witness, grading and credit are all done (the owner can let go then).
    @ObservationIgnored var onWorkDone: () -> Void = {}

    init(attemptId: String, kind: ExamKind, store: ExamStore?) {
        self.attemptId = attemptId
        self.kind = kind
        self.store = store
        startedAt = .now
        reload()
    }

    /// Fixture values for snapshots and previews.
    init(fixture kind: ExamKind, overall: Double, low: Double, high: Double, skills: [SkillRow], corrections: [GradeError],
         integrity: IntegrityLevel?, timeline: [IntegrityTimelineEntry], grading: Grading, provisional: Bool, minutes: Double) {
        attemptId = "fixture"
        self.kind = kind
        store = nil
        endedAt = Date(timeIntervalSince1970: 1_792_000_000)
        startedAt = Date(timeIntervalSince1970: 1_792_000_000 - minutes * 60)
        self.overall = overall
        overallLow = low
        overallHigh = high
        self.skills = skills
        self.corrections = corrections
        self.integrity = integrity
        self.timeline = timeline
        self.grading = grading
        self.provisional = provisional
        feedback = corrections.isEmpty ? nil : "Clear ideas and good connectors. Watch prepositions after verbs."
    }

    var minutes: Int { Int(((endedAt ?? .now).timeIntervalSince(startedAt) / 60).rounded()) }
    var pendingCount: Int { skills.count { $0.pending } }
    var countsForPromotion: Bool { integrity?.counts(confirmed: integrityConfirmed) ?? false }

    // MARK: Loading

    func reload() {
        guard let store else { return }
        do {
            guard let attempt = try store.attempt(attemptId) else { return }
            startedAt = Date(timeIntervalSince1970: Double(attempt.startedAt) / 1000)
            endedAt = attempt.endedAt.map { Date(timeIntervalSince1970: Double($0) / 1000) }
            integrity = attempt.integrity.flatMap(IntegrityLevel.init(rawValue:))
            integrityConfirmed = attempt.integrityConfirmed
            if let json = attempt.integrityJSON, let verdict = try? JSONDecoder().decode(IntegrityVerdict.self, from: Data(json.utf8)) {
                timeline = verdict.timeline
                integrityProblems = verdict.problems
            }
            let bands = try store.bands(attemptId: attemptId)
            let entries = try store.writingEntries(attemptId: attemptId)
            let pendingSkills = Set(entries.filter { $0.gradeStatus == "pending" }.compactMap { $0.skill.flatMap(ExamSkill.init(rawValue:)) })
            let failedSkills = Set(entries.filter { $0.gradeStatus == "failed" }.compactMap { $0.skill.flatMap(ExamSkill.init(rawValue:)) })
            let responses = try store.responses(attemptId: attemptId)
            let touched = Set(responses.compactMap { ExamSkill(rawValue: $0.skill) })
            let skillOrder: [ExamSkill] = kind == .placement ? ExamSkill.allCases : ExamSkill.allCases.filter { touched.contains($0) }
            skills = skillOrder.map { skill in
                let row = bands.last { $0.skill == skill.rawValue }
                return SkillRow(skill: skill, band: row?.band, low: row?.low, high: row?.high,
                                pending: pendingSkills.contains(skill),
                                failed: failedSkills.contains(skill))
            }
            if let row = bands.last(where: { $0.skill == BandHistoryRecord.overall }) {
                overall = row.band
                overallLow = row.low
                overallHigh = row.high
                provisional = false
            } else {
                let estimate = OverallBand(estimates: try store.skillStates())
                overall = estimate.band
                overallLow = estimate.low
                overallHigh = estimate.high
                provisional = true
            }
            var fixes: [GradeError] = []
            for entry in entries where entry.gradeStatus == "graded" {
                guard let json = entry.gradeJSON,
                      let grade = try? JSONDecoder().decode(WritingGrade.self, from: Data(json.utf8)),
                      let run = grade.runs.first else { continue }
                fixes += run.errors
                if feedback == nil, !run.feedbackLine.isEmpty { feedback = run.feedbackLine }
            }
            corrections = Array(fixes.prefix(3))
            let notes = try store.progress(attemptId)?.noteMap ?? [:]
            readInstead = notes.values.count { $0 == ExamNote.readInstead }
            typedSpeaking = notes.values.count { $0 == ExamNote.typedInstead }
        } catch {
            loadProblem = "Couldn't read the results: \(error.localizedDescription)"
        }
    }

    // MARK: Work after submit

    /// Runs while the results screen is open: witness, grading, credit. Safe to call twice.
    func start(grading: GradingService, gamification: GamificationEngine?, denyList: DenyList, reader: TivraReader) {
        guard work == nil, let store else { return }
        work = Task { [weak self] in
            await self?.verifyIntegrity(store: store, denyList: denyList, reader: reader)
            // The placement counts for Tena's stage at once (provisional band); credit() sets the final one.
            self?.recordPlacement(gamification: gamification)
            await self?.grade(store: store, service: grading)
            self?.credit(store: store, gamification: gamification)
            self?.onWorkDone()
        }
    }

    /// The learner confirms a WARNING ("that was me, not AI help"): the attempt then counts.
    func confirmWarning() {
        guard let store, integrity == .warning else { return }
        let json = try? store.attempt(attemptId)?.integrityJSON
        try? store.setIntegrity(attemptId: attemptId, .warning, confirmed: true, json: json ?? nil)
        reload()
    }

    func verifyIntegrity(store: ExamStore, denyList: DenyList, reader: TivraReader) async {
        guard integrity == nil, let attempt = try? store.attempt(attemptId) else { return }
        let window = TivraWindow(startTs: attempt.startedAt, endTs: attempt.endedAt ?? Int64(Date.now.timeIntervalSince1970 * 1000))
        let evidence = await reader.evidence(window: window)
        let events = (try? store.integrityEvents(attemptId: attemptId)) ?? []
        let verdict = IntegrityVerifier(denyList: denyList).verdict(
            examId: attemptId, window: window, verifiedTs: Int64(Date.now.timeIntervalSince1970 * 1000),
            tivra: evidence, tenazEvents: events)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = (try? encoder.encode(verdict)).map { String(decoding: $0, as: UTF8.self) }
        try? store.setIntegrity(attemptId: attemptId, verdict.verdict, json: json)
        reload()
    }

    /// Grades this attempt's writing through the app's one queue and follows it: the queue reports
    /// after every job, and a minute without news drains again (a retried job is due by then).
    private func grade(store: ExamStore, service: GradingService) async {
        guard (try? store.openJobCount(attemptId: attemptId)) ?? 0 > 0 else {
            grading = pendingCount > 0 ? .unavailable("Claude couldn't grade yet.") : .done
            return
        }
        guard service.cli.isAvailable else {
            grading = .unavailable("Claude Code isn't installed on this Mac.")
            return
        }
        grading = .running
        var report = await service.drainNow()
        let giveUp = Date.now.addingTimeInterval(8 * 60)
        while !Task.isCancelled {
            reload()
            if (try? store.openJobCount(attemptId: attemptId)) ?? 0 == 0 {
                grading = .done
                return
            }
            if report.unavailable {
                grading = .unavailable("Claude is busy or at its limit. Grades will finish later.")
                return
            }
            if Date.now > giveUp { break }
            let seen = service.revision
            for _ in 0..<60 where service.revision == seen && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
            }
            report = service.revision == seen ? await service.drainNow() : (service.lastReport ?? ClaudeJobQueue.Report())
        }
        grading = .unavailable("Grading is taking long. It will finish when Claude is available.")
    }

    /// The shared queue finished a job while this result is on screen (after `start`'s own wait
    /// ended): show the new grades.
    func gradingProgressed() {
        guard let store, grading != .running else { return }
        reload()
        if pendingCount == 0, (try? store.openJobCount(attemptId: attemptId)) ?? 0 == 0, grading != .none { grading = .done }
    }

    private func recordPlacement(gamification: GamificationEngine?) {
        guard kind == .placement, let gamification, let band = overall else { return }
        _ = try? gamification.mergeStageEvidence { e in
            e.placementDone = true
            e.placementBand = band
        }
    }

    /// XP/streak credit and, for the placement, Tena's stage evidence. Once per attempt.
    func credit(store: ExamStore, gamification: GamificationEngine?) {
        guard let gamification, let overall, let integrity, !((try? store.isCredited(attemptId: attemptId)) ?? true) else { return }
        let counts = (try? store.creditCounts(attemptId: attemptId)) ?? (correct: 0, productions: 0)
        let examIntegrity = ExamIntegrity(rawValue: integrity.rawValue.lowercased()) ?? .unverifiable
        let sections = skills.filter { ExamSkill.sections.contains($0.skill) }.compactMap(\.band)
        let credit = ExamCredit(attemptId: attemptId, kind: ExamCreditKind(kind), band: overall, sectionBands: sections,
                                integrity: integrityConfirmed && integrity == .warning ? .warning : examIntegrity,
                                correctItems: counts.correct, productions: counts.productions)
        do {
            let effects = try gamification.handle(.examFinished(credit))
            xpGained = effects.xp
            if kind == .placement {
                let band = overall
                let stage = try gamification.mergeStageEvidence { e in
                    e.placementDone = true
                    e.placementBand = band
                }
                stageAdvanced = stage.stageAdvanced
            }
        } catch {
            loadProblem = "Couldn't save XP: \(error.localizedDescription)"
        }
    }
}
