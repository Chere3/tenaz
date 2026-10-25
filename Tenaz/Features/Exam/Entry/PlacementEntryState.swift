import Foundation
import TenazCore

/// What the placement intro needs: the plan, an unfinished attempt to continue, the last result.
struct PlacementEntryState {
    struct Section: Identifiable {
        var id: String
        var title: String
        var minutes: Int
        var skill: ExamSkill?
    }

    var sections: [Section]
    var totalMinutes: Int
    /// An unfinished placement: its id and "section 3 of 7".
    var unfinished: (id: String, where: String)?
    /// The last finished placement.
    var last: ExamAttemptSummary?

    static func load(blueprint: ExamBlueprint?, store: ExamStore?) -> PlacementEntryState {
        let sections = (blueprint?.sections ?? []).map {
            Section(id: $0.id, title: $0.title, minutes: Int($0.minutes), skill: $0.skill)
        }
        var state = PlacementEntryState(sections: sections, totalMinutes: sections.map(\.minutes).reduce(0, +))
        guard let store else { return state }
        if let attempt = try? store.unfinishedAttempts(kind: .placement).first {
            let index = (try? store.progress(attempt.id))?.sectionIndex ?? 0
            state.unfinished = (attempt.id, "section \(min(index + 1, max(sections.count, 1))) of \(sections.count)")
        }
        state.last = try? store.history().first { $0.kind == .placement && $0.status == "done" }
        return state
    }
}
