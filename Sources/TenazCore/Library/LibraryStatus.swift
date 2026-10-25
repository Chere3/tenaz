/// Where the learner is with a catalog item. Abandoning is data, never a penalty (research 08 §6.4).
public enum LibraryStatus: String, Codable, CaseIterable, Sendable {
    case inProgress, finished, abandoned
}
