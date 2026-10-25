# 10. Swift engineering practices for Tenaz

Date: 2026-10-22. Scope: how Tenaz should be built as a native Swift 6 macOS app, derived from the author's existing macOS projects (Tivra and others) and the available skills. Everything marked **[verified here]** was run with the reference toolchain on 2026-10-22 (skeleton built, tested, signed in a scratch directory at `<scratch>`). Package versions come from the GitHub API on that date. Apple documentation URLs are cited for orientation and were not re-fetched in this pass, so claims that rest only on them are marked [unverified].

---

## 0. Decisions in one screen

1. **Same layout as Tivra**: XcodeGen `project.yml` + root `Package.swift` with a pure-logic `TenazCore` library and tests. The `.xcodeproj` is generated and gitignored.
2. **Swift 6 language mode, strict concurrency complete, everywhere.** The app target uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` + `SWIFT_APPROACHABLE_CONCURRENCY = YES` (UI-heavy code is main-actor by default). `TenazCore` keeps the *nonisolated* default and is made of value types, `Sendable` structs and a few actors. The two modes are verified to coexist **[verified here]**.
3. **Persistence: GRDB (SQLite)**, not SwiftData. Reasons in section 4.
4. **Spaced repetition: do not take a hard dependency on `swift-fsrs` main.** It has no release after v5.0.0 (Oct 2024); FSRS-6 only exists on `main`, and its README snippet does not compile against the public API (section 5). Wrap it behind a `ReviewScheduler` protocol, pin a commit now, and plan to own a ~200-line FSRS-6 port in `TenazCore` if the library drifts.
5. **Tests: Swift Testing** (`import Testing`) for new code, run with `DEVELOPER_DIR=... swift test`. Tivra uses XCTest (75 files); Swift Testing works on this toolchain **[verified here]**, and the `swift-concurrency` skill says "Swift Testing first, XCTest fallback".
6. **Signing**: copy Tivra exactly (team `<TEAMID>`, Automatic, Apple Development, hardened runtime, not sandboxed). A Debug build signs as `Apple Development: <name> (<cert id>)` with TeamIdentifier `<TEAMID>` **[verified here]**.
7. **Dev/prod side by side**: Debug is `com.chere3.tenaz.dev` / `TenazDev.app`, Release is `com.chere3.tenaz` / `Tenaz.app` (same trick Tivra uses so TCC and LaunchServices identities do not collide).
8. **Install path is always `/Applications/Tenaz.app`** via an `install-tenaz.sh` copied from Tivra's script, so TCC grants stick to one identity.
9. **Safety is code, not convention**: every overlay controller takes an injected `KillSwitch` and `Clock`, and has unit tests for the escape hatches (DECISIONS.md rule 2).
10. **No third-party UI libs.** Allowed deps: GRDB, swift-fsrs (wrapped), KeyboardShortcuts (global kill-switch hotkey). Not needed: Sparkle (personal app, installed by script), SwiftLint (not installed; `swiftformat` is).

---

## 1. Reference toolchain **[verified here]**

| Item | Value |
|---|---|
| Xcode | 26.3 (build 17C529), `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` |
| Swift | 6.2.4 (swiftlang-6.2.4.1.4), target `arm64-apple-macosx26.0` |
| macOS SDK used by xcodebuild | MacOSX26.2.sdk |
| xcodegen | 2.46.0 (`/opt/homebrew/bin/xcodegen`) |
| swiftformat | 0.63.1 (`/opt/homebrew/bin/swiftformat`) |
| swiftlint | not installed. Do not add it; use swiftformat + compiler warnings-as-errors |
| Quirk | bare `swift test` cannot find XCTest/Testing under the command-line toolchain; always set `DEVELOPER_DIR` (Tivra CLAUDE.md says the same) |

Package versions as of 2026-10-22 (GitHub API):

| Package | Latest | Notes |
|---|---|---|
| [GRDB.swift](https://github.com/groue/GRDB.swift/releases) | v7.11.1 (2026-06-18), repo pushed 2026-09-29 | Tivra pins `from: "6.29.0"` (resolved 6.29.3). Tenaz uses 7.x. Two separate apps, no conflict as long as Tenaz never depends on the TivraCore package (section 7). |
| [open-spaced-repetition/swift-fsrs](https://github.com/open-spaced-repetition/swift-fsrs) | tag v5.0.0 (2024-10-29); `main` HEAD `4fbaf201...` (2026-05-25) | README: "A Swift implementation of FSRS-6.0 (FSRS-5.0 supported via 19-length `w`)". Package is `swift-tools-version: 5.10`, builds with `StrictConcurrency=complete`, migrated to Swift Testing in May 2026. |
| [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts/releases) | 3.1.0 (2026-09-11) | Global hotkeys + SwiftUI recorder. Candidate for the kill-switch hotkey. |
| [Sparkle](https://github.com/sparkle-project/Sparkle/releases) | 2.10.0 (2026-09-13) | Not needed. |
| [LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern) | v1.1.0 (2023-12-21) | Stale; use `SMAppService.mainApp` directly instead ([Apple docs](https://developer.apple.com/documentation/servicemanagement/smappservice), [unverified] not re-fetched). |

### XcodeBuildMCP

Tivra's `.mcp.json` registers it. Copy it verbatim into `tenaz/.mcp.json`:

```json
{
  "mcpServers": {
    "XcodeBuildMCP": {
      "command": "npx",
      "args": ["-y", "xcodebuildmcp@2.7.0", "mcp"],
      "env": {
        "XCODEBUILDMCP_ENABLED_WORKFLOWS": "macos,swift-package",
        "XCODEBUILDMCP_SENTRY_DISABLED": "true"
      }
    }
  }
}
```

Run as `npx -y xcodebuildmcp@2.7.0 mcp` (stdio MCP). Tivra's guidance: prefer `build_macos` / `swift_package_test` when connected, hand-typed `xcodebuild` is the fallback. The 2.7.0 pin is current (`npm view xcodebuildmcp version` returned 2.7.0 on 2026-10-22; verified in the verification pass). The `build-macos-apps` skill pipes build output through `xcsift`; it may not be installed (not checked beyond `which`), so ignore that bit.

---

## 2. What the existing Swift projects teach

| Project | Build system | Lesson for Tenaz |
|---|---|---|
| Tivra (sibling project) | XcodeGen `project.yml` + root `Package.swift` (`TivraCore`, `TivraTaxonomy`), tools 6.2, macOS 26, GRDB, XCTest, `.swiftformat` | **Copy this.** Logic in SwiftPM so `swift test` runs in seconds without Xcode project. The `FocusFlow` scheme has no testables, so tests run via SwiftPM, not `xcodebuild test`. Debug/Release split by bundle id and product name. Widgets cannot be tested by `xcodebuild test`. |

Tivra specifics worth copying:

- `project.yml` options: `createIntermediateGroups`, `generateEmptyDirectories`, `minimumXcodeGenVersion: 2.38.0`.
- Debug config sets `PRODUCT_BUNDLE_IDENTIFIER: ...dev`, `PRODUCT_NAME: TivraDev`, and `SWIFT_ACTIVE_COMPILATION_CONDITIONS = TIVRA_DEV_BUILD`.
- `CODE_SIGN_ENTITLEMENTS` file is small: app group, apple-events, calendars, network.server. Tenaz entitlements start empty.
- `.swiftformat`: `--swiftversion 6.0 --indent 4 --exclude <xcodeproj>,.build --disable consecutiveSpaces,numberFormatting,trailingCommas,wrapIfStatementBodies,wrapPropertyBodies`, and the note "apply to the files you touch".
- Tivra has no `defaultIsolation`/`StrictConcurrency` flags in its manifest (grep returned nothing); it relies on Swift 6 mode defaults. Tenaz goes one step stricter.
- Tivra uses `DispatchQueue.main.async` in `FloatingWindowConfigurator`, which `swiftui-pro` forbids. Do not copy that bit.

---

## 3. Architecture

### 3.1 Targets

```
TenazCore (SwiftPM library, nonisolated default, Swift 6)   <- all logic, no SwiftUI/AppKit
  Scheduling/   FSRS wrapper, review queue, difficulty ladder
  Persistence/  GRDB records, migrations, DatabaseQueue/Pool factory
  Learning/     Deck, Card, ExamBlueprint, Rubric, level estimation (CEFR)
  Gamification/ XP, streaks, mascot state machine, achievements
  Safety/       KillSwitch, EscapeHatch policy, MaxOnScreen policy, MeetingGuard protocol
  Claude/       ClaudeRunner (actor), prompt builders, JSON decoding of replies
  Tivra/        TivraReader protocol + read-only SQLite/MCP adapters
