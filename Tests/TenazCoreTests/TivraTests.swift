import Foundation
import GRDB
import Testing
@testable import TenazCore

struct TivraTests {
    @Test func readerIsReadOnly() async throws {
        let url = try TivraFixture.makeDatabase()
        let reader = TivraReader(databaseURL: url)
        await #expect(throws: (any Error).self) {
            try await reader.withConnection { db in try db.execute(sql: "DELETE FROM activity_spans") }
        }
        await #expect(throws: (any Error).self) {
            try await reader.withConnection { db in try db.execute(sql: "CREATE TABLE x(a)") }
        }
        let remaining = try await reader.withConnection { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM activity_spans") }
        #expect((remaining ?? 0) > 0)
    }

    @Test func readerDoesNotCreateAMissingFile() async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nope-\(UUID().uuidString)/tivra.db")
        let evidence = await TivraReader(databaseURL: url).evidence(window: TivraFixture.window(0))
        #expect(evidence == .unavailable(reason: "tivra_db_missing"))
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func readerRefusesTheDevDatabase() async {
        let url = URL(fileURLWithPath: "/tmp/Tivra-Dev/tivra.db")
        let evidence = await TivraReader(databaseURL: url).evidence(window: TivraFixture.window(0))
        #expect(evidence == .unavailable(reason: "forbidden_database"))
    }

    @Test func readerRefusesALinkIntoTheDevDatabase() async throws {
        let real = try TivraFixture.makeDatabase()
        let dev = FileManager.default.temporaryDirectory.appendingPathComponent("Tivra-Dev-\(UUID().uuidString)/Tivra-Dev", isDirectory: true)
        try FileManager.default.createDirectory(at: dev, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: real, to: dev.appendingPathComponent("tivra.db"))
        let link = FileManager.default.temporaryDirectory.appendingPathComponent("link-\(UUID().uuidString)")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: dev)
        for url in [dev.appendingPathComponent("tivra.db"), link.appendingPathComponent("tivra.db")] {
            let evidence = await TivraReader(databaseURL: url).evidence(window: TivraFixture.window(0))
            #expect(evidence == .unavailable(reason: "forbidden_database"))
        }
    }

    @Test func verdictClean() async throws {
        let v = try await TivraFixture.verdict(0)
        #expect(v.verdict == .clean)
        #expect(v.tivraAvailable)
        #expect(v.violations.isEmpty && v.warnings.isEmpty)
        #expect((v.captureGapMaxSec ?? 999) <= 60)
    }

    @Test func verdictViolationFromClaudeAI() async throws {
        let v = try await TivraFixture.verdict(1)
        #expect(v.verdict == .violation)
        #expect(v.violations.count == 1)
        #expect(v.violations[0].kind == .domain)
        #expect(v.violations[0].label == "Claude")
        #expect(v.violations[0].seconds == 42)
        #expect(v.warnings.isEmpty, "the raw focus event is explained by the span")
        #expect(v.timeline.map(\.severity) == [.violation])
    }

    @Test func verdictWarningFromFlashAndPhone() async throws {
        let v = try await TivraFixture.verdict(2)
        #expect(v.verdict == .warning)
        #expect(v.violations.isEmpty)
        #expect(Set(v.warnings.map(\.kind)) == [.flash, .phoneActive])
        #expect(v.warnings.first { $0.kind == .phoneActive }?.seconds == 300)
    }

    @Test func verdictUnverifiableOnCaptureGap() async throws {
        let v = try await TivraFixture.verdict(3)
        #expect(v.verdict == .unverifiable)
        #expect(v.problems.contains("capture_gap"))
        #expect((v.captureGapMaxSec ?? 0) > 150)
    }

    @Test func verdictUnverifiableOnPausedSpan() async throws {
        let v = try await TivraFixture.verdict(4)
        #expect(v.verdict == .unverifiable)
        #expect(v.problems == ["paused_or_excluded"])
    }

    @Test func verdictUnverifiableWhenASourceIsDegraded() async throws {
        let v = try await TivraFixture.verdict(0) { db in
            try db.execute(sql: "UPDATE source_health SET state = 'no_permission' WHERE source = 'browser_url.dia'")
        }
        #expect(v.verdict == .unverifiable)
        #expect(v.problems == ["source_browser_url.dia_no_permission"])
    }

    @Test func deniedPhonePackageIsAViolation() async throws {
        let v = try await TivraFixture.verdict(5)
        #expect(v.verdict == .violation)
        #expect(v.violations.first?.kind == .package)
        #expect(v.violations.first?.label == "Claude")
    }

    @Test func missingTableIsUnverifiable() async throws {
        let url = try TivraFixture.makeDatabase(sql: "CREATE TABLE tivra_events(id INTEGER PRIMARY KEY);")
        let window = TivraFixture.window(0)
        let evidence = await TivraReader(databaseURL: url).evidence(window: window)
        guard case .unavailable(let reason) = evidence else { Issue.record("expected unavailable"); return }
        #expect(reason.hasPrefix("schema_mismatch:"))
        let v = IntegrityVerifier(denyList: try TivraFixture.denyList())
            .verdict(examId: "x", window: window, verifiedTs: 0, tivra: evidence, tenazEvents: [])
        #expect(v.verdict == .unverifiable)
        #expect(!v.tivraAvailable)
    }

    @Test func missingColumnIsUnverifiable() async throws {
        let url = try TivraFixture.makeDatabase { db in
            try db.execute(sql: "ALTER TABLE source_health DROP COLUMN state")
        }
        let evidence = await TivraReader(databaseURL: url).evidence(window: TivraFixture.window(0))
        #expect(evidence == .unavailable(reason: "schema_mismatch:source_health.state"))
    }

    @Test func unverifiableOutranksATenazSideViolation() async throws {
        let events = [IntegrityEvent(attemptId: "a", ts: TivraFixture.window(3).startTs + 1000, kind: .app, detail: "ChatGPT", durationMs: 9000)]
        let v = try await TivraFixture.verdict(3, events: events)
        #expect(v.verdict == .unverifiable)
        #expect(v.violations.count == 1, "the finding is still listed")
    }

    @Test func tenazSideRulesApplyOnAHealthyWitness() async throws {
        let t = TivraFixture.window(0).startTs
        func flags(_ n: Int) -> [IntegrityEvent] { (0..<n).map { IntegrityEvent(attemptId: "a", ts: t + Int64($0) * 1000, kind: .paste) } }
        #expect(try await TivraFixture.verdict(0, events: flags(3)).verdict == .warning)
        #expect(try await TivraFixture.verdict(0, events: flags(4)).verdict == .violation)
        let brief = IntegrityEvent(attemptId: "a", ts: t, kind: .app, detail: "Claude", durationMs: 3000)
        #expect(try await TivraFixture.verdict(0, events: [brief]).verdict == .warning)
        let long = IntegrityEvent(attemptId: "a", ts: t, kind: .app, detail: "Claude", durationMs: 3001)
        #expect(try await TivraFixture.verdict(0, events: [long]).verdict == .violation)
        let focus = IntegrityEvent(attemptId: "a", ts: t, kind: .focusLoss)
        let v = try await TivraFixture.verdict(0, events: [focus])
        #expect(v.verdict == .clean)
        #expect(v.timeline.map(\.severity) == [.info])
    }

    @Test func spanOverlapIsClippedToTheWindow() {
        let w = TivraWindow(startTs: 1000, endTs: 2000)
        let list = DenyList(domains: [.init(host: "claude.ai", label: "Claude", tier: .ai)])
        let evidence = TivraEvidence.available(TivraReading(
            health: TivraHealth(captureTickCount: 10, maxGapSeconds: 60, sourceStates: [:], pausedOrExcludedSeconds: 0, problems: []),
            foreground: ForegroundEvidence(spans: [ForegroundSpan(startTs: 0, endTs: 3000, domain: "claude.ai")])))
        let v = IntegrityVerifier(denyList: list).verdict(examId: "x", window: w, verifiedTs: 0, tivra: evidence, tenazEvents: [])
        #expect(v.verdict == .warning, "1 s inside the window is a flash, not a violation")
        #expect(v.warnings.first?.seconds == 1)
    }

    @Test func learningMinutesAndFocusBlocks() async throws {
        let url = try TivraFixture.makeDatabase()
        let reader = TivraReader(databaseURL: url)
        // Fixture base is 03:50 UTC, so the learning day (04:00 start) holding the scenarios contains base + 2 h.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let date = Date(timeIntervalSince1970: Double(TivraFixture.base + 2 * TivraFixture.hour) / 1000)
        let day = DayBoundary.day(for: date, calendar: utc)
        let minutes = try await reader.learningMinutes(day: day, calendar: utc)
        #expect(minutes.tenaz > 45)
        #expect(minutes.all > minutes.tenaz, "Duolingo adds to the total")

        let ends = try await reader.focusBlockEnded(since: TivraFixture.base)
        #expect(ends.map(\.id) == ["S1"])
        #expect(ends.first?.finalState == "completed")
    }

    @Test func integrityEventRoundTrips() throws {
        let db = try TenazDatabase.inMemory()
        try db.writer.write { _ = try IntegrityEvent(attemptId: "a1", ts: 5, kind: .paste, detail: "x").inserted($0) }
        let all = try db.reader.read { try IntegrityEvent.fetchAll($0) }
        #expect(all.count == 1 && all[0].kind == .paste && all[0].id != nil)
    }
}
