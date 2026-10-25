/// One section in the exam header strip.
struct ExamSectionChip: Identifiable, Equatable {
    let id: String
    let title: String
    let minutes: Double
    var state: ChipState
}
