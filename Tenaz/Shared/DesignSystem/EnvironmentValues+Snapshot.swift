import SwiftUI

extension EnvironmentValues {
    /// True while `--tenaz-snapshot` renders off-screen with ImageRenderer, which cannot draw AppKit
    /// views; components that wrap one show a SwiftUI stand-in instead.
    @Entry var isSnapshot = false
}
