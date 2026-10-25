/// What Today's buttons do. The live `HomeView` wires them to the navigator; snapshots leave them empty.
struct HomeActions {
    var primary: () -> Void = {}
    var dailyCheck: () -> Void = {}
    var write: () -> Void = {}
    var quests: () -> Void = {}
    var level: () -> Void = {}
    /// Tena is still an egg (onboarding closed early): open onboarding again.
    var hatch: () -> Void = {}
}
