import Foundation

/// What one `ContentImporter.importVocab` run added.
public struct ImportReport: Equatable, Sendable {
    public var notesAdded = 0
    public var cardsAdded = 0

    public init(notesAdded: Int = 0, cardsAdded: Int = 0) {
        self.notesAdded = notesAdded
        self.cardsAdded = cardsAdded
    }
}
