import Foundation

/// Fixed review screens for snapshots, built from real bundled entries.
extension ReviewViewState {
    static let sampleProgress = ReviewProgress(answered: 6, correct: 5, remaining: 8, xp: 64, combo: 4, correctToday: 5)

    static let clozeCard = ReviewCardModel(
        id: "workplace-meetings-follow-up:C", type: .cloze, text: "I will ____ with the vendor about the missing invoice tomorrow.",
        hint: "dar seguimiento, retomar", expected: "follow up", headword: "follow up",
        exampleEn: "I will follow up with the vendor about the missing invoice tomorrow.",
        exampleEs: "Le daré seguimiento al proveedor sobre la factura faltante mañana.", gloss: "dar seguimiento, retomar"
    )

    static let recognitionCard = ReviewCardModel(
        id: "false-friends-eventually:R", type: .recognition, text: "eventually", hint: "The build failed twice, but it eventually passed.",
        options: ["eventualmente, a veces", "al final, con el tiempo", "en realidad, de hecho", "suponer, dar por hecho"], correctOption: 1,
        expected: nil, headword: "eventually", exampleEn: "The build failed twice, but it eventually passed.",
        exampleEs: "La compilación falló dos veces, pero al final pasó.", gloss: "al final, con el tiempo"
    )

    static let recallCard = ReviewCardModel(
        id: "b2-academic-assume:L", type: .recall, text: "suponer, dar por hecho", hint: "to think that something is true without having proof",
        expected: "assume", headword: "assume", exampleEn: "Don't assume that the client has read the report.",
        exampleEs: "No des por hecho que el cliente ha leído el informe.", gloss: "suponer, dar por hecho"
    )

    static let question = ReviewViewState(phase: .question(clozeCard), progress: sampleProgress)

    static let correct = ReviewViewState(
        phase: .feedback(recognitionCard, ReviewFeedback(correct: true, chosenOption: 1, xp: 12, backIn: 600, combo: 5)),
        progress: ReviewProgress(answered: 7, correct: 6, remaining: 7, xp: 76, combo: 5, correctToday: 6)
    )

    static let wrong = ReviewViewState(
        phase: .feedback(recallCard, ReviewFeedback(correct: false, typed: "asume", xp: 0, backIn: 60, combo: 0)),
        progress: ReviewProgress(answered: 8, correct: 6, remaining: 7, xp: 76, combo: 0, correctToday: 6)
    )

    static let waiting = ReviewViewState(phase: .waiting(until: SnapshotFixtures.morning.addingTimeInterval(42)),
                                         progress: ReviewProgress(answered: 10, correct: 8, remaining: 2, xp: 98, combo: 2, correctToday: 8))

    static let checkpoint = ReviewViewState(phase: .checkpoint,
                                            progress: ReviewProgress(answered: 11, correct: 10, remaining: 6, xp: 120, combo: 3, correctToday: 10),
                                            mood: .proud)

    static let done = ReviewViewState(phase: .done(ReviewSummary(
        answered: 14, correct: 12, xp: 156, bestCombo: 8, correctToday: 12, productionsToday: 0, dayQualified: false,
        leveledUp: true, level: 4, mood: .ecstatic, stage: .juvenile, comingBack: 2
    )))
}
