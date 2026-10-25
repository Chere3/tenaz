import SwiftUI

extension EnvironmentValues {
    /// When true, Tena draws her resting pose and never ticks (snapshots, the exam corner).
    @Entry var mascotStill = false
    /// The flood Tena stands on, set by `.flood(_:)`: on coral and orange her gills step down to gill deep.
    @Entry var mascotFlood: Flood?
}
