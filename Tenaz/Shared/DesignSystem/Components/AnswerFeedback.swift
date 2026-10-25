/// What the answer field shows after Return. Never red while typing.
enum AnswerFeedback: Equatable {
    case none
    case correct
    case wrong(expected: String)
}
