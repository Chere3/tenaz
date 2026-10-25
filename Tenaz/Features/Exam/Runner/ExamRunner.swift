import Foundation
import Observation
import TenazCore

/// Drives one exam attempt for the UI: section intros, one task per screen, the section timer,
/// answers written to the database as soon as they are given, pause/resume, abort and submit.
/// Shared by the placement, Daily Check and mocks; Exam Mode wraps it in a panel.
@Observable
final class ExamRunner {
    enum Phase: Equatable {
        /// Before a section starts: the timer is stopped.
        case intro
        case task
        /// A meeting started: timer stopped, panel closed.
        case meetingPause
        case finished
        case voided
    }

    private(set) var session: ExamSession
    private(set) var phase: Phase = .intro
    var draft = ExamDraft()
    private(set) var outcome: ExamOutcome?
    /// Refreshed every second so the timer redraws.
    private(set) var now = Date.now
    /// The attempt was rebuilt from the database (crash, quit or a pause between sections).
    let resumed: Bool
    /// Tasks shown as text because speech could not play, or answered by typing instead of speaking.
    private(set) var notes: [String: String] = [:]
    /// Set when saving failed; the exam keeps going and says so.
    private(set) var saveProblem: String?
    /// Listening audio is playing.
    private(set) var isPlaying = false
    /// Tenaz itself holds the microphone (speaking task), so the meeting watcher ignores mic use.
    var usingMicrophone = false
    /// Tivra witness status shown in the footer (set by the host).
    var witness: ExamWitness = .checking

    @ObservationIgnored let store: ExamStore
    @ObservationIgnored let clock: any TenazClock
    @ObservationIgnored let examMode: Bool
    @ObservationIgnored var onEvent: (ExamRunnerEvent) -> Void = { _ in }
    @ObservationIgnored private var typing = TypingMonitor()
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var replayClock: ReplayClock?
    @ObservationIgnored var speaker: any ExamSpeaking = LaunchArguments.current.isAutomation ? SilentSpeaker() : NeuralSpeaker()

    init(session: ExamSession, store: ExamStore, clock: any TenazClock, examMode: Bool, resumed: Bool = false,
         replayClock: ReplayClock? = nil, notes: [String: String] = [:]) {
        self.session = session
        self.store = store
        self.clock = clock
        self.examMode = examMode
        self.resumed = resumed
        self.replayClock = replayClock
        self.notes = notes
        if case .running = session.status { self.session.pause(.user) }
        if let task = session.currentTask {
            draft = .fresh(for: task)
            // Text typed before a crash, quit or pause comes back (saved every few seconds).
            if let stored = notes[Self.draftNoteKey].flatMap(StoredDraft.decode), stored.taskId == task.id {
                stored.apply(to: &draft)
            }
        }
        if session.isComplete { phase = .finished }
    }

    // MARK: Factories

    /// Begins a new attempt: stored skill states as priors; bank items shown anywhere (gate, Write,
    /// exams) in the last 180 days are avoided, with their whole group, and vocabulary probes answered
    /// in the last 14 days. `ExamSession` lets them back in when the bank runs short.
    static func begin(_ blueprint: ExamBlueprint, library: ContentLibrary, store: ExamStore, examMode: Bool,
                      seed: UInt64 = UInt64.random(in: 1...UInt64(Int64.max)), clock: any TenazClock = SystemClock()) throws -> ExamRunner {
        let history = try ExposureStore(database: store.database).all()
        let picker = ExposurePicker(surface: .exam, library: library.items, history: history, now: clock.now)
        var excluded = picker.excludedIds(library.items)
        excluded.formUnion(try store.recentItemIds(since: clock.now.addingTimeInterval(-14 * 86_400)).filter { $0.hasPrefix("vocab:") })
        let session = ExamSession(blueprint: blueprint, library: library, priors: try store.priors(for: blueprint.kind),
                                  excluding: excluded, seed: seed, clock: clock)
        try store.begin(session)
        let runner = ExamRunner(session: session, store: store, clock: clock, examMode: examMode)
        runner.persistProgress(pausedBetweenSections: false)
        return runner
    }

