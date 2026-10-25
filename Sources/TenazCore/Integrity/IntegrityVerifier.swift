import Foundation

/// Pure: turns Tivra's evidence plus Tenaz's own integrity events into the F5 verdict. No I/O.
///
/// Rules (PLAN F5): a Tivra problem makes the result UNVERIFIABLE, even over a violation (the findings are
/// still listed). Then VIOLATION: a deny match of >= 5 s, a deny-listed phone package, a deny app frontmost
/// > 3 s in Tenaz's log, or more than 3 paste/clipboard/burst flags. Then WARNING: a shorter flash, phone use,
/// 1-3 flags, a deny app frontmost <= 3 s. Otherwise CLEAN.
public struct IntegrityVerifier: Sendable {
    public var denyList: DenyList
    public var mode: DenyMode
    public var violationMinMs: Int64 = 5_000
    public var denyAppFrontmostMs: Int64 = 3_000
    public var maxFlags = 3
    /// Raw focus events of one target closer than this count as the same flash.
    public var flashDedupeMs: Int64 = 10_000

    public init(denyList: DenyList, mode: DenyMode = .strict) {
        self.denyList = denyList
        self.mode = mode
    }

    public func verdict(
        examId: String, window: TivraWindow, verifiedTs: Int64, tivra: TivraEvidence, tenazEvents: [IntegrityEvent]
    ) -> IntegrityVerdict {
        var violations: [IntegrityFinding] = []
        var warnings: [IntegrityFinding] = []
        var problems: [String] = []
        var gap: Int?

        switch tivra {
        case .unavailable(let reason):
            problems = [reason]
        case .available(let reading):
            gap = reading.health.maxGapSeconds
            problems = reading.health.problems
            addMacFindings(reading.foreground, window, &violations, &warnings)
            addPhoneFindings(reading.devices, window, &violations, &warnings)
        }
        addTenazFindings(tenazEvents, &violations, &warnings)

        let level: IntegrityLevel =
            !problems.isEmpty ? .unverifiable : !violations.isEmpty ? .violation : !warnings.isEmpty ? .warning : .clean

        return IntegrityVerdict(
            examId: examId, window: window, verifiedTs: verifiedTs, tivraAvailable: tivra.isAvailable, captureGapMaxSec: gap,
            verdict: level, problems: problems, violations: violations, warnings: warnings,
            timeline: timeline(violations, warnings, tenazEvents))
    }

    // MARK: Findings

    private func addMacFindings(
        _ evidence: ForegroundEvidence, _ window: TivraWindow, _ violations: inout [IntegrityFinding], _ warnings: inout [IntegrityFinding]
    ) {
        var covered: [(start: Int64, end: Int64)] = []
        for span in evidence.spans {
            guard let hit = denyList.match(bundleId: span.bundleId, domain: span.domain, url: span.url, mode: mode) else { continue }
            let ms = window.overlapMs(start: span.startTs, end: span.endTs)
            guard ms > 0 else { continue }
            covered.append((span.startTs, span.endTs))
            let finding = IntegrityFinding(
                startTs: max(span.startTs, window.startTs), endTs: min(span.endTs, window.endTs),
                kind: ms >= violationMinMs ? findingKind(hit.kind) : .flash, label: hit.label, seconds: Int((ms + 500) / 1000))
            if ms >= violationMinMs { violations.append(finding) } else { warnings.append(finding) }
        }
        // Raw events catch a flash that never became a span; skip those a span already explains.
        var lastFlash: [String: Int64] = [:]
        for event in evidence.events {
            guard let hit = denyList.match(bundleId: event.bundleId, domain: event.domain, url: event.url, mode: mode),
                  !covered.contains(where: { event.ts >= $0.start - 1_000 && event.ts <= $0.end + 1_000 })
            else { continue }
            if let last = lastFlash[hit.label], event.ts - last < flashDedupeMs { continue }
            lastFlash[hit.label] = event.ts
            warnings.append(IntegrityFinding(startTs: event.ts, endTs: event.ts, kind: .flash, label: hit.label, seconds: 0))
        }
    }

    private func addPhoneFindings(
        _ usage: [DeviceUsageSpan], _ window: TivraWindow, _ violations: inout [IntegrityFinding], _ warnings: inout [IntegrityFinding]
    ) {
        var otherMs: Int64 = 0
        var first: Int64 = .max
        var last: Int64 = 0
        for span in usage {
            let ms = window.overlapMs(start: span.startTs, end: span.endTs)
            guard ms > 0 else { continue }
            if let hit = denyList.match(packageName: span.packageName, mode: mode) {
                violations.append(IntegrityFinding(
                    startTs: max(span.startTs, window.startTs), endTs: min(span.endTs, window.endTs),
                    kind: .package, label: hit.label, seconds: Int((ms + 500) / 1000)))
            } else {
                otherMs += ms
                first = min(first, max(span.startTs, window.startTs))
                last = max(last, min(span.endTs, window.endTs))
            }
        }
        if otherMs > 0 {
            warnings.append(IntegrityFinding(startTs: first, endTs: last, kind: .phoneActive, label: "Phone", seconds: Int((otherMs + 500) / 1000)))
        }
    }

    private func addTenazFindings(_ events: [IntegrityEvent], _ violations: inout [IntegrityFinding], _ warnings: inout [IntegrityFinding]) {
        for event in events where event.kind == .app {
            let ms = event.durationMs ?? 0
            let finding = IntegrityFinding(
                startTs: event.ts, endTs: event.ts + ms, kind: .tenazApp, label: event.detail ?? "App", seconds: Int((ms + 500) / 1000))
            if ms > denyAppFrontmostMs { violations.append(finding) } else { warnings.append(finding) }
        }
        let flags = events.filter { [.paste, .clipboard, .burst].contains($0.kind) }
        if let first = flags.map(\.ts).min(), let last = flags.map(\.ts).max() {
            let finding = IntegrityFinding(startTs: first, endTs: last, kind: .tenazFlags, label: "\(flags.count) flags", seconds: 0)
            if flags.count > maxFlags { violations.append(finding) } else { warnings.append(finding) }
        }
    }

    private func findingKind(_ kind: DenyMatchKind) -> IntegrityFindingKind {
        switch kind {
        case .bundle: .bundle
        case .domain: .domain
        case .package: .package
        }
    }

    private func timeline(_ violations: [IntegrityFinding], _ warnings: [IntegrityFinding], _ events: [IntegrityEvent]) -> [IntegrityTimelineEntry] {
        func entry(_ f: IntegrityFinding, _ severity: IntegrityTimelineEntry.Severity) -> IntegrityTimelineEntry {
            IntegrityTimelineEntry(startTs: f.startTs, endTs: f.endTs, kind: f.kind.rawValue, label: f.label, severity: severity)
        }
        let info = events.filter { $0.kind == .focusLoss || $0.kind == .tivra }.map {
            IntegrityTimelineEntry(startTs: $0.ts, endTs: $0.ts + ($0.durationMs ?? 0), kind: $0.kind.rawValue, label: $0.detail ?? $0.kind.rawValue, severity: .info)
        }
        return (violations.map { entry($0, .violation) } + warnings.map { entry($0, .warning) } + info).sorted { $0.startTs < $1.startTs }
    }
}

extension TivraEvidence {
    var isAvailable: Bool {
        if case .available = self { true } else { false }
    }
}
