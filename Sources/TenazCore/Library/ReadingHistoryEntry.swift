/// One catalog item the learner started, in the order they touched them (oldest first).
public struct ReadingHistoryEntry: Equatable, Sendable {
    public var itemId: String
    public var status: LibraryStatus

    public init(itemId: String, status: LibraryStatus) {
        self.itemId = itemId
        self.status = status
    }
}
