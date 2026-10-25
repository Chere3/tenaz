import Foundation

/// Builds today's set from all cards (pure, so the rules are unit-tested without a database).
public enum ReviewQueue {
    /// Due cards first (learning steps, then by due time), one card per note, nothing buried or
    /// suspended. New cards: at most `newPerDay` note introductions minus those already made today,
    /// plus unlocked siblings at most 1 per `reviewsPerNew` due cards; none while more than
    /// `suspendNewAboveDue` are due. New cards are interleaved 1 per `reviewsPerNew` reviews (spares go
    /// last), the whole set fits the daily cap, then it is reordered so no type or topic runs longer
    /// than `maxSameInARow` when another card can go there. `picked` are notes the learner chose with
    /// "Learn this next" (`deck_pick`): they are introduced before any other new note, within the budget.
    public static func build(
        cards: [CardRecord], notes: [String: NoteRecord], today: DailyCounts, day: Int, now: Date,
        limits: QueueLimits = .standard, picked: Set<String> = []
    ) -> [CardRecord] {
        let nowMs = now.unixMilliseconds
        let byNote = Dictionary(grouping: cards, by: \.noteId)
        let live = cards.filter { c in
            guard let note = notes[c.noteId], !note.suspended else { return false }
            return (c.buriedUntilDay ?? 0) < day
        }
        let due = live.filter { $0.state != .new && $0.due <= nowMs }.sorted { a, b in
            let ra = a.state == .review ? 1 : 0, rb = b.state == .review ? 1 : 0
            return ra != rb ? ra < rb : (a.due, a.id) < (b.due, b.id)
        }
        let fresh: [(card: CardRecord, availability: CardAvailability)] = live
            .filter { $0.state == .new }
            .map { c in (c, CardUnlock.availability(of: c, kind: notes[c.noteId]!.kind, noteCards: byNote[c.noteId] ?? [])) }
            .filter { $0.availability != .locked }
            .sorted { newPriority($0.card, notes, picked).lexicographicallyPrecedes(newPriority($1.card, notes, picked)) }

        var usedNotes = Set<String>()
        var pickedDue: [CardRecord] = []
        for c in due where usedNotes.insert(c.noteId).inserted { pickedDue.append(c) }

        let room = max(0, limits.dailyCap - today.answered)
        pickedDue = Array(pickedDue.prefix(room))
        let newAllowed = due.count <= limits.suspendNewAboveDue
        var noteBudget = newAllowed ? max(0, limits.newPerDay - today.newIntroduced) : 0
        var siblingBudget = newAllowed ? pickedDue.count / max(1, limits.reviewsPerNew) : 0
        var newRoom = room - pickedDue.count
        var pickedNew: [CardRecord] = []
        for (c, availability) in fresh where newRoom > 0 && !usedNotes.contains(c.noteId) {
            switch availability {
            case .introducesNote where noteBudget > 0: noteBudget -= 1
            case .sibling where siblingBudget > 0: siblingBudget -= 1
            default: continue
            }
            usedNotes.insert(c.noteId)
            pickedNew.append(c)
            newRoom -= 1
        }

        var merged: [CardRecord] = []
        var newIter = pickedNew.makeIterator()
        for (i, c) in pickedDue.enumerated() {
            merged.append(c)
            if (i + 1) % max(1, limits.reviewsPerNew) == 0, let n = newIter.next() { merged.append(n) }
        }
        while let n = newIter.next() { merged.append(n) }
        return spread(merged, notes: notes, maxRun: limits.maxSameInARow)
    }

    /// Greedy reorder: take the earliest card that does not make a run of `maxRun + 1` of one type
    /// and one topic; else one that at least breaks the type run; else the earliest.
    static func spread(_ cards: [CardRecord], notes: [String: NoteRecord], maxRun: Int) -> [CardRecord] {
        var rest = cards
        var out: [CardRecord] = []
        func topic(_ c: CardRecord) -> String { notes[c.noteId]?.topic ?? "" }
        func runs(_ c: CardRecord, _ key: (CardRecord) -> String) -> Bool {
            out.count >= maxRun && out.suffix(maxRun).allSatisfy { key($0) == key(c) }
        }
        while !rest.isEmpty {
            let i = rest.firstIndex { !runs($0, { $0.type.rawValue }) && !runs($0, topic) }
                ?? rest.firstIndex { !runs($0, { $0.type.rawValue }) }
                ?? 0
            out.append(rest.remove(at: i))
        }
        return out
    }

    /// Picked notes first, then error patterns, then must-know notes, then easier CEFR, then a stable order.
    private static func newPriority(_ c: CardRecord, _ notes: [String: NoteRecord], _ picked: Set<String>) -> [String] {
        let note = notes[c.noteId]
        let pick = picked.contains(c.noteId) ? "0" : "1"
        let kind = note?.kind == .pattern ? "0" : "1"
        let must = note?.mustKnow == true ? "0" : "1"
        let level = String(CEFRLevel(label: note?.cefr ?? "")?.rawValue ?? 9)
        let typeOrder = String(CardType.allCases.firstIndex(of: c.type) ?? 9)
        return [pick, kind, must, level, c.noteId, typeOrder]
    }
}
