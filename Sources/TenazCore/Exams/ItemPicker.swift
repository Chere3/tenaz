/// Draws tasks for a section from the bank, deterministically from the session's RNG.
public enum ItemPicker {
    /// Every task a pick could produce, in a stable shuffled order. Used whole by adaptive sections.
    public static func candidates(_ pick: ItemPick, section: SectionSpec, library: ContentLibrary,
                                  excluding: Set<String>, rng: inout SeededRandom) -> [ExamTask] {
        var tasks: [ExamTask]
        if let ids = pick.ids {
            tasks = ids.compactMap { id in library.items.first { $0.id == id } }.map { task(for: $0, section: section) }
        } else if let types = pick.types {
            let items = library.items.filter { types.contains($0.type) }.sorted { $0.id < $1.id }
            tasks = items.map { task(for: $0, section: section) }
        } else if pick.vocab == true {
            let entries = library.vocab.sorted { $0.id < $1.id }
            tasks = entries.map { ExamTask.vocab($0, sectionId: section.id, skill: section.skill ?? .grammar, rng: &rng) }
        } else {
            tasks = []
        }
        tasks.removeAll { excluding.contains($0.id) }
        tasks.shuffle(using: &rng)
        return tasks
    }

    /// `pick.count` tasks, preferring the pick's levels and filling from the nearest levels.
    public static func pick(_ pick: ItemPick, section: SectionSpec, library: ContentLibrary,
                            excluding: Set<String>, rng: inout SeededRandom) -> [ExamTask] {
        let pool = candidates(pick, section: section, library: library, excluding: excluding, rng: &rng)
        let wanted = Set((pick.levels ?? []).compactMap { CEFRLevel(label: $0) })
        guard !wanted.isEmpty else { return Array(pool.prefix(pick.count)) }
        func distance(_ task: ExamTask) -> Int {
            wanted.map { abs($0.rawValue - task.level.rawValue) }.min() ?? 0
        }
        // Stable sort keeps the shuffled order within each distance.
        let ranked = pool.enumerated().sorted { (distance($0.element), $0.offset) < (distance($1.element), $1.offset) }
        return Array(ranked.prefix(pick.count).map(\.element))
    }

    static func task(for item: ExamItem, section: SectionSpec) -> ExamTask {
        ExamTask(content: .item(item), sectionId: section.id, skill: section.skill ?? ExamSkill.natural(for: item))
    }

    /// Adaptive choice: the unused task whose difficulty is nearest `theta`, ties broken by pool order.
    public static func nearest(to theta: Double, in pool: [ExamTask], excluding used: Set<String>) -> ExamTask? {
        pool.enumerated()
            .filter { !used.contains($0.element.id) }
            .min { (abs($0.element.difficulty - theta), $0.offset) < (abs($1.element.difficulty - theta), $1.offset) }?
            .element
    }
}
