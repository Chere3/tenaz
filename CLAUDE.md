# CLAUDE.md — Tenaz

Native macOS English-learning app for Spanish-speaking learners (built for ADHD-friendly study, B1+ → B2/C1). Intentionally intrusive (word overlays, a post-unlock writing gate, self-chosen penalties), with a growing mascot, TOEFL-style exams and Tivra-backed anti-cheat.

Read before working:
- `private/STATUS.md` — where the build is and what is next (local only, not published).
- `DECISIONS.md` — assumptions and the **hard safety rules** (overlays off by default with escape hatches, never lock the learner out or interrupt a meeting, Tivra is read-only, Claude only via the `claude` CLI, data stays local).
- `docs/PLAN.md` — product spec, architecture and milestones.
- `docs/research/` — the evidence behind the plan. The starting level (B1+) is described in `DECISIONS.md`; personal notes live in `private/` (not published).

Stack: Swift 6 + SwiftUI/AppKit, macOS 26, XcodeGen (`project.yml`) + SwiftPM (`Package.swift`, `TenazCore` pure-logic library with tests). Never edit the generated `.xcodeproj` by hand.

Commands (full list in `docs/PLAN.md` §0):
```bash
scripts/verify.sh m3 --snap home --smoke overlay --selftest content   # tests + xcodegen + Debug build + snapshots/smokes
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test     # TenazCore tests only
.derived/Build/Products/Debug/TenazDev.app/Contents/MacOS/TenazDev --tenaz-snapshot popover --out .derived/shots/x.png
```
Layout: `Sources/TenazCore` (logic, GRDB), `Tenaz/` (app: `App/`, `Features/<Name>/`, `Services/`, `Shared/DesignSystem/`, `Resources/`), `Content/` (bundled JSON, format in `Content/FORMAT.md`). New migrations: add a `register` function in your area and one line in `Persistence/Migrations.swift`. New screens: one line in `Tenaz/App/SnapshotRegistry.swift`.

Skills: `swiftui-pro` for views, `swift-concurrency` for actors/Sendable, `macos-design-guidelines` for windows/menus, `xcode-build-fixer` when a build breaks.
