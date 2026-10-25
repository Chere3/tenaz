import Foundation

/// Where Tenaz keeps its files. The folder follows the app variant, so the Debug build
/// (`TenazDev`) never touches the Release build's data.
public struct Paths: Sendable {
    public var root: URL

    public init(root: URL) { self.root = root }

    /// `~/Library/Application Support/<Tenaz|TenazDev>`.
    public static func forApp(bundleIdentifier: String?) -> Paths {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = (bundleIdentifier ?? "").hasSuffix(".dev") ? "TenazDev" : "Tenaz"
        return Paths(root: base.appendingPathComponent(folder, isDirectory: true))
    }

    public var database: URL { root.appendingPathComponent("tenaz.sqlite") }
    public var disableOverlaysFlag: URL { root.appendingPathComponent("DISABLE_OVERLAYS") }
    public var claudeWorkDirectory: URL { root.appendingPathComponent("claude-cwd", isDirectory: true) }
    public var audioCache: URL { root.appendingPathComponent("audio-cache", isDirectory: true) }
    public var backups: URL { root.appendingPathComponent("backups", isDirectory: true) }

    public func ensureExists() throws {
        for dir in [root, claudeWorkDirectory, audioCache, backups] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}
