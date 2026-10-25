import Foundation
import GRDB
import Testing
@testable import TenazCore

struct SmokeTests {
    @Test func pathsUseBundleSpecificFolder() {
        #expect(Paths.forApp(bundleIdentifier: "com.chere3.tenaz.dev").root.lastPathComponent == "TenazDev")
        #expect(Paths.forApp(bundleIdentifier: "com.chere3.tenaz").root.lastPathComponent == "Tenaz")
    }

    @Test func clockSleepsWithTestClock() async throws {
        let clock = TestClock()
        let start = clock.now
        try await clock.sleep(for: .seconds(90))
        #expect(clock.now.timeIntervalSince(start) == 90)
    }

    @Test func dayBoundaryIsFourAM() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Mexico_City")!
        let f = ISO8601DateFormatter()
        #expect(DayBoundary.day(for: f.date(from: "2026-10-23T09:30:00Z")!, calendar: cal) == 20261022) // 03:30 local
        #expect(DayBoundary.day(for: f.date(from: "2026-10-23T10:30:00Z")!, calendar: cal) == 20261023) // 04:30 local
    }

    @Test func databaseMigrates() throws {
        let db = try TenazDatabase.inMemory()
        let tables = try db.reader.read { try String.fetchAll($0, sql: "SELECT name FROM sqlite_master WHERE type='table'") }
        #expect(tables.contains("intrusion_log"))
    }
}
