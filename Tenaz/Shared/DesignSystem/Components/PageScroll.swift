import SwiftUI

/// A vertical page scroller. ImageRenderer draws a ScrollView blank, so snapshots get the plain content.
struct PageScroll<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        if isSnapshot {
            content
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxHeight: .infinity, alignment: .top)
        } else {
            ScrollView { content }
        }
    }
}