    /// Rebuilds an unfinished attempt and leaves it at the intro of the section it stopped in.
    static func resume(_ attemptId: String, catalog: BlueprintCatalog, library: ContentLibrary, store: ExamStore) throws -> ExamRunner {
        let (session, clock) = try store.restore(attemptId, catalog: catalog, library: library)
        clock.goLive()
        let notes = try store.progress(attemptId)?.noteMap ?? [:]
        return ExamRunner(session: session, store: store, clock: clock, examMode: session.blueprint.kind != .daily, resumed: true,
                          replayClock: clock, notes: notes)
    }

    // MARK: Reading

    var blueprint: ExamBlueprint { session.blueprint }
    var task: ExamTask? { session.currentTask }
    var kind: ExamTaskKind? { task.map(ExamTaskKind.init) }
    var section: SectionSpec? { session.currentSection }

    /// Sections as the learner sees them: routed modules share their group's chip.
    var displaySections: [ExamSectionChip] {
        var chips: [ExamSectionChip] = []
        let current = session.sectionIndex
        for (i, spec) in blueprint.sections.enumerated() {
            if spec.isOptional && !session.includeOptional { continue }
            let key = spec.group ?? spec.id
            let isCurrent = current.map { blueprint.sections[$0].group ?? blueprint.sections[$0].id } == key
            let isDone = current.map { i < $0 && !isCurrent } ?? true
            if let at = chips.firstIndex(where: { $0.id == key }) {
                if isCurrent { chips[at].state = .active }
                continue
            }
            chips.append(ExamSectionChip(id: key, title: spec.title, minutes: spec.minutes,
                                         state: isCurrent ? .active : isDone ? .done : .idle))
        }
        return chips
    }

    var sectionNumber: Int { (displaySections.firstIndex { $0.state == .active } ?? 0) + 1 }

    var remaining: Duration {
        _ = now
        return session.sectionRemaining
    }

    var remainingFraction: Double {
        guard let spec = section else { return 0 }
        let total = Double(spec.timeLimit.components.seconds)
        return total > 0 ? Double(remaining.components.seconds) / total : 0
    }

    /// The last two minutes: the timer turns orange and says so once, calmly.
    var isLastTwoMinutes: Bool { phase == .task && remaining <= .seconds(120) }

    var positionText: String {
        guard section != nil else { return "" }
        let upTo = section?.adaptive != nil ? "up to " : ""
        return "\(session.sectionPosition + 1) of \(upTo)\(session.sectionLength)"
    }

    var isTranscriptShown: Bool { task.map { notes[$0.id] == ExamNote.readInstead } ?? false }

    // MARK: Section flow

    /// Starts (or continues) the section on screen: the timer runs from here.
    func startSection() {
        guard phase == .intro || phase == .meetingPause, session.currentTask != nil else { return }
        session.resume()
        phase = .task
        markPresented()
        onEvent(.sectionStarted(section?.timeLimit ?? .zero))
        startTicking()
    }

    /// "Pause here, finish later": only between sections, saved so the Exams screen can resume it.
    func pauseBetweenSections() {
        guard phase == .intro else { return }
        persistProgress(pausedBetweenSections: true)
        stopTicking()
        onEvent(.pausedForLater)
    }

    /// A meeting signal: the timer stops at once, nothing is flagged, the panel closes.
    func pauseForMeeting() {
        guard phase == .task || phase == .intro else { return }
        stopAudio()
        saveDraft(force: true)
        if case .running = session.status { session.pause(.meeting) }
        phase = .meetingPause
        stopTicking()
        persistProgress(pausedBetweenSections: false)
    }

    /// The watchdog fired: stop and keep everything for a resume.
    func suspendForWatchdog() {
        stopAudio()
        saveDraft(force: true)
        if case .running = session.status { session.pause(.user) }
        if phase == .task { phase = .intro }
        stopTicking()
        persistProgress(pausedBetweenSections: true)
    }

    // MARK: Answering

