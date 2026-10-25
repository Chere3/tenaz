/// Quest slots (PLAN F9): three daily ones plus the weekly "meeting prep".
public enum QuestSlot: String, Codable, CaseIterable, Sendable {
    /// Clear your due set; cannot be faked (needs FSRS data).
    case core
    /// Rotates by the weakest error-ledger category.
    case skill
    /// Optional and risky; promises a mystery drop.
    case stretch
    case weekly
}