Tenaz (app target, MainActor default)                        <- SwiftUI + AppKit glue
  App/ Features/ Services/ Shared/ Resources/
(no helper target yet)
```

- **TenazCore must not import SwiftUI or AppKit.** That is what keeps `swift test` fast and makes the safety logic testable.
- **No helper/XPC target for now.** Reasons: non-sandboxed app, one process is simpler, and a helper adds a second signing/TCC identity. Revisit only if the exam anti-cheat needs a process that survives the app being quit (note: DECISIONS.md rule 2 says nothing may survive a force-quit, so likely never).
- **No widget/extension in v1.** Tivra needs `xcodebuild` to prove widgets work; Tenaz should earn the app first.
- Optional later: a second library `TenazContent` for static word lists/resources, only if resource size slows `TenazCore` builds.

### 3.2 State management

- **Observation framework only.** `@Observable` classes marked `@MainActor` unless the target default is MainActor (it is, for the app target; `TenazCore` stores stay value types or actors). Views own with `@State`, inject with `@Environment`, edit with `@Bindable`. No `ObservableObject`, `@Published`, `@StateObject`, `@EnvironmentObject` (`swiftui-pro` data.md).
- **Stores, not view models per screen.** Five app-wide `@Observable` stores, built in `TenazApp` and injected via `@Entry` environment keys:
  - `ReviewSession` (current queue, current card, answer state)
  - `ProgressStore` (XP, streak, level, achievements; reads from DB)
  - `MascotStore` (mood/growth derived from progress)
  - `OverlayCoordinator` (what is allowed on screen right now, owns the kill switch)
  - `SettingsStore` (backed by `UserDefaults`; note `@AppStorage` must not be used inside an `@Observable` class, `swiftui-pro` data.md)
- **Data flow from DB to UI**: GRDB `ValueObservation` -> `AsyncSequence` -> a `.task {}` in the store (cancelled automatically) -> mutate `@Observable` property. No Combine.
- **Dependency injection**: protocols declared in `TenazCore` (`Clock`, `TivraReader`, `ClaudeRunning`, `NotificationScheduling`, `KillSwitchSource`), concrete implementations in the app target, fakes in tests.

### 3.3 Concurrency rules (Swift 6 strict)

Project settings (the `swift-concurrency` skill demands knowing these first):

| Setting | TenazCore (SwiftPM) | Tenaz app (Xcode) |
|---|---|---|
| Language mode | `swiftLanguageModes: [.v6]` | `SWIFT_VERSION: 6.0` |
| Strict concurrency | implied complete by Swift 6 mode | `SWIFT_STRICT_CONCURRENCY: complete` |
| Default isolation | nonisolated (no `.defaultIsolation`) | `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor` |
| Approachable concurrency | upcoming features `NonisolatedNonsendingByDefault`, `InferIsolatedConformances` | `SWIFT_APPROACHABLE_CONCURRENCY: YES` (the Xcode build log shows it expands to `-default-isolation=MainActor` plus those two upcoming features, **[verified here]**) |
| Warnings | | `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` (build still passes **[verified here]**) |

Rules:

1. UI, stores, window/panel controllers: main actor (default in the app target). Do not sprinkle `@MainActor` as a fix; if a type needs it, say why.
2. Anything off the main thread (DB, Claude subprocess, Tivra reads, FSRS batch scheduling) lives in `TenazCore` as `Sendable` structs, `actor`s, or `nonisolated` async functions. Mark CPU-heavy async work `@concurrent`.
3. **The SQLite connection is the isolation boundary.** GRDB's `DatabaseQueue`/`DatabasePool` are `Sendable` and serialize access; pass records (value types) across, never `Database` handles.
4. Long-lived tasks (observations, overlay timers) are created in a `.task {}` or stored in the owning object and cancelled in `stop()`. Check `Task.isCancelled` in loops.
5. Timers and waits: `try await Task.sleep(for:)` with an injected `Clock`; never `Task.sleep(nanoseconds:)`, never `DispatchQueue`, never `Timer` without a reason (`swiftui-pro` swift.md).
6. `Task.detached` is banned unless a comment states why. `@unchecked Sendable`, `nonisolated(unsafe)`, `@preconcurrency` need a documented invariant and a removal plan (`swift-concurrency` guardrails).
7. **`Process` (the `claude` CLI) is not `Sendable`.** Wrap it in `actor ClaudeRunner`; bridge termination with `withCheckedThrowingContinuation` + `terminationHandler`; add timeout via `withThrowingTaskGroup` racing a `Task.sleep`; always kill the process on cancellation (`withTaskCancellationHandler`). Environment: copy `ProcessInfo.processInfo.environment`, remove `ANTHROPIC_API_KEY`, resolve `~/.local/bin/claude` explicitly (DECISIONS.md rule 4).
8. `NSPanel`/`NSWindow` code is main-actor only; hop back with `await` into main-actor stores, not `MainActor.run` (in a MainActor-default target it is usually redundant, `swiftui-pro` swift.md).
9. Notification and EventKit/NSWorkspace callbacks: convert to `AsyncStream` at the edge, consume in a main-actor task.
10. Prefer `async` APIs over completion handlers wherever both exist.

### 3.4 Folder layout

```
tenaz/
  CLAUDE.md  DECISIONS.md  docs/
  Package.swift                 # TenazCore + tests
  project.yml                   # XcodeGen, app target
  .swiftformat  .gitignore  .mcp.json
  scripts/install-tenaz.sh
  Sources/TenazCore/{Scheduling,Persistence,Learning,Gamification,Safety,Claude,Tivra}/
  Tests/TenazCoreTests/{Scheduling,Persistence,Safety,...}/
  Tenaz/                        # app target sources (feature folders, one type per file)
    App/            TenazApp.swift, AppDelegate (NSApplicationDelegateAdaptor, only if needed)
    Features/       Review/ Onboarding/ Exam/ Mascot/ Achievements/ Settings/ Library/
    Overlay/        WordOverlayPanel, UnlockGatePanel, OverlayCoordinator, KillSwitchHotkey
    Services/       ClaudeCLI, TivraBridge, Notifications, LoginItem, SystemEvents (wake/unlock)
    Shared/         DesignSystem/ (tokens, buttons, motion), Extensions/
    Resources/      Assets.xcassets, Info.plist, Tenaz.entitlements, Localizable.xcstrings, Fonts
