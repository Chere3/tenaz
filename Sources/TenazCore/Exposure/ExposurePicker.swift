import Foundation

/// Chooses what to show so the learner does not keep seeing the same thing (dataset plan §6). Pure: the
/// exposure history, the clock and the RNG come in; nothing is read or written here.
///
/// - Writing prompts (gate, Write): an item whose id or group was ever shown is skipped until 90 % of
///   the pool has been used; then the least recently shown come back first. Never the same kind as the
///   last 2 writing prompts on any surface, unless nothing else is eligible.
/// - Exam items: an item whose id or group was shown in the last 180 days is excluded.
public struct ExposurePicker: Sendable {
    public static let examCooldown: TimeInterval = 180 * 86_400
    /// Share of a writing pool that must be used before any prompt comes back.
    public static let writingReuseShare = 0.9
    /// How many recent writing kinds a new writing prompt must differ from.
    public static let kindMemory = 2

    public let surface: ExposureSurface
    public let now: Date
    /// Kinds of the most recent writing prompts on any surface, newest first.
    public let recentKinds: [WritingKind]
    private let lastById: [String: Int64]
    private let lastByGroup: [String: Int64]

    /// - Parameters:
    ///   - library: every bundled item, to find the group and kind of history rows that lack them
    ///     (the backfill) or of items shown on another surface.
    ///   - history: exposure rows in any order.
    public init(surface: ExposureSurface, library: [ExamItem], history: [ExposureRecord], now: Date) {
        self.surface = surface
        self.now = now
        var groupOf: [String: String] = [:]
        var kindOf: [String: WritingKind] = [:]
        for item in library {
            if let group = item.group { groupOf[item.id] = group }
            if let kind = item.writingKind { kindOf[item.id] = kind }
        }
        var byId: [String: Int64] = [:]
        var byGroup: [String: Int64] = [:]
        for row in history {
            byId[row.itemId] = max(byId[row.itemId] ?? .min, row.ts)
            if let group = row.groupId ?? groupOf[row.itemId] { byGroup[group] = max(byGroup[group] ?? .min, row.ts) }
        }
        lastById = byId
        lastByGroup = byGroup
        let newestFirst = history.enumerated().sorted { ($0.element.ts, $0.offset) > ($1.element.ts, $1.offset) }.map(\.element)
        recentKinds = Array(newestFirst.lazy
            .compactMap { row in row.kind.flatMap(WritingKind.init(rawValue:)) ?? kindOf[row.itemId] }
            .filter { $0 != .interview }
            .prefix(Self.kindMemory))
    }

    /// When the item, or any item of its group, was last shown (Unix ms); nil = never.
    public func lastShown(_ item: ExamItem) -> Int64? {
        let byGroup = item.group.flatMap { lastByGroup[$0] }
        switch (lastById[item.id], byGroup) {
        case let (a?, b?): return max(a, b)
        case let (a, b): return a ?? b
        }
    }

    /// Ids of the items shown (by id or group) within `cooldown` of now, for `ExamSession(excluding:)`.
    public func excludedIds(_ items: [ExamItem], cooldown: TimeInterval = examCooldown) -> Set<String> {
        let cutoff = now.addingTimeInterval(-cooldown).unixMilliseconds
        return Set(items.filter { (lastShown($0) ?? .min) >= cutoff }.map(\.id))
    }

    /// One item from `candidates`, or nil when there are none.
    public func pick(_ candidates: [ExamItem], rng: inout SeededRandom) -> ExamItem? {
        guard !candidates.isEmpty else { return nil }
        var eligible: [ExamItem]
        switch surface {
        case .exam, .review:
            let cutoff = now.addingTimeInterval(-Self.examCooldown).unixMilliseconds
            eligible = candidates.filter { (lastShown($0) ?? .min) < cutoff }
            if eligible.isEmpty { eligible = leastRecentlyShown(candidates) }
            return eligible[Int.random(in: 0 ..< eligible.count, using: &rng)]
        case .gate, .write:
            let unseen = candidates.filter { lastShown($0) == nil }
            let usedShare = Double(candidates.count - unseen.count) / Double(candidates.count)
            eligible = !unseen.isEmpty && usedShare < Self.writingReuseShare ? unseen : leastRecentlyShown(candidates)
            let rotated = eligible.filter { item in item.writingKind.map { !recentKinds.contains($0) } ?? true }
            if !rotated.isEmpty { eligible = rotated }
        }
        // Kind first, then the item, so a pool of 80 personal prompts and 10 advice ones still varies.
        var kinds: [WritingKind?] = []
        for item in eligible where !kinds.contains(item.writingKind) { kinds.append(item.writingKind) }
        let kind = kinds[Int.random(in: 0 ..< kinds.count, using: &rng)]
        let ofKind = eligible.filter { $0.writingKind == kind }
        return ofKind[Int.random(in: 0 ..< ofKind.count, using: &rng)]
    }

    /// The soft fallback: the oldest-shown tenth of the pool (never-shown items first), at least one.
    func leastRecentlyShown(_ items: [ExamItem]) -> [ExamItem] {
        let ranked = items.enumerated().sorted { a, b in
            (lastShown(a.element) ?? .min, a.offset) < (lastShown(b.element) ?? .min, b.offset)
        }
        return ranked.prefix(max(1, items.count / 10)).map(\.element)
    }
}
