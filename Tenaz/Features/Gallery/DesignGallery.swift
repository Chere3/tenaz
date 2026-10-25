import SwiftUI
import TenazCore

/// Debug catalogue: both sheets side by side. The identity lives in details code review cannot judge.
struct DesignGallery: View {
    var body: some View {
        HStack(spacing: 0) {
            GallerySheet(palette: .paper)
                .environment(\.colorScheme, .light)
            GallerySheet(palette: .nightPress)
                .environment(\.colorScheme, .dark)
        }
    }
}
