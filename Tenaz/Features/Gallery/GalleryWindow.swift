import SwiftUI

/// The debug "Gallery" window (dev builds): design sheets and the mascot gallery in tabs.
struct GalleryWindow: View {
    var body: some View {
        TabView {
            Tab("Design", systemImage: "paintpalette") {
                ScrollView([.vertical, .horizontal]) { DesignGallery() }
            }
            Tab("Tena", systemImage: "face.smiling") {
                ScrollView([.vertical, .horizontal]) { MascotGallery() }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}