```

Layout follows `swiftui-pro`: "Break different types up into different Swift files", folders by feature.

---

## 4. Persistence: GRDB over SwiftData

| Criterion | GRDB | SwiftData |
|---|---|---|
| Already in the family | Yes, Tivra's whole stack (migrations, `TivraMigrations.swift`) | No |
| Testable in `swift test` without Xcode | Yes (in-memory `DatabaseQueue()`, **[verified here]**: insert + fetchCount test passed) | `@Model` needs macro + `ModelContainer`; works but ties logic to Apple frameworks and `@Query` pulls it into views |
| Concurrency under Swift 6 | Records are plain `Sendable` structs; queue is the boundary | `ModelContext`/`@Model` objects are non-`Sendable`; actor-isolation friction (`ModelActor`) |
| Migrations | Explicit `DatabaseMigrator`, versioned, reviewable | Lightweight/custom, opaque |
| Analytics/SRS queries ("cards due before X ordered by stability") | Plain SQL, indexes on `dueAt` | Predicates, less control |
| Reading other SQLite DBs (Tivra's file) | Same library, read-only connection | Not applicable |
| CloudKit sync | No | Yes, but Tenaz is local-only (DECISIONS.md rule 5) |
| Observation of changes | `ValueObservation` as `AsyncSequence` | `@Query` |

Decision: **GRDB 7.x**. Use `DatabasePool` (WAL) in the app and `DatabaseQueue()` in memory for tests. One file at `~/Library/Application Support/Tenaz/tenaz.sqlite`. Keep a nightly copy by `VACUUM INTO` (path under Application Support) as cheap insurance, because a streak is worth protecting. Encryption is not required (Tivra's SQLCipher is not even linked yet; per Tivra CLAUDE.md).

Records: `Card` (lemma, sense id, FSRS fields: due, stability, difficulty, reps, lapses, state, lastReview), `ReviewLog` (append-only, enough to re-fit FSRS parameters later), `Attempt` (exam item + response + rubric score), `WritingEntry` (daily paragraph, Claude feedback JSON), `MascotEvent`, `Achievement`, `Settings` kept in `UserDefaults`, not SQL. Append-only logs make FSRS re-optimization and "undo penalty" safe.

---

## 5. FSRS dependency: what actually happens **[verified here]**

I added `swift-fsrs` at `main` (revision `4fbaf20184d62f82a9f44f343337c61a2c5483e9`) to the skeleton and wrote the README's v6 example. Results:

- `FSRS(parameters: .init(w: FSRSDefaults.defaultWv6))` compiles (`defaultWv6` is public).
- `FSRSDefaults().createEmptyCard()` **does not compile from outside the module**: `error: 'FSRSDefaults' initializer is inaccessible due to 'internal' protection level` (also `createEmptyCard` internal). The README example is wrong for the public API.
- Workaround that compiles and passes a test: build the card yourself with `Card(due: now)` (public memberwise init on a `Sendable`, `Codable` struct) and call `fsrs.next(card:now:grade:).card.due`.
- `next` is `throws` (it throws on `.manual` rating).
- The package declares tools 5.10 and builds under our Swift 6 mode without warnings.

Recommendation:
1. Keep `ReviewScheduler` as the only type that imports `FSRS`. Everything else sees `Date` and a Tenaz `ReviewState` struct.
2. Pin by `revision:` (SwiftPM cannot take `branch:` for a reproducible release). Add a test asserting known intervals for a fixed sequence of grades so a silent algorithm change on update fails CI.
3. If you want zero risk, implement FSRS-6 in `TenazCore` (formulas and 21 default weights are public in the [FSRS wiki](https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm), not re-fetched here [unverified]) and use swift-fsrs only as a test oracle. Decide after the learning-science doc (03) fixes the exact scheduler behaviour needed for "punish if forgotten" (short re-learning steps in the same session, not next day).
4. Do not use `FSRSDefaults.defaultLearningSteps` string steps ("1m","10m") blindly: Tenaz's overlay cadence is a product decision, not an Anki default.

---

## 6. Project skeleton (compiles; copied from the verified scratchpad build)

### 6.1 `Package.swift`

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TenazCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "TenazCore", targets: ["TenazCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.11.1"),
        // swift-fsrs has no tag after v5.0.0 (Oct 2024); FSRS-6 is only on main. Pin the commit.
        .package(url: "https://github.com/open-spaced-repetition/swift-fsrs",
                 revision: "4fbaf20184d62f82a9f44f343337c61a2c5483e9"),
    ],
    targets: [
        .target(
            name: "TenazCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "FSRS", package: "swift-fsrs"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        ),
        .testTarget(
            name: "TenazCoreTests",
            dependencies: ["TenazCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
```

