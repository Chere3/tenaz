/// The "Test connection" button's result.
enum ClaudeTestState: Equatable {
    case idle, running, ok(String), failed(String)
}
