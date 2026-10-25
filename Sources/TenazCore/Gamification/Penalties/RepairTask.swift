/// The regeneration task (PLAN F10): 15 reviews without hints, then a 60-word paragraph.
/// Every 5 reviews regrows one limb (3 limbs), the paragraph regrows the fourth.
public enum RepairTask {
    public static let reviewsRequired = 15
    public static let reviewsPerLimb = 5
    public static let paragraphWords = 60
    public static let limbs = 4
    /// Budgeted against the 5-minute daily penalty-task cap.
    public static let estimatedMinutes = 5

    public static func limbsRegrown(reviews: Int, paragraphDone: Bool) -> Int {
        min(reviews, reviewsRequired) / reviewsPerLimb + (paragraphDone ? 1 : 0)
    }

    public static func isComplete(reviews: Int, paragraphDone: Bool) -> Bool {
        reviews >= reviewsRequired && paragraphDone
    }
}