### 6.2 `project.yml`

```yaml
name: Tenaz
options:
  minimumXcodeGenVersion: 2.38.0
  createIntermediateGroups: true
  generateEmptyDirectories: true
configs:
  Debug: debug
  Release: release
settings:
  base:
    SWIFT_VERSION: 6.0
    MACOSX_DEPLOYMENT_TARGET: "26.0"
    SWIFT_STRICT_CONCURRENCY: complete
    SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor
    SWIFT_APPROACHABLE_CONCURRENCY: YES
    SWIFT_TREAT_WARNINGS_AS_ERRORS: YES
packages:
  TenazCore:
    path: .
targets:
  Tenaz:
    type: application
    platform: macOS
    sources:
      - path: Tenaz
        excludes: ["Resources/Info.plist", "Resources/Tenaz.entitlements"]
    dependencies:
      - package: TenazCore
        product: TenazCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.chere3.tenaz
        PRODUCT_NAME: Tenaz
        INFOPLIST_FILE: Tenaz/Resources/Info.plist
        CODE_SIGN_STYLE: Automatic
        CODE_SIGN_IDENTITY: Apple Development
        DEVELOPMENT_TEAM: <TEAMID>
        CODE_SIGN_ENTITLEMENTS: Tenaz/Resources/Tenaz.entitlements
        ENABLE_HARDENED_RUNTIME: YES
        CURRENT_PROJECT_VERSION: 1
        MARKETING_VERSION: 0.1.0
      configs:
        Debug:
          PRODUCT_BUNDLE_IDENTIFIER: com.chere3.tenaz.dev
          PRODUCT_NAME: TenazDev
          SWIFT_ACTIVE_COMPILATION_CONDITIONS: "$(inherited) TENAZ_DEV_BUILD"
    scheme:
      run:
        config: Debug
      archive:
        config: Release
```

Gotcha seen in practice: Tivra excludes `Info.plist`/entitlements only for the widget; for the app they sit under `Resources`, so list them in `excludes` (as above) to avoid "copy bundle resources" warnings, which `SWIFT_TREAT_WARNINGS_AS_ERRORS` does not cover but noisy builds hide real ones.

