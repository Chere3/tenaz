import TenazCore

/// What the reading log sheet hands back.
struct ReadingLogEntry: Equatable {
    var minutes: Int
    var pages: Int?
    /// Yes answers to the 3-question self-check.
    var understood: Int
    /// nil = still reading.
    var newStatus: LibraryStatus?
    var abandonReason: String?
}
