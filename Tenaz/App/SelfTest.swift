import Foundation
import TenazCore

/// `--tenaz-selftest <name>`: scripted checks that print JSON-ish results. Features add cases.
enum SelfTest {
    static func run(_ name: String, environment env: AppEnvironment) async -> Int32 {
        switch name {
        case "content":
            print("vocab \(env.content.vocab.count) items \(env.content.items.count) problems \(env.contentProblems.count)")
            return env.content.vocab.isEmpty ? 1 : 0
        case "tivra":
            return await tivra()
        case "review":
            return review(content: env.content)
        case "write":
            return write(environment: env)
        case "review-ui":
            return reviewUI(environment: env)
        case "home-state":
            return homeState(environment: env)
        case "design":
            return design()
        case "gamification":
            return gamification()
        case "placement-sim":
            return await placementSimulation(environment: env)
        case "intrusions":
            return intrusions(environment: env)
        case "claude":
            return await claudeGrade(environment: env)
        case "placement-flow":
            return await placementFlow(environment: env)
        case "progress":
            return progress(environment: env)
        case "first-run":
            return await firstRun(environment: env)
        case "exam-live":
            return await examLive(environment: env)
        case "exam-window":
            return await examWindow(environment: env)
        case "placement-window":
            return placementWindow()
        case "audio":
            return audio(environment: env)
        case "mascot":
            return mascot()
        case "mascot-dump":
            return mascot(dump: true)
        default:
            print("unknown selftest \(name)")
            return 2
        }
    }

    /// Answers 10 seeded cards through the session API on an in-memory database (misses come back after
    /// their learning step) and prints the `review_log` count.
    private static func review(content: ContentLibrary) -> Int32 {
        do {
            let db = try TenazDatabase.inMemory()
            var now = Date()
            let report = try ContentImporter.importVocab(content.vocab, into: db, now: now)
            let store = ReviewStore(database: db)
            var session = try store.startSession(book: PromptBook(vocab: content.vocab), surface: .session, now: now)
            var answered = 0
            while answered < 10 {
                if session.next(now: now) == nil, let back = session.nextReturn { now = back }
                guard let item = session.next(now: now) else { break }
                let miss = answered % 3 == 0
                let answer: ReviewAnswer = switch item.prompt.type {
                case .recognition: .choice(miss ? ((item.prompt.correctOption ?? 0) + 1) % 4 : item.prompt.correctOption ?? 0)
                case .production: .graded(miss ? .again : .good)
                default: .typed(miss ? "zzz" : item.prompt.expected ?? "")
                }
                let mode: InputMode = item.prompt.type == .recognition ? .choice : .typed
                let outcome = try session.submit(answer, durationMs: 3000, inputMode: mode, at: now)
                try store.record(outcome)
                print("\(item.card.id) \(outcome.rating) -> \(outcome.after.state.rawValue)")
                answered += 1
                now += 2
            }
            let logs = try db.reader.read { try ReviewLogRecord.fetchCount($0) }
            print("notes \(report.notesAdded) cards \(report.cardsAdded) review_log \(logs)")
            return logs == 10 ? 0 : 1
        } catch {
            print("review selftest failed: \(error)")
            return 1
        }
    }

    /// Runs the gamification engine on a throwaway in-memory database with the bundled stages and
    /// achievements: one minimum viable day, then prints level, Tena and quests. Touches no real data.
    private static func gamification() -> Int32 {
        do {
            let root = Bundle.main.resourceURL!.appendingPathComponent("Content")
            let engine = try GamificationEngine.bundled(database: .inMemory(), contentRoot: root)
            try engine.mergeStageEvidence { e in
                e.onboardingDone = true
                e.levelParagraphDone = true
                e.privateBand = StageEvidence.englishLevelPriorBand
            }
            for i in 0..<10 { try engine.handle(.reviewAnswered(AnsweredReview(cardId: "selftest-\(i)", correct: true))) }
            try engine.handle(.productionDone(Production(refId: "selftest", quality: 0.6, words: 20)))
            let s = try engine.state()
            let unlocked = s.achievements.filter(\.isUnlocked).map(\.id)
            print("level \(s.level.level) xp \(s.level.totalXP) scales \(s.scales) stage \(s.mascot.stage) \(s.stageName) "
                + "vitality \(s.mascot.vitality) spirit \(s.mascot.spirit) mood \(s.mood.rawValue) qualified \(s.today.qualified) "
                + "streak \(s.streak.current) quests \(s.quests.map { "\($0.slot.rawValue) \($0.progress)/\($0.target)" }) "
                + "achievements \(s.achievements.count) unlocked \(unlocked) rulesOn \(PenaltyRuleKind.allCases.filter { s.contract.isActive($0, at: Int64(Date().timeIntervalSince1970 * 1000)) })")
            return s.today.qualified && s.mascot.stage == 3 && s.achievements.count == 53 ? 0 : 1
        } catch {
            print("gamification selftest failed: \(error)")
            return 1
        }
    }

    /// Reads the live Tivra database read-only (last 2 hours) and prints the health JSON, then proves with
    /// `lsof` that this process holds no handle on the file.
    private static func tivra() async -> Int32 {
        let reader = TivraReader()
        let window = TivraWindow(start: Date().addingTimeInterval(-7200), end: Date())
        do {
            let health = try await reader.health(window: window)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
            print(String(decoding: try encoder.encode(health), as: UTF8.self))
        } catch {
            print("unavailable (\(error))")
        }
        print("handles on tivra.db held by this process: \(openHandles(on: TivraReader.defaultDatabaseURL))")
        return 0
    }

    private static func openHandles(on url: URL) -> Int {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(filePath: "/usr/sbin/lsof")
        process.arguments = ["-nP", "-p", String(ProcessInfo.processInfo.processIdentifier)]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return -1 }
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        return output.split(separator: "\n").filter { $0.contains(url.path) }.count
    }
}
