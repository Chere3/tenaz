import Foundation
import GRDB

/// The single SQLite database (`tenaz.sqlite`). Each feature area registers its own
/// append-only migrations in `Migrations.swift`; never edit a shipped migration.
public final class TenazDatabase: Sendable {
    public let writer: any DatabaseWriter

    public init(writer: any DatabaseWriter) throws {
        self.writer = writer
        try Migrations.migrator().migrate(writer)
    }

    /// WAL pool on disk for the app.
    public static func onDisk(_ paths: Paths) throws -> TenazDatabase {
        try paths.ensureExists()
        var config = Configuration()
        config.foreignKeysEnabled = true
        return try TenazDatabase(writer: DatabasePool(path: paths.database.path, configuration: config))
    }

    /// Empty in-memory database for tests.
    public static func inMemory() throws -> TenazDatabase {
        var config = Configuration()
        config.foreignKeysEnabled = true
        return try TenazDatabase(writer: DatabaseQueue(configuration: config))
    }

    public var reader: any DatabaseReader { writer }
}