    /// Return / Next: moves to the next question of a multi-question item, or hands the item in.
    func next() {
        guard phase == .task, let task else { return }
        let questions = questionCount(task)
        if questions > 1, draft.questionIndex < questions - 1 {
            // An interview question is spoken per question; a conversation keeps playing across its questions.
            if kind == .interview { stopAudio() }
            draft.questionIndex += 1
            if kind == .interview { draft.plays = 0 }
            return
        }
        commit(task, answer: draft.answer(for: task))
    }

    /// Back to the previous question inside the same item (never to a previous item).
    func previousQuestion() {
        guard draft.questionIndex > 0 else { return }
        draft.questionIndex -= 1
    }

    func choose(_ option: Int) {
        guard phase == .task, let task, kind?.hasOptions == true else { return }
        let count = optionCount(task)
        guard option >= 0, option < count, draft.choices.indices.contains(draft.questionIndex) else { return }
        draft.choices[draft.questionIndex] = option
    }

    func questionCount(_ task: ExamTask) -> Int {
        guard let item = task.item else { return 1 }
        switch item.type {
        case .readDaily, .readAcademic, .listenConversation, .listenAnnouncement, .listenTalk: return item.questions?.count ?? 1
        case .interview: return item.interviewQuestions?.count ?? 1
        default: return 1
        }
    }

    func optionCount(_ task: ExamTask) -> Int {
        switch task.content {
        case let .vocab(_, options, _): return options.count
        case let .item(item):
            if let qs = item.questions, qs.indices.contains(draft.questionIndex) { return qs[draft.questionIndex].options.count }
            return item.options?.count ?? 0
        }
    }

    /// Hands the current item in (Next on the last question, or time running out).
    private func commit(_ task: ExamTask, answer: ExamAnswer?) {
        let before = session.sectionIndex
        guard session.answer(answer) else { return }
        save { try store.recordResponse(session, taskId: task.id) }
        afterAdvance(from: before)
    }

    private func afterAdvance(from sectionBefore: Int?) {
        // The old item's audio never talks over the next item (and never keeps its Play disabled).
        stopAudio()
        if let task = session.currentTask { draft = .fresh(for: task) }
        if session.isComplete {
            finish()
        } else if session.sectionIndex != sectionBefore {
            session.pause(.user)
            phase = .intro
            stopTicking()
            persistProgress(pausedBetweenSections: false)
            onEvent(.sectionEnded)
        } else {
            persistProgress(pausedBetweenSections: false)
            if phase == .task { markPresented() }
        }
    }

    /// Bank items logged when they reach the screen (dataset plan §6), once per runner; vocabulary
    /// probes are left to FSRS.
    @ObservationIgnored private var presented: Set<String> = []

    private func markPresented() {
        guard let item = task?.item, presented.insert(item.id).inserted else { return }
        save { try ExposureStore(database: store.database).record(item, surface: .exam, at: clock.now) }
    }

    /// Called every second while a section runs. Time up: whatever is in the draft is handed in,
    /// then the section ends (unanswered tasks count as wrong, as in TOEFL).
    func tick() {
        now = clock.now
        saveDraft(force: false)
        guard phase == .task, session.sectionRemaining <= .zero else { return }
        let before = session.sectionIndex
        if let task, !draft.isEmpty {
            commit(task, answer: draft.answer(for: task))
            if session.sectionIndex != before || phase != .task { return }
        }
        if session.tick() { afterAdvance(from: before) }
    }

    /// Ends the attempt and scores it; writing and speaking go to the Claude queue.
    func finish() {
        stopTicking()
        stopAudio()
        guard let result = session.submit() else { return }
        outcome = result
        save { try store.save(session, outcome: result) }
        save { try store.saveProgress(session, pausedBetweenSections: false, at: clock.now) }
        phase = .finished
        onEvent(.finished(session.id))
    }

    /// Hold-Esc abort or the kill switch: the attempt is void and never counts.
    func abort(reason: String) {
        guard phase != .finished, phase != .voided else { return }
        stopTicking()
        stopAudio()
        session.abort()
        save { try store.void(session) }
        phase = .voided
        onEvent(.voided(reason))
    }

