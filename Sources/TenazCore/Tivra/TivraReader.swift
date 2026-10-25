import Foundation
import GRDB

/// Read-only view of Tivra's SQLite file (PLAN 4.7, research 06 section 1.1). Every call opens the file
/// read-only with `query_only`, reads, and closes it again: Tenaz never holds the file and never writes.
/// A missing file, table or column surfaces as an error / `.unavailable`, which the verifier turns into UNVERIFIABLE.
public actor TivraReader {
    public static var defaultDatabaseURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tivra", isDirectory: true).appendingPathComponent("tivra.db")
    }

    /// The subset of Tivra's schema this reader depends on.
    static let expectedSchema: [String: [String]] = [
        "tivra_events": ["type", "ts", "payload", "device_id"],
        "activity_spans": ["device_id", "start_ts", "end_ts", "kind", "bundle_id", "url", "domain", "category"],
        "source_health": ["source", "device_id", "state"],
        "sessions": ["id", "actual_end_ts", "final_state"],
    ]
    static let macDevice = "mac-local"

    public let databaseURL: URL

    public init(databaseURL: URL = TivraReader.defaultDatabaseURL) {
        self.databaseURL = databaseURL
    }

    // MARK: Public API

    public func health(window: TivraWindow) throws -> TivraHealth {
        try withConnection { try Self.health($0, window) }
    }

    public func foregroundEvidence(window: TivraWindow) throws -> ForegroundEvidence {
        try withConnection { try Self.foreground($0, window) }
    }

    public func otherDeviceUsage(window: TivraWindow) throws -> [DeviceUsageSpan] {
        try withConnection { try Self.otherDevices($0, window) }
    }

    /// `day` is a learning day (`yyyymmdd`, starting 04:00 local, see `DayBoundary`).
    public func learningMinutes(day: Int, calendar: Calendar = .current) throws -> LearningMinutes {
        var parts = DateComponents()
        parts.year = day / 10000
        parts.month = day / 100 % 100
        parts.day = day % 100
        parts.hour = DayBoundary.hour
        guard let start = calendar.date(from: parts), let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return LearningMinutes(tenaz: 0, all: 0)
        }
        let window = TivraWindow(start: start, end: end)
        return try withConnection { db in
            let row = try Row.fetchOne(
                db,
                sql: """
                    SELECT COALESCE(SUM(ov), 0) / 60000.0 AS allMin,
                           COALESCE(SUM(CASE WHEN bundle_id LIKE 'com.chere3.tenaz%' THEN ov END), 0) / 60000.0 AS tenazMin
                    FROM (SELECT bundle_id, MIN(end_ts, :e) - MAX(start_ts, :s) AS ov FROM activity_spans
                          WHERE category = 'aprendizaje' AND kind = 'active' AND end_ts > :s AND start_ts < :e)
                    """,
                arguments: ["s": window.startTs, "e": window.endTs])
            let all: Double = row?["allMin"] ?? 0
            let tenaz: Double = row?["tenazMin"] ?? 0
            return LearningMinutes(tenaz: tenaz, all: all)
        }
    }

    /// Tivra focus blocks that ended after `since` (ms), oldest first.
    public func focusBlockEnded(since: Int64) throws -> [FocusBlockEnd] {
        try withConnection { db in
            try Row.fetchAll(db, sql: "SELECT id, actual_end_ts, final_state FROM sessions WHERE actual_end_ts > ? ORDER BY actual_end_ts", arguments: [since])
                .map { FocusBlockEnd(id: $0["id"], endTs: $0["actual_end_ts"], finalState: $0["final_state"]) }
        }
    }

    /// Health, foreground and phone evidence in one read. Never throws: failure is `.unavailable`.
    public func evidence(window: TivraWindow) -> TivraEvidence {
        do {
            return try withConnection { db in
                .available(TivraReading(
                    health: try Self.health(db, window),
                    foreground: try Self.foreground(db, window),
                    devices: try Self.otherDevices(db, window)))
            }
        } catch let error as TivraReadError {
            return .unavailable(reason: Self.reason(error))
        } catch {
            return .unavailable(reason: "unreadable")
        }
    }

    // MARK: Connection

    /// Opens, checks the schema, runs `body`, closes. Internal so tests can prove writes are refused.
    func withConnection<T>(_ body: (Database) throws -> T) throws -> T {
        let path = databaseURL.path
        // Check the symlink-resolved path too, so a link into a dev folder cannot sneak past.
        let components = Set(databaseURL.standardizedFileURL.pathComponents + databaseURL.resolvingSymlinksInPath().pathComponents)
        if !components.isDisjoint(with: ["Tivra-Dev", "TivraSmokeF1d"]) { throw TivraReadError.forbiddenDatabase }
        guard FileManager.default.fileExists(atPath: path) else { throw TivraReadError.missingFile }

        var config = Configuration()
        config.readonly = true
        config.busyMode = .timeout(2)
        config.prepareDatabase { db in try db.execute(sql: "PRAGMA query_only = 1") }
        let queue = try DatabaseQueue(path: path, configuration: config)
        defer { try? queue.close() }
        return try queue.read { db in
            try Self.checkSchema(db)
            return try body(db)
        }
    }

    private static func checkSchema(_ db: Database) throws {
        for (table, columns) in expectedSchema {
            guard try db.tableExists(table) else { throw TivraReadError.schemaMismatch(table) }
            let present = Set(try db.columns(in: table).map(\.name))
            for column in columns where !present.contains(column) {
                throw TivraReadError.schemaMismatch("\(table).\(column)")
            }
        }
    }

    private static func reason(_ error: TivraReadError) -> String {
        switch error {
        case .missingFile: "tivra_db_missing"
        case .forbiddenDatabase: "forbidden_database"
        case .schemaMismatch(let what): "schema_mismatch:\(what)"
        }
    }

    // MARK: Queries (06 section 4.2)

    private static func health(_ db: Database, _ window: TivraWindow) throws -> TivraHealth {
        let ticks = try Int64.fetchAll(
            db,
            sql: "SELECT ts FROM tivra_events WHERE type = 'capture_tick' AND device_id = ? AND ts BETWEEN ? AND ? ORDER BY ts",
            arguments: [macDevice, window.startTs - 120_000, window.endTs + 120_000])
        var states: [String: String] = [:]
        for row in try Row.fetchAll(db, sql: "SELECT source, state FROM source_health WHERE device_id = ?", arguments: [macDevice]) {
            states[row["source"]] = row["state"]
        }
        let paused = try Row.fetchAll(
            db,
            sql: "SELECT start_ts, end_ts FROM activity_spans WHERE device_id = ? AND kind IN ('paused', 'excluded') AND end_ts > ? AND start_ts < ?",
            arguments: [macDevice, window.startTs, window.endTs]
        ).reduce(Int64(0)) { $0 + window.overlapMs(start: $1["start_ts"], end: $1["end_ts"]) }
        return TivraHealth.evaluate(tickTimestamps: ticks, sourceStates: states, pausedOrExcludedMs: paused, window: window)
    }

    private static func foreground(_ db: Database, _ window: TivraWindow) throws -> ForegroundEvidence {
        let spans = try Row.fetchAll(
            db,
            sql: """
                SELECT start_ts, end_ts, bundle_id, domain, url FROM activity_spans
                WHERE device_id = ? AND end_ts > ? AND start_ts < ? AND kind IN ('active', 'passive') ORDER BY start_ts
                """,
            arguments: [macDevice, window.startTs, window.endTs]
        ).map { ForegroundSpan(startTs: $0["start_ts"], endTs: $0["end_ts"], bundleId: $0["bundle_id"], domain: $0["domain"], url: $0["url"]) }

        let events = try Row.fetchAll(
            db,
            sql: """
                SELECT ts, CAST(payload AS BLOB) AS payload FROM tivra_events
                WHERE device_id = ? AND ts BETWEEN ? AND ? AND type IN ('app_active', 'window_focus', 'tab_active') ORDER BY ts
                """,
            arguments: [macDevice, window.startTs, window.endTs]
        ).map { row -> FocusEvent in
            let json = payload(row["payload"])
            return FocusEvent(
                ts: row["ts"], bundleId: (json["bundleId"] ?? json["bundleIdentifier"]) as? String,
                domain: json["domain"] as? String, url: json["url"] as? String)
        }
        return ForegroundEvidence(spans: spans, events: events)
    }

    private static func otherDevices(_ db: Database, _ window: TivraWindow) throws -> [DeviceUsageSpan] {
        // `ts` is the usage start; look an hour back so a long use that began before the window is seen.
        try Row.fetchAll(
            db,
            sql: """
                SELECT CAST(payload AS BLOB) AS payload FROM tivra_events
                WHERE device_id <> ? AND type = 'device_usage' AND ts BETWEEN ? AND ?
                """,
            arguments: [macDevice, window.startTs - 3_600_000, window.endTs]
        ).compactMap { row -> DeviceUsageSpan? in
            let json = payload(row["payload"])
            guard json["kind"] as? String == "app",
                  let start = (json["startTs"] as? NSNumber)?.int64Value,
                  let end = (json["endTs"] as? NSNumber)?.int64Value,
                  window.overlapMs(start: start, end: end) > 0
            else { return nil }
            return DeviceUsageSpan(startTs: start, endTs: end, packageName: json["packageName"] as? String)
        }
    }

    private static func payload(_ data: Data?) -> [String: Any] {
        guard let data, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return object
    }
}
