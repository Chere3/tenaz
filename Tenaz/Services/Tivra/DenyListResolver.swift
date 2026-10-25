import AppKit
import TenazCore

/// Resolves deny-list bundle ids at runtime (research 06 gap: ids like the ChatGPT app's are not guessable).
/// Looks up each entry's `appName` among installed apps and adds the bundle id it really has.
enum DenyListResolver {
    static func resolve(_ list: DenyList) -> DenyList {
        let folders = [URL(filePath: "/Applications"), URL(filePath: "/System/Applications"), FileManager.default.homeDirectoryForCurrentUser.appending(path: "Applications")]
        var found: [DenyList.BundleEntry] = []
        for entry in list.bundles {
            guard let name = entry.appName else { continue }
            for folder in folders {
                let app = folder.appending(path: "\(name).app")
                if let id = Bundle(url: app)?.bundleIdentifier {
                    found.append(DenyList.BundleEntry(id: id, label: entry.label, tier: entry.tier, appName: name))
                    break
                }
            }
        }
        return list.adding(bundles: found)
    }
}