    // MARK: Audio

    /// Plays the current task's audio (at most twice). If speech can't play, the text is shown
    /// instead and the item is marked "read instead".
    func play() {
        guard phase == .task, let task, !isPlaying, draft.plays < Self.maxPlays else { return }
        let lines = ExamScript.lines(for: task, question: draft.questionIndex)
        guard !lines.isEmpty else { return }
        draft.plays += 1
        isPlaying = true
        playGeneration += 1
        let generation = playGeneration
        let taskId = task.id
        Task {
            let ok = await speaker.speak(lines)
            // A stop (next item, pause) already reset the state; a newer play owns it now.
            guard generation == playGeneration else { return }
            isPlaying = false
            if !ok, session.currentTask?.id == taskId, notes[taskId] == nil { note(ExamNote.readInstead, for: taskId) }
        }
    }

    static let maxPlays = 2
    @ObservationIgnored private var playGeneration = 0

    var playsLeft: Int { max(0, Self.maxPlays - draft.plays) }

    // MARK: Notes and telemetry

    func note(_ text: String, for taskId: String) {
        notes[taskId] = text
        save { try store.saveProgress(session, pausedBetweenSections: false, note: (taskId, text), at: clock.now) }
    }

    /// Every edit of an exam answer field (never the text itself, only counts).
    func recordTyping(inserted: Int, deleted: Int, isIME: Bool) {
        let t = ProcessInfo.processInfo.systemUptime
        guard let flag = typing.record(at: t, inserted: inserted, deleted: deleted, isIME: isIME) else { return }
        switch flag {
        case let .largeInsertion(characters): logIntegrity(.paste, detail: "\(characters) characters at once")
        case let .fastTyping(wpm): logIntegrity(.burst, detail: "\(wpm) wpm")
        }
    }

    /// A blocked paste or drop in an answer field.
    func pasteBlocked() { logIntegrity(.paste, detail: "paste blocked") }

    func logIntegrity(_ kind: IntegrityEventKind, detail: String? = nil, durationMs: Int64? = nil) {
        save { try store.logIntegrity(attemptId: session.id, kind: kind, detail: detail, durationMs: durationMs, at: clock.now) }
    }

    // MARK: Draft autosave

    /// The `exam_progress.notes` key holding the typed text of the task on screen.
    static let draftNoteKey = "draft"
    @ObservationIgnored private var savedDraft: String?
    @ObservationIgnored private var lastDraftSave = Date.distantPast

    /// Writing, interview and gap text survive a crash, Cmd-Q or Tivra closing Tenaz: saved at most
    /// every 3 seconds while it changes (only counts and text, as the answer itself would be).
    func saveDraft(force: Bool) {
        guard phase == .task || force, let task else { return }
        guard force || clock.now.timeIntervalSince(lastDraftSave) >= 3 else { return }
        let stored = StoredDraft(taskId: task.id, text: draft.text, texts: draft.texts, gaps: draft.gaps)
        guard stored.hasText, let json = stored.encoded, json != savedDraft else { return }
        lastDraftSave = clock.now
        savedDraft = json
        save { try store.saveProgress(session, pausedBetweenSections: phase != .task,
                                      note: (Self.draftNoteKey, json), at: clock.now) }
    }

    // MARK: Plumbing

    private func persistProgress(pausedBetweenSections: Bool) {
        save { try store.saveProgress(session, pausedBetweenSections: pausedBetweenSections, at: clock.now) }
    }

    private func save(_ body: () throws -> Void) {
        do { try body() } catch { saveProblem = "Couldn't save: \(error.localizedDescription)" }
    }

    /// Drives the timer from the system clock; tests and the self-test call `tick()` themselves.
    @ObservationIgnored var autoTick = true

    private func startTicking() {
        guard autoTick, ticker == nil else { return }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.tick()
            }
        }
    }

    func stopAudio() {
        guard isPlaying else { return }
        playGeneration += 1
        speaker.stop()
        isPlaying = false
    }

    private func stopTicking() {
        ticker?.cancel()
        ticker = nil
        now = clock.now
    }
}
