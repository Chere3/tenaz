import Foundation

public enum ClaudeCLIError: Error, Equatable, CustomStringConvertible {
    case notInstalled
    case timedOut
    case usageLimit(String)
    case failed(String)
    case noStructuredOutput

    public var description: String {
        switch self {
        case .notInstalled: "Claude Code isn't installed at ~/.local/bin/claude."
        case .timedOut: "Claude took too long."
        case let .usageLimit(m): "Claude usage limit: \(m)"
        case let .failed(m): "Claude failed: \(m)"
        case .noStructuredOutput: "Claude didn't return a structured answer."
        }
    }
}

/// Runs one-shot `claude -p` calls through the learner's claude.ai session (never an API key).
/// Calls are slim: no tools, no MCP servers, no skills, no user settings, no saved session,
/// which keeps a grading call around 1k tokens of context and 2-5 seconds.
public struct ClaudeCLI: Sendable {
    public var executable: URL
    public var model: String
    public var workDirectory: URL

    public init(
        executable: URL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".local/bin/claude"),
        model: String = "sonnet",
        workDirectory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("tenaz-claude")
    ) {
        self.executable = executable
        self.model = model
        self.workDirectory = workDirectory
    }

    public var isAvailable: Bool { FileManager.default.isExecutableFile(atPath: executable.path) }

    /// The arguments for one call. Exposed for tests.
    public func arguments(prompt: String, system: String, schema: String) -> [String] {
        [
            "-p", prompt,
            "--output-format", "json",
            "--json-schema", schema,
            "--tools", "",
            "--no-session-persistence",
            "--model", model,
            "--strict-mcp-config",
            "--disable-slash-commands",
            "--setting-sources", "",
            "--system-prompt", system,
        ]
    }

    public static func environment(from base: [String: String]) -> [String: String] {
        var env = base
        for key in ["ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX"] {
            env.removeValue(forKey: key)
        }
        // A grading call must not join or inherit a parent Claude Code session (when Tenaz is
        // started from a terminal running Claude Code): drop its session, socket and model variables.
        for key in env.keys where key == "CLAUDECODE" || key == "CLAUDE_PID" || key == "CLAUDE_EFFORT" || key.hasPrefix("CLAUDE_CODE_") {
            env.removeValue(forKey: key)
        }
        env["PATH"] = "\(NSHomeDirectory())/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        env["NO_COLOR"] = "1"
        return env
    }

    /// Runs the call and decodes `structured_output` into `T`.
    public func structured<T: Decodable & Sendable>(
        _ type: T.Type, prompt: String, system: String, schema: String, timeout: Duration = .seconds(120)
    ) async throws -> T {
        let data = try await run(prompt: prompt, system: system, schema: schema, timeout: timeout)
        return try Self.decodeStructured(type, from: data)
    }

    public static func decodeStructured<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let text = String(data: data, encoding: .utf8) ?? ""
            if text.localizedCaseInsensitiveContains("limit") { throw ClaudeCLIError.usageLimit(String(text.prefix(200))) }
            throw ClaudeCLIError.failed(String(text.prefix(300)))
        }
        if (obj["is_error"] as? Bool) == true {
            let msg = (obj["result"] as? String) ?? "unknown error"
            if msg.localizedCaseInsensitiveContains("limit") { throw ClaudeCLIError.usageLimit(msg) }
            throw ClaudeCLIError.failed(msg)
        }
        guard let structured = obj["structured_output"] else { throw ClaudeCLIError.noStructuredOutput }
        let raw = try JSONSerialization.data(withJSONObject: structured)
        return try JSONDecoder().decode(T.self, from: raw)
    }

    private func run(prompt: String, system: String, schema: String, timeout: Duration) async throws -> Data {
        guard isAvailable else { throw ClaudeCLIError.notInstalled }
        try? FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments(prompt: prompt, system: system, schema: schema)
        process.environment = Self.environment(from: ProcessInfo.processInfo.environment)
        process.currentDirectoryURL = workDirectory
        process.standardInput = FileHandle.nullDevice
        let out = Pipe()
        process.standardOutput = out
        process.standardError = FileHandle.nullDevice

        let box = OutputBox()
        out.fileHandleForReading.readabilityHandler = { handle in box.append(handle.availableData) }

        return try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
                    process.terminationHandler = { _ in
                        out.fileHandleForReading.readabilityHandler = nil
                        box.append(out.fileHandleForReading.readDataToEndOfFile())
                        cont.resume(returning: box.data)
                    }
                    do { try process.run() } catch { cont.resume(throwing: ClaudeCLIError.failed("\(error)")) }
                }
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw ClaudeCLIError.timedOut
            }
            defer { if process.isRunning { process.terminate() } }
            let first = try await group.next()!
            group.cancelAll()
            return first
        }
    }
}

/// Collects pipe output from a background handler.
final class OutputBox: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    func append(_ d: Data) { lock.lock(); buffer.append(d); lock.unlock() }
    var data: Data { lock.lock(); defer { lock.unlock() }; return buffer }
}
