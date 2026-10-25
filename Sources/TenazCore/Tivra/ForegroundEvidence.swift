import Foundation

public struct ForegroundEvidence: Hashable, Sendable {
    public var spans: [ForegroundSpan]
    public var events: [FocusEvent]

    public init(spans: [ForegroundSpan] = [], events: [FocusEvent] = []) {
        self.spans = spans
        self.events = events
    }
}
