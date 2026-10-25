import Foundation

/// Which entries count: exams use everything (dictionaries too), practice only forbids AI chatbots.
public enum DenyMode: Sendable {
    case strict
    case practice
}

public enum DenyTier: String, Codable, Sendable {
    case ai, translator, dictionary
}

public enum DenyMatchKind: String, Codable, Sendable {
    case bundle, domain, package
}

public struct DenyMatch: Hashable, Sendable {
    public var kind: DenyMatchKind
    public var label: String
}

/// Apps, sites and Android packages that must not be used during an exam (`Content/denylist.json`, PLAN 4.7).
/// Tenaz owns the list because Tivra has no AI or translator category (06 section 3.2).
public struct DenyList: Codable, Hashable, Sendable {
    public struct BundleEntry: Codable, Hashable, Sendable {
        public var id: String
        public var label: String
        public var tier: DenyTier
        /// Display name used by the app layer to find the real bundle id when `id` is a guess.
        public var appName: String?

        public init(id: String, label: String, tier: DenyTier, appName: String? = nil) {
            self.id = id
            self.label = label
            self.tier = tier
            self.appName = appName
        }
    }

    public struct DomainEntry: Codable, Hashable, Sendable {
        /// Host, optionally followed by a path prefix (`huggingface.co/chat`).
        public var host: String
        public var label: String
        public var tier: DenyTier

        public init(host: String, label: String, tier: DenyTier) {
            self.host = host
            self.label = label
            self.tier = tier
        }
    }

    public struct PackageEntry: Codable, Hashable, Sendable {
        public var id: String
        public var label: String
        public var tier: DenyTier

        public init(id: String, label: String, tier: DenyTier) {
            self.id = id
            self.label = label
            self.tier = tier
        }
    }

    public var bundles: [BundleEntry]
    public var domains: [DomainEntry]
    public var androidPackages: [PackageEntry]

    public init(bundles: [BundleEntry] = [], domains: [DomainEntry] = [], androidPackages: [PackageEntry] = []) {
        self.bundles = bundles
        self.domains = domains
        self.androidPackages = androidPackages
    }

    public static func load(from url: URL) throws -> DenyList {
        try JSONDecoder().decode(DenyList.self, from: Data(contentsOf: url))
    }

    /// Adds bundle ids resolved at runtime (the app layer looks installed apps up by `appName`).
    public func adding(bundles extra: [BundleEntry]) -> DenyList {
        var copy = self
        let known = Set(bundles.map { $0.id.lowercased() })
        copy.bundles += extra.filter { !known.contains($0.id.lowercased()) }
        return copy
    }

    /// Match a Mac foreground sample. Bundle ids win over domains.
    public func match(bundleId: String?, domain: String?, url: String?, mode: DenyMode) -> DenyMatch? {
        if let bundleId, let hit = bundles.first(where: { applies($0.tier, mode) && $0.id.caseInsensitiveCompare(bundleId) == .orderedSame }) {
            return DenyMatch(kind: .bundle, label: hit.label)
        }
        let parsed = url.flatMap { URL(string: $0) }
        guard let host = (domain ?? parsed?.host)?.lowercased(), !host.isEmpty else { return nil }
        let path = parsed?.path.lowercased() ?? ""
        for entry in domains where applies(entry.tier, mode) {
            let parts = entry.host.lowercased().split(separator: "/", maxSplits: 1)
            guard let entryHost = parts.first.map(String.init), host == entryHost || host.hasSuffix("." + entryHost) else { continue }
            if parts.count == 2, !path.hasPrefix("/" + parts[1]) { continue }
            return DenyMatch(kind: .domain, label: entry.label)
        }
        return nil
    }

    public func match(packageName: String?, mode: DenyMode) -> DenyMatch? {
        guard let packageName,
              let hit = androidPackages.first(where: { applies($0.tier, mode) && $0.id.caseInsensitiveCompare(packageName) == .orderedSame })
        else { return nil }
        return DenyMatch(kind: .package, label: hit.label)
    }

    private func applies(_ tier: DenyTier, _ mode: DenyMode) -> Bool {
        mode == .strict || tier == .ai
    }
}
