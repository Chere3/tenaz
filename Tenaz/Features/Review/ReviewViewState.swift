/// Everything the review screen draws.
struct ReviewViewState: Equatable {
    var phase: ReviewPhase
    var progress = ReviewProgress()
    var mood: TenaMood = .focused
    var stage: TenaStage = .juvenile
}
