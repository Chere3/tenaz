import AppKit
import SwiftUI

/// Renders registered screens to PNG with ImageRenderer. Features add their screens in SnapshotRegistry.
enum Snapshot {
    static func render(_ name: String, to path: String, environment: AppEnvironment) -> Int32 {
        guard let entry = SnapshotRegistry.screens(environment)[name] else {
            FileHandle.standardError.write(Data("unknown snapshot \(name); known: \(SnapshotRegistry.screens(environment).keys.sorted())\n".utf8))
            return 2
        }
        // `--dark` renders the Night Press theme (dynamic colors resolve against the dark appearance).
        let dark = CommandLine.arguments.contains("--dark")
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
        NSApp.appearance = appearance
        let content = entry.view
            .frame(width: entry.size.width, height: entry.size.height)
            .environment(\.isSnapshot, true)
            .environment(\.mascotStill, true)
            .environment(\.colorScheme, dark ? .dark : .light)
        var png: Data?
        appearance.performAsCurrentDrawingAppearance {
            let renderer = ImageRenderer(content: content)
            renderer.scale = 2
            if let image = renderer.nsImage, let tiff = image.tiffRepresentation {
                png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
            }
        }
        guard let png else { return 3 }
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        do { try png.write(to: url) } catch { return 4 }
        print("snapshot \(name) -> \(path)")
        return 0
    }
}

struct SnapshotEntry {
    var view: AnyView
    var size: CGSize
}