### 6.3 Minimal sources (all compiled in the scratchpad)

`Sources/TenazCore/Scheduling/ReviewScheduler.swift`:

```swift
import FSRS
import Foundation

/// Thin seam over the FSRS library so the scheduler can be swapped or re-implemented.
public struct ReviewScheduler: Sendable {
    private let fsrs: FSRS

    public init() {
        fsrs = FSRS(parameters: .init(w: FSRSDefaults.defaultWv6))
    }

    public func nextDue(after now: Date, grade: Rating, card: Card? = nil) throws -> Date {
        let current = card ?? Card(due: now)   // FSRSDefaults().createEmptyCard is internal
        return try fsrs.next(card: current, now: now, grade: grade).card.due
    }
}
```

`Sources/TenazCore/Persistence/Database.swift`:

```swift
import Foundation
import GRDB

public struct WordRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "word"
    public var id: Int64?
    public var lemma: String
    public var dueAt: Date
    public init(id: Int64? = nil, lemma: String, dueAt: Date) {
        self.id = id; self.lemma = lemma; self.dueAt = dueAt
    }
}

public enum TenazDatabase {
    public static func makeQueue(path: String? = nil) throws -> DatabaseQueue {
        let db = try path.map { try DatabaseQueue(path: $0) } ?? DatabaseQueue()
        try migrator.migrate(db)
        return db
    }

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "word") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("lemma", .text).notNull().unique()
                t.column("dueAt", .datetime).notNull().indexed()
            }
        }
        return migrator
    }
}
```

`Tests/TenazCoreTests/SchedulerTests.swift` (Swift Testing; both tests pass **[verified here]**):

```swift
import Foundation
import GRDB
import Testing
@testable import TenazCore

@Suite struct SchedulerTests {
    @Test func goodGradeSchedulesInTheFuture() throws {
        let now = Date.now
        let due = try ReviewScheduler().nextDue(after: now, grade: .good)
        #expect(due > now)
    }

    @Test func wordRoundTrips() throws {
        let db = try TenazDatabase.makeQueue()
        try db.write { try WordRecord(lemma: "tenacious", dueAt: .now).insert($0) }
        let count = try db.read { try WordRecord.fetchCount($0) }
        #expect(count == 1)
    }
}
```

`Tenaz/App/TenazApp.swift`:

```swift
import SwiftUI
import TenazCore

@main
struct TenazApp: App {
    var body: some Scene {
        MenuBarExtra("Tenaz", systemImage: "bolt.fill") { Text("Tenaz") }
    }
}
```

`Info.plist` is Tivra's plus `LSUIElement = true` while the app is menu-bar first (flip to false or switch activation policy at runtime when a main window is open); category `public.app-category.education`. `Tenaz.entitlements` is an empty `<dict/>` to start; add `com.apple.security.automation.apple-events`, calendars, etc. only when a feature needs them.

`.gitignore`: `.build/`, `*.xcodeproj`, `DerivedData/`, `.derived/`.

