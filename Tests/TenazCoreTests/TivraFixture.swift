import Foundation
import GRDB
@testable import TenazCore

/// Builds a throwaway Tivra database from `Fixtures/tivra_fixture.sql`. Scenario `i` covers
/// `[base + i h, base + i h + 10 min]`: 0 clean, 1 claude.ai 42 s, 2 chatgpt flash + phone, 3 capture gap,
/// 4 paused span, 5 deny-listed phone package.
enum TivraFixture {
    static let base: Int64 = 1_792_727_400_000
    static let hour: Int64 = 3_600_000
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    static func window(_ scenario: Int) -> TivraWindow {
        let start = base + Int64(scenario) * hour
        return TivraWindow(startTs: start, endTs: start + 600_000)
    }

    static func denyList() throws -> DenyList {
        try DenyList.load(from: root.appendingPathComponent("Content/denylist.json"))
    }

    /// `sql` replaces the fixture script, so tests can also build broken databases.
    static func makeDatabase(sql: String? = nil, then mutate: ((Database) throws -> Void)? = nil) throws -> URL {
        let script = try sql ?? String(contentsOf: root.appendingPathComponent("Tests/TenazCoreTests/Fixtures/tivra_fixture.sql"), encoding: .utf8)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tivra-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("tivra.db")
        let queue = try DatabaseQueue(path: url.path)
        try queue.write { db in
            try db.execute(sql: script)
            try mutate?(db)
        }
        try queue.close()
        return url
    }

    static func verdict(_ scenario: Int, mutate: ((Database) throws -> Void)? = nil, events: [IntegrityEvent] = []) async throws -> IntegrityVerdict {
        let url = try makeDatabase(then: mutate)
        let window = window(scenario)
        let evidence = await TivraReader(databaseURL: url).evidence(window: window)
        let verifier = IntegrityVerifier(denyList: try denyList())
        return verifier.verdict(examId: "e\(scenario)", window: window, verifiedTs: window.endTs + 90_000, tivra: evidence, tenazEvents: events)
    }
}
