# Contributing to Tenaz

Thanks for your interest. Tenaz is a native macOS English-learning app (Swift 6, SwiftUI/AppKit) with a mascot, TOEFL-style exams and deliberately intrusive habit tools. Issues and pull requests are welcome.

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md). Report security problems privately, see [SECURITY.md](SECURITY.md).

## Requirements

- macOS 26 and Xcode 26 (Swift 6.2 toolchain; `Package.swift` uses `swift-tools-version: 6.2` and `.macOS(.v26)`)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.38 or newer (`brew install xcodegen`)

## Setup

```bash
git clone https://github.com/Chere3/tenaz.git
cd tenaz
xcodegen generate        # creates Tenaz.xcodeproj from project.yml
open Tenaz.xcodeproj
```

Never edit the generated `.xcodeproj` by hand; change `project.yml` and regenerate. The project is gitignored.

### Signing

`project.yml` carries the owner's `DEVELOPMENT_TEAM`, which will not work for you. Either build with your own team:

```bash
xcodebuild -project Tenaz.xcodeproj -scheme Tenaz -configuration Debug \
  -derivedDataPath .derived build DEVELOPMENT_TEAM=<your-team-id>
```

or build unsigned, which is enough to check that your change compiles:

```bash
xcodebuild -project Tenaz.xcodeproj -scheme Tenaz -configuration Debug \
  -derivedDataPath .derived build CODE_SIGNING_ALLOWED=NO
```

Do not commit a change to `DEVELOPMENT_TEAM`.

## Tests

```bash
swift test                 # TenazCore (pure logic, GRDB) tests
scripts/verify.sh m3 --snap home --smoke overlay --selftest content
```

`scripts/verify.sh` runs the tests, regenerates the project, does a Debug build and then the snapshots, smoke runs and self-tests you list. It assumes your Xcode lives at `/Applications/Xcode.app` and uses the owner's signing setup, so contributors may prefer `swift test` plus the unsigned build above. Full command list: `docs/PLAN.md` section 0.

### Snapshots

Screens render headlessly to PNG, which is how UI changes are reviewed:

```bash
.derived/Build/Products/Debug/TenazDev.app/Contents/MacOS/TenazDev \
  --tenaz-snapshot popover --out .derived/shots/popover.png
```

Attach before/after snapshots to UI pull requests.

## Where things live

Read `CLAUDE.md` for the layout and `docs/PLAN.md` for the spec and architecture.

- `Sources/TenazCore`: logic and persistence (GRDB), unit-tested
- `Tenaz/`: the app (`App/`, `Features/<Name>/`, `Services/`, `Shared/DesignSystem/`, `Resources/`)
- `Content/`: bundled JSON content; format in `Content/FORMAT.md`
- `docs/`: plan, research, design (`docs/design/full-bleed.md`)

## Conventions

- **New screen:** add one line to `Tenaz/App/SnapshotRegistry.swift` so it can be rendered with `--tenaz-snapshot`.
- **New database migration:** add a `register` function in your feature area and one line in `Persistence/Migrations.swift`.
- Put testable logic in `TenazCore`, not in views.
- Swift 6 strict concurrency is on; keep it warning-free.
- Follow the Full Bleed design language (`docs/design/full-bleed.md`).

## Safety rules every PR must keep

Tenaz is intrusive on purpose, which makes these rules non-negotiable (see `DECISIONS.md`):

1. Every overlay, gate or other intrusion ships **disabled by default**.
2. Every intrusion has a tested **escape hatch**: an emergency skip (with a penalty, not a lockout), a global kill-switch hotkey, a `defaults write` kill switch and a maximum on-screen time. Nothing may lock a user out of their Mac or survive a force-quit.
3. Never interrupt a meeting.
4. The unlock gate is a full-screen panel after unlock/wake, not a security boundary, and never replaces the macOS login.
5. **Data stays local** (Application Support). No telemetry, no uploads.
6. Claude is used **only through the `claude` CLI** (the user's own session), never an API key; the child process environment must strip `ANTHROPIC_API_KEY`. Core features must work without Claude.
7. Tivra integration is read-only.

## Commits and pull requests

Look at `git log` for the style: a short imperative sentence in English, optionally prefixed with an area (`install-tenaz: ...`, `docs: ...`), e.g. `Add app icon, live Dock icon, login item and install script`. Keep PRs focused, and fill in the PR template checklist.

## Content licensing

Only redistributable sources may be added to the public tree (permissive, or CC BY-SA with attribution). Non-commercial, research-only or unclear-licence sources use the `.nc.json` suffix and are gitignored; do not commit them. Every file with third-party or derived text needs an entry in `Content/licenses.json`; then regenerate the table:

```bash
python3 scripts/gen-content-licenses.py   # rewrites Content/LICENSES.md
```