`.swiftformat` (Tivra's, same philosophy):

```
--swiftversion 6.0
--indent 4
--exclude Tenaz.xcodeproj,.build,DerivedData
--disable consecutiveSpaces,numberFormatting,trailingCommas,wrapIfStatementBodies,wrapPropertyBodies
```

---

## 7. Tivra integration boundary (engineering side)

- **Do not add a SwiftPM dependency on `TivraCore`.** Tivra's checkout has uncommitted work and pins GRDB 6.29; Tenaz is on GRDB 7. A path dependency would force a version unification and couple build breaks.
- Define `protocol TivraReader: Sendable` in `TenazCore/Tivra` with the minimum Tenaz needs (frontmost app category over a time window, "is a protected session running", "list blocked-app events during an exam"). Provide two adapters later: (a) read-only GRDB connection to Tivra's SQLite file (`DatabaseQueue(path:configuration:)` with `configuration.readonly = true`), (b) Tivra's MCP. Fakes for tests. Which of (a) or (b) is stable is out of scope here, see the macOS mechanics doc (05).
- Anything that would modify Tivra is a patch in a separate worktree, never installed (DECISIONS.md rule 3).

---

## 8. Build, test, run, install (commands that work here)

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd tenaz

# Unit tests (fast path, SwiftPM only). Verified in the scratchpad skeleton.
swift test
swift test --filter SchedulerTests/goodGradeSchedulesInTheFuture

# Generate + build the app (Debug = TenazDev, signed with team <TEAMID>)
xcodegen generate
xcodebuild -project Tenaz.xcodeproj -scheme Tenaz \
  -derivedDataPath /tmp/tenaz-derived -configuration Debug build
# -> /tmp/tenaz-derived/Build/Products/Debug/TenazDev.app   (BUILD SUCCEEDED, verified)

open /tmp/tenaz-derived/Build/Products/Debug/TenazDev.app

# Format only touched files
swiftformat Sources/TenazCore/Scheduling/ReviewScheduler.swift
```

Rules from Tivra's CLAUDE.md that carry over: do **not** build with `CODE_SIGNING_ALLOWED=NO` (it produces a linker-only stamp; for Tenaz it would also reset the TCC identity). First `swift test` resolves packages over the network (a few seconds to a minute); the first `xcodebuild` also builds GRDB.

Build output is huge in the log (the explicit-module command lines are thousands of characters). Always pipe through `grep -E "error:|warning:|BUILD|CodeSign"` or use XcodeBuildMCP.

### 8.1 `scripts/install-tenaz.sh` (adapted from Tivra's install script)

```bash
#!/usr/bin/env bash
# Builds a signed Release Tenaz.app and installs it at /Applications/Tenaz.app.
# Always the same path, so TCC grants stay attached to one identity.
set -euo pipefail

EXPECTED_ID="com.chere3.tenaz"
EXPECTED_TEAM="<TEAMID>"
DEST="/Applications/Tenaz.app"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED="${TENAZ_DERIVED_DATA:-/tmp/tenaz-release-derived}"
BUILT="$DERIVED/Build/Products/Release/Tenaz.app"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

log() { printf '[install-tenaz] %s\n' "$*"; }
die() { printf '[install-tenaz] ERROR: %s\n' "$*" >&2; exit 1; }

if [[ -d "$DEST" ]]; then
  current_id="$(codesign -dvv "$DEST" 2>&1 | sed -n 's/^Identifier=//p' | head -n1 || true)"
  [[ -z "$current_id" || "$current_id" == "$EXPECTED_ID" ]] || \
    die "$DEST has Identifier=$current_id (expected $EXPECTED_ID). Remove it yourself first."
fi

log "Running tests"; (cd "$ROOT" && swift test)
log "Generating Xcode project"; (cd "$ROOT" && xcodegen generate)
log "Building Release"
(cd "$ROOT" && xcodebuild -project Tenaz.xcodeproj -scheme Tenaz \
  -derivedDataPath "$DERIVED" -configuration Release build)
[[ -d "$BUILT" ]] || die "build product not found: $BUILT"

log "Installing to $DEST"
osascript -e 'tell application id "'"$EXPECTED_ID"'" to quit' >/dev/null 2>&1 || true
ditto "$BUILT" "$DEST"

codesign --verify --strict --deep --verbose=2 "$DEST"
info="$(codesign -dvv "$DEST" 2>&1)"
grep -q "^Identifier=$EXPECTED_ID$" <<<"$info" || die "unexpected Identifier"
grep -q "^TeamIdentifier=$EXPECTED_TEAM$" <<<"$info" || die "unexpected TeamIdentifier"
! grep -qi 'adhoc' <<<"$info" || die "signature is ad-hoc"
log "OK: $DEST installed and verified"
```

Differences from Tivra's: runs tests first, and never installs during the overnight autopilot run (DECISIONS.md: Tivra-side changes are not installed overnight; a first Tenaz install is the learner's call). Login item: register with `SMAppService.mainApp.register()` from a Settings toggle, default off.

---

## 9. Design system engineering

- One `Theme`/token layer in `Tenaz/Shared/DesignSystem` (`swiftui-pro` design.md: "shared enum of constants for fonts, sizes, colors, spacing, animation timings"). Colors in the asset catalog with light/dark and a high-contrast variant; generated symbols (`Color(.brandGreen)`).
- **Liquid Glass**: the `swiftui-liquid-glass` skill is written for iOS 26 and says gate with `#available(iOS 26, *)`. Tenaz targets macOS 26 only, so the gate is unnecessary; use the macOS 26 spelling of the same APIs (`glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass)`/`.glassProminent`) (verified in the MacOSX26.2 SDK swiftinterface: `glassEffect(_:in:)`, `GlassEffectContainer`, `.glass` and `.glassProminent` button styles all exist). `swiftui-expert-skill` says adopt glass only when asked, and `macos-hig-designer` says glass is for the navigation/controls layer, not content. For an ADHD app: **no glass on the big word cards**; use solid, high-contrast surfaces and spend glass on chrome only.
- `apple-hig-designer` is **iOS-oriented** (navigation bar, tab bar, sheets with detents). Use `macos-design-guidelines` and `macos-hig-designer` for Tenaz instead.
- Motion: every animation has a Reduce Motion fallback (opacity only), checked through `@Environment(\.accessibilityReduceMotion)`. The mascot's growth animation must respect it too.
- Type: only Dynamic-Type-capable styles (`.font(.largeTitle)` etc.). "Big words on screen" means `.font(.system(.largeTitle, design: .rounded))`. **Corrected in verification:** the `.font(.body.scaled(by:))` API quoted in `swiftui-pro` accessibility.md for iOS 26 was NOT found in the MacOSX26.2 SDK swiftinterface (the only `scaled(by:)` there is `VectorArithmetic`). [unverified] on macOS; for the oversized overlay word use a user-adjustable size setting (`.system(size:)` driven by a stored multiplier) instead of relying on it.

---

## 10. Top 40 rules for Tenaz (checklist)

Source tags: SP = swiftui-pro, SC = swift-concurrency, SE = swiftui-expert-skill, MG = macos-design-guidelines, MH = macos-hig-designer, LG = swiftui-liquid-glass, PA = swiftui-performance-audit, BM = build-macos-apps, XB = xcode-build-fixer.

**Concurrency and safety**
1. Read the project's isolation settings before touching concurrency code; they are written down in section 3.3 (SC).
2. `@MainActor` only where truly UI-bound; never as a blanket fix (SC).
3. `@Observable` classes are `@MainActor` (or the target default is MainActor, as here) (SP data).
4. No `DispatchQueue`, no `Task.sleep(nanoseconds:)`; use `Task.sleep(for:)` and an injected `Clock` (SP swift).
5. `Task.detached` and `MainActor.run` need a justification; check the Task's synchronous prefix to choose `@concurrent` vs inherited isolation (SC).
6. Every `@unchecked Sendable` / `nonisolated(unsafe)` / `@preconcurrency` carries a written invariant and removal plan (SC).
7. Check `Task.isCancelled` in loops and cancel observation tasks on teardown; verify deallocation of long-lived tasks (SC).
8. No semaphores or ad hoc locks in async code; use actors or `Mutex` (SC).
9. Prefer async over closure APIs; bridge delegate callbacks to `AsyncStream` (SP/SC).
10. Flag mutable shared state not behind an actor or the main actor (SP swift).

**Data flow**
11. `@Observable` + `@State` (owner) + `@Bindable`/`@Environment` (consumer); no `ObservableObject` family (SP data).
12. `@State` is `private` and owned by the creating view (SP data).
13. No `Binding(get:set:)` in `body`; bind to state and use `onChange` with the 0- or 2-parameter form (SP data/api).
14. Never `@AppStorage` inside an `@Observable`; never store secrets in `@AppStorage` (SP data/hygiene).
15. Business logic out of `body`, `task`, `onAppear`; button actions are methods (SP views).
16. Treat each `View` as an invalidation boundary; give it only the data it reads (SE, PA).

**Views and API**
17. One type per file; folders by feature (SP).
18. Extract subviews as `View` structs, not computed `some View` properties (SP views, SP performance).
19. `foregroundStyle`, `clipShape(.rect(cornerRadius:))`, `Tab`, `@Entry` for env keys, `#Preview` (SP api/views).
20. No `onTapGesture` for buttons; use `Button` (SP accessibility).
21. `.animation` always with `value:`; chain with `withAnimation { } completion:` (SP views).
22. Prefer `containerRelativeFrame`/`visualEffect` to `GeometryReader` (SP api).
23. View initializers do no work; async loading in `.task` (cancelled automatically) not `.onAppear` (SP performance).
24. `ForEach` over stable `Identifiable` values; no inline filter/sort in `body` (SP performance, PA).
25. Lazy stacks for long lists (review history, achievements) (SP performance).
26. Use text formats (`Text(date, format:)`), never `String(format:)`; use `^[...](inflect: true)` for plurals (SP swift/api).

**Design, HIG and accessibility**
27. Every icon-only button gets a text label (`Button("Skip", systemImage:, action:)`) (SP accessibility).
28. Honor Reduce Motion, Increase Contrast, and `accessibilityDifferentiateWithoutColor`; correct/incorrect cannot be color-only (SP accessibility). Essential for reward/punish feedback.
29. Dynamic Type everywhere; avoid `.caption2`; no fixed frames that clip big text (SP design/accessibility).
30. Menus: standard app/edit/window/help menus, every command has a shortcut, stable command names and locations (MG 1.x, 5.x).
31. Escape cancels or closes, Return is the default action, full keyboard navigation (MG 5.2-5.4). This is also the safety escape hatch for overlays.
32. Windows remember state, resize with sensible minimums (MG 2.x); the main window must never be the only way to reach Settings or the kill switch.
33. Notifications: match feedback to cognitive cost, do not interrupt unnecessarily; give an alert suppression option (MG 7.x). Tenaz is intentionally intrusive, so every intrusion is a user-configured setting with a visible off switch.
34. Liquid Glass on chrome only, one `GlassEffectContainer` per cluster, `glassEffect` after layout modifiers; solid surfaces for the word card (LG, MH, SE).
35. Use `confirmationDialog`/`sheet(item:)` attached to the triggering UI (SP navigation).

**Process, build, quality**
36. "Prove, don't promise": every change is built, tested, launched before reporting (BM). Tests prove logic, the learner's eyes prove quality.
37. Small verified steps; leave the tree building and tests passing at every stop (BM).
38. Unit tests for all `TenazCore` logic; UI tests only where unit tests cannot reach (SP hygiene). Safety policies (kill switch, max on-screen time, meeting guard, emergency skip penalty) each have a test that fails if the escape hatch is removed.
39. One build-fix at a time, re-benchmark after: explicit type annotations on complex expressions, `final` classes, split huge `body`s, keep `SWIFT_COMPILATION_MODE`/debug-info settings per XB `build-settings-best-practices` (XB). Don't edit generated `.pbxproj`; change `project.yml`.
40. No secrets in the repo; Claude via `claude` CLI only; localized strings in `Localizable.xcstrings` with symbol keys, no user-facing string literals scattered in views (SP hygiene, DECISIONS.md rule 4). Errors from user actions are shown, never only `print`ed (SP swift).

Also worth knowing, from `swift.md`: prefer `Double` over `CGFloat`, `Date.now`, `if let value {`, implicit returns, `localizedStandardContains` for search, `count(where:)`.

---

## 11. Open questions / risks

- **swift-fsrs API gaps** (section 5): decide own port vs pinned dependency before the scheduler is wired in.
- **`SWIFT_TREAT_WARNINGS_AS_ERRORS` with future package updates**: GRDB or FSRS warnings do not affect it (it applies to Tenaz targets only), but SDK deprecations on Xcode updates will break builds. Accept; fix warnings immediately.
- **LSUIElement vs main window**: menu-bar-first apps need `NSApp.setActivationPolicy(.regular)` when a window opens, otherwise windows don't take focus properly [unverified, behavior to test at first window].
- **Swift Testing and `@MainActor` stores**: store tests must be `@MainActor` (`@Test @MainActor func ...`). Not exercised yet.
- **Not checked**: App Intents/Shortcuts, `SMAppService` behavior from a non-notarized dev-signed app, notarization (only needed to share the app; personal use needs none).


## Verification

Checked 2026-10-22 with the reference toolchain, read-only for the Tivra repo. Method: commands run, source files read, GitHub API, npm, SDK swiftinterface grep.

| # | Claim | Verdict | Source |
|---|---|---|---|
| 1 | Xcode 26.3 (17C529), Swift 6.2.4 arm64-apple-macosx26.0, SDK MacOSX26.2, xcodegen 2.46.0, swiftformat 0.63.1, swiftlint and xcsift absent | confirmed | `xcodebuild -version`, `swift --version`, `xcodebuild -showsdks`, `xcodegen --version`, `swiftformat --version`, `which` |
| 3 | Package versions: GRDB v7.11.1 (2026-06-18), KeyboardShortcuts 3.1.0 (2026-09-11), Sparkle 2.10.0, LaunchAtLogin-Modern v1.1.0 (2023-12-21), swift-fsrs v5.0.0 (2024-10-29), main HEAD 4fbaf201 (2026-05-25) | confirmed | `gh api repos/*/releases/latest`, `.../tags`, `.../commits/main` |
| 4 | swift-fsrs: README says FSRS-6.0; `FSRSDefaults().createEmptyCard()` internal; `defaultWv6` public with 21 weights; `Card(due:)` public; tools 5.10 | confirmed (20 literals plus `FSRS6_DEFAULT_DECAY` = 21; `createEmptyCard` declared without `public` at FSRSDefaults.swift:225; README line 14 uses it) | `.build/checkouts/swift-fsrs` in the scratchpad skeleton |
| 5 | Skeleton tests pass under Swift Testing (2 tests) | confirmed, re-run on 2026-10-22 | `DEVELOPER_DIR=... swift test` in `tenaz-skel` |
| 6 | Debug build signs as Apple Development, team <TEAMID>, id `com.chere3.tenaz.dev` | confirmed | `codesign -dvv` on the skeleton's TenazDev.app |
| 7 | Tivra: XcodeGen + root Package.swift (tools 6.2, macOS 26, GRDB `from: "6.29.0"`, resolved 6.29.3), 75 XCTest files and 0 Swift Testing files, no defaultIsolation/StrictConcurrency flags, project.yml options and Debug `TivraDev`/`TIVRA_DEV_BUILD`, team <TEAMID>, `.swiftformat` contents, entitlements (app group, apple-events, calendars, network.server) | confirmed | `apps/macos/{Package.swift,Package.resolved,project.yml,.swiftformat}`, Tests dir, entitlements file |
| 8 | Tivra `FloatingWindowConfigurator` uses `DispatchQueue.main.async` | confirmed (lines 7 and 16) | Tivra `Shared/FloatingWindowConfigurator.swift` |
| 9 | `.mcp.json` copy, `xcodebuildmcp@2.7.0` pin | confirmed identical to Tivra's, pin is the current npm version (was [unverified], now fixed above) | Tivra `.mcp.json`, `npm view xcodebuildmcp version` |
| 10 | Liquid Glass APIs usable on macOS 26 (`glassEffect`, `GlassEffectContainer`, `.glass`, `.glassProminent`) | confirmed (was [unverified], marked above) | MacOSX26.2.sdk SwiftUICore/SwiftUI swiftinterface |
| 11 | `.font(.largeTitle.scaled(by:))` available on macOS 26 | corrected to [unverified]: not present in the macOS SDK interface; text above edited | same swiftinterface grep; `swiftui-pro/references/accessibility.md` says iOS 26 only |
| 12 | `claude` CLI resolved at an explicit install path; Tivra CLAUDE.md on bare `swift test` needing DEVELOPER_DIR and on SQLCipher not linked | confirmed | Tivra `CLAUDE.md` (build notes and SQLCipher note) |
| 13 | install script derived from Tivra's install script (EXPECTED_ID/TEAM/DEST, ditto, codesign checks) | confirmed structure | Tivra install script |
| not checked | Apple doc URLs, SMAppService behavior, FSRS wiki formulas, `Process`/actor patterns, LSUIElement activation policy | remain [unverified] as already marked | none fetched |

Net: no numeric or version claim in the report was wrong; one API claim (`Font.scaled(by:)`) was unsupported on macOS and was corrected, and two [unverified] marks were upgraded to verified.

## Gaps found in verification

- **Tivra data location is not pinned down.** Tivra's entitlements declare an app group and `~/Library/Group Containers/<TEAMID>.com.chere3.focusflow` may exist, plus a separate Application Support folder per variant (production, dev, smoke). The `TivraReader` read-only adapter (section 7) must decide which of these holds the live DB, and Dev vs prod paths differ; Tenaz must not open the Dev one by accident. Not resolved here (doc 05 should).
- **Swift Testing is not used by Tivra at all** (0 files), so the "same layout as Tivra" decision does mix two test frameworks across repos; fine, but CI scripts copied from Tivra assume XCTest output formats.
- **Build output location `/tmp/tenaz-derived`** in sections 6 and 8 conflicts with the session rule to avoid `/tmp`, and `/tmp` is wiped on reboot; use a path under the scratchpad or `~/Library/Developer/Xcode/DerivedData`-style per-project folder for anything the install script depends on.
- **`SWIFT_TREAT_WARNINGS_AS_ERRORS` was verified only on a trivial skeleton.** It may fail once real code uses GRDB 7 / FSRS from `Tenaz` target imports; keep it but expect to relax per-target if a package warning leaks through.
