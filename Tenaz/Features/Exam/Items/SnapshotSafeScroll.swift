import SwiftUI

/// A vertical ScrollView in the app; plain clipped content in snapshots (ImageRenderer cannot
/// draw the AppKit scroll view behind ScrollView on macOS).
/// With `hug`, the view takes only the height its content needs when that fits.
struct SnapshotSafeScroll<Content: View>: View {
    var hug = false
    @ViewBuilder var content: Content
    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        if hug {
            ViewThatFits(in: .vertical) {
                content
                scrolling
            }
        } else {
            scrolling
        }
    }

    @ViewBuilder private var scrolling: some View {
        if isSnapshot {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
        } else {
            ScrollView { content }
        }
    }
}
