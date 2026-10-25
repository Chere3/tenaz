import Foundation
import TenazCore

/// The bundled catalog and Brain bites, read once. An unreadable file degrades to an empty
/// Library (logged), never a crash.
enum LibraryBundle {
    static let content: LibraryContent = {
        let root = Bundle.main.resourceURL!.appendingPathComponent("Content")
        do { return try LibraryContent.load(from: root) } catch {
            NSLog("Tenaz: library content failed to load: \(error)")
            return LibraryContent(catalog: [], knowledge: [])
        }
    }()
}
