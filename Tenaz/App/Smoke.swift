import AppKit
import SwiftUI
import TenazCore

/// `--tenaz-smoke <surface>`: shows a surface with real content through the real presenter,
/// lets the watchdog close it after 3 s, writes an intrusion_log row, prints it and exits.
/// `overlay`, `overlay-sticker` and `gate` go through `IntrusionCoordinator` (the real pipeline);
/// any other name shows a generic card.
enum Smoke {
    static let presenter = OverlayPresenter()

    static func run(_ surface: String, environment env: AppEnvironment) {
        if surface == "exam" { return ExamSmoke.run(environment: env) }
        if ["overlay", "overlay-sticker", "gate"].contains(surface) {
            AppDelegate.intrusions.runSmoke(surface)
            return
        }
        let start = Date()
        presenter.onForcedClose = { reason in
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            try? env.database?.writer.write { db in
                try db.execute(sql: "INSERT INTO intrusion_log (ts, surface, trigger, decision, reason, outcome, durationMs) VALUES (?, ?, 'smoke', 'allow', ?, 'timeout', ?)",
                               arguments: [Int(start.timeIntervalSince1970 * 1000), surface, reason, ms])
            }
            let rows = (try? env.database?.reader.read { try Int.fetchOne($0, sql: "SELECT count(*) FROM intrusion_log") }) ?? nil
            print("smoke \(surface) closed by \(reason) after \(ms) ms; intrusion_log rows: \(rows ?? 0)")
            exit(0)
        }
        presenter.show(.fullScreen, maxOnScreen: .seconds(3), activate: true) {
            SmokeCard(surface: surface)
        }
    }
}

private struct SmokeCard: View {
    let surface: String
    var body: some View {
        VStack(spacing: 16) {
            Text("leverage").font(.system(size: 96, weight: .heavy, design: .rounded))
            Text("smoke test: \(surface)").font(.title3).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 28).fill(Color(nsColor: .windowBackgroundColor)))
    }
}
