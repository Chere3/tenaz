# Tenaz: product and engineering plan

Single source of truth for building Tenaz. Written 2026-10-22 from the 11 research reports in `docs/research/` (including their Verification sections), and `DECISIONS.md`. Every feature points to the research section that justifies it. `[unverified]` tags carried over from the reports stay. Where reports disagreed, section 2 settles it once, and the rest of this file follows that ruling.

Notation: `[03 §4.3]` means `docs/research/03-learning-science.md`, section 4.3. Files: [01](research/01-adhd-psychology.md), [02](research/02-gamification-mascot.md), [03](research/03-learning-science.md), [04](research/04-exams-cefr.md), [05](research/05-macos-mechanics.md), [06](research/06-tivra-integration.md), [07](research/07-competitors.md), [08](research/08-content-books.md), [09](research/09-prior-art.md), [10](research/10-swift-practices.md), [11](research/11-design-system.md).

---

## 0. Commands (the block CLAUDE.md points to)

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd path/to/tenaz

swift test                                   # all TenazCore tests (Swift Testing)
swift test --filter SafetyTests              # one suite
xcodegen generate                            # regenerate Tenaz.xcodeproj (never edit it)
xcodebuild -project Tenaz.xcodeproj -scheme Tenaz -configuration Debug \
  -derivedDataPath .derived build 2>&1 | grep -E "error:|warning:|BUILD"
APP=.derived/Build/Products/Debug/TenazDev.app

# Render a screen to PNG without any TCC permission, then exit (added in M1)
"$APP/Contents/MacOS/TenazDev" --tenaz-snapshot home --out .derived/shots/home.png

# Launch, prove it runs, try a real screenshot, quit
open "$APP"; sleep 4; pgrep -x TenazDev && screencapture -x .derived/shots/screen.png; pkill -x TenazDev

# Wraps all of the above. First arg = lowercase label (names the PNGs), then any number of
# --snap <screen>, --smoke <surface>, --selftest <name>; fails if overlaysEnabled is left on.
scripts/verify.sh m3 --snap home --smoke overlay --selftest content
```

Derived data lives in the gitignored `.derived/` folder, not `/tmp` (`/tmp` is wiped on reboot and the session rules avoid it; [10 Gaps]). `CLAUDE.md` already shows these commands. Content file formats are in `Content/FORMAT.md` (the reference for every content JSON; this plan does not repeat it).

Reference toolchain: Xcode 26.3, Swift 6.2, macOS 26 SDK, xcodegen, swiftformat, no swiftlint [10 §1]. The `claude` CLI is expected at `~/.local/bin/claude` (the native installer location), and `claude auth status --json` should report `authMethod: "claude.ai"`.

### 0.1 Already built (on `main` at 36a6208)

Rule: **the names on disk win.** Every plan name below is used in this file with its on-disk name; no rename is scheduled (wave 1 is editing these files in `../tenaz-wt/*` worktrees, and a rename would collide with its merges). When wave 1 merges, the orchestrator updates this table.

| Plan concept | File on disk | Commit | State / gap the next milestone closes |
|---|---|---|---|
| Scaffold (M1): XcodeGen app + SwiftPM `TenazCore` | `project.yml`, `Package.swift`, `.swiftformat`, `.gitignore`, `Tenaz/App/TenazApp.swift` (`MenuBarExtra`, `systemImage: "flame.fill"`), `MenuPopover.swift`, `AppEnvironment.swift` | 2ab771a | done; `.mcp.json` not yet added (M3 adds it if XcodeBuildMCP is wanted). `MenuBarExtra` is replaced by `NSStatusItem` in M6 (ruling 13) |
| Launch modes `--tenaz-snapshot/--tenaz-smoke/--tenaz-selftest` | `Tenaz/App/{LaunchArguments,Snapshot,Smoke,SelfTest,SnapshotRegistry}.swift` | 495fab8 | done; new screens add one line in `SnapshotRegistry.swift`, new self-tests add a `case` in `SelfTest.swift` |
| `scripts/verify.sh` | `scripts/verify.sh` (label + `--snap/--smoke/--selftest`) | 495fab8 | done |
| `Paths`, `Clock`, `TenazDatabase`, `Migrations` | `Sources/TenazCore/Persistence/{Paths,TenazDatabase,Migrations}.swift`, `Support/Clock.swift` | 495fab8 | done; each area adds a `register` function + one line in `Migrations.swift` |
| `FSRS6` + learning steps (plan: `Scheduling/FSRS6.swift`) | `Sources/TenazCore/SRS/FSRS.swift` (`FSRS`, `FSRSConfig`, `MemoryState`, `ReviewLog`, `Rating`, `CardState`) | 0f75cd7 | done, golden vectors pass (`FSRSTests`). `ReviewQueue`/`AnswerMatcher` go in `SRS/` too |
| Content models + validator (plan: `Learning/Note.swift`, `Content/seed`) | `Sources/TenazCore/Content/{ContentModels,ContentValidator}.swift` (`VocabEntry`, `ExamItem`, `ContentLibrary`, `WordGap`); `Content/FORMAT.md` | 92a254e, 495fab8 | done (`ContentTests`) |
| Seed vocabulary (plan: `Content/seed`, ~200 notes) | `Content/vocab/*.json`: 12 files, **740 entries** (each entry is one *note*; cards are derived per F3) | 495fab8 | done, except: only 6 entries carry the `error-pattern` tag (`false-friends.json`, `workplace-meetings.json`); M2 adds the 12 common Spanish-L1 error patterns as `Content/vocab/error-patterns.json` with the learner's own wrong form as a distractor |
| Starter item bank (plan: ≥150 items in M10) | `Content/items/*.json`: 11 files, **436 items** (grammar, complete-words, build-sentence, reading, listening scripts, speaking, writing prompts, 80 life-paragraph prompts) | 495fab8 | done; anchors not yet marked (M10) |
| `ClaudeRunner` | `Sources/TenazCore/Claude/ClaudeCLI.swift` (`ClaudeCLI`, `environment(from:)`, `decodeStructured`) | 00deef0 | "slim": args + env scrub + decode; job queue, timeout ladder and health check are M8 |
| `RaschGrid` + `ObjectiveScorer` | `Sources/TenazCore/Exams/AbilityEstimator.swift` (`AbilityEstimator`, `ObjectiveScorer`: gaps, build-sentence, WER, repeat score) | 00deef0 | done for scoring (`ExamScoringTests`); per-skill posterior storage is M10 |
| `InterruptionGuard` + `IntrusionPolicy` | `Sources/TenazCore/Safety/InterruptionPolicy.swift` (`InterruptionSignals`, `InterruptionPolicy.decide`, `OverlaySchedule`, `EscapeAction`) | 7452645 | gaps closed in M5: decision is only `.allow/.deferred(reason:)` (needs `.allow(maxMode:)` and `.deny`); signals are unattributed `Bool?` (needs holders, F14); `maxIdleSeconds = 120` is kept (F14 now says 120 s) |
| Kill switch, signal probes, overlay panel (plan: `Services/Signals/*.swift`) | `Tenaz/Services/Safety/{KillSwitch,SignalProbes,OverlayPanel}.swift` | dc3f82a | probes exist but are device-level (mic) and unattributed (assertions); M5 replaces them per F14. Panel has a watchdog |
| `CEFRLevel` | `Sources/TenazCore/CEFRLevel.swift` | 92a254e | done |

The folder layout in 4.2 and every milestone below use these names.

---

## 1. Vision and the daily loop

### 1.1 Vision (5 lines)

1. Tenaz is a native Mac app that comes to the learner, not the other way round: English retrieval prompts appear at the natural gaps of the learner's day, big and impossible to ignore, and never during a meeting.
2. Every intrusion is a short act of recall or production (type the word, write two sentences about your morning), scheduled by FSRS so it lands right before the learner would forget.
3. The learner writes their own contract: they pick the stakes (mascot health, a repair task, a stricter gate), and every gate has an honest, priced, always-working way out.
4. Tena, an axolotl, grows only with proven skill (mastered chunks and verified exam bands), so her stage is a real measure of the learner's English, not of time spent in the app.
5. Exams are modeled on the 2026 TOEFL iBT (with IELTS task types and an approximate IELTS band beside the Tenaz band), get harder as the learner improves, and count only when the Mac (and Tivra, as a read-only witness) saw no AI help.

### 1.2 Core daily loop (what the learner experiences)

Times are an example weekday. Everything intrusive ships off (section 5) and is switched on once, deliberately, in the "Arm Tenaz" step (F10). Every step defers automatically when `InterruptionPolicy` (F14) sees a call or meeting (mic, camera or call audio attributed to a call app, a calendar event, a presentation), Focus, or quiet hours, and anything already on screen closes for free if a meeting starts.

| When | What happens | Duration | Feature |
|---|---|---|---|
| First unlock (about 08:30) | **Unlock gate**: full-screen notebook page. Tena: "Morning. Tell me about your plan for today in 2-3 sentences. Use *follow up on*." Live word counter fills; Return unlocks. Local checks pass instantly; Claude's feedback arrives a few seconds later as a sticker in the corner. | 1-3 min | F2, F6 |
| Right after | 5-7 due reviews in the gate's follow-up ("finish your morning set"), typed recall | 2 min | F3 |
| Before a calendar meeting (T-10 min) | A notification only (no overlay): "Warm up: 3 meeting chunks", answerable from the banner | 30 s | F14, F4 |
| Between work blocks (app switch after 25+ min of deep work, idle return, unlock) | **Word overlay**: a 20-second pulse on the menu-bar icon, then a poster-sized word slams in; 3 items; each answer closes in under 1 s with sound and XP; a missed word returns in 1 min, then 10 min, then on the next gate | 20-60 s each, up to 8 a day | F1, F3 |
| Lunch | **Input block** from the menu bar: one knowledge card or a graded passage at about 95-98% known-word coverage, 3 questions, up to 5 new cards picked | 10 min | F11, F4 |
| Afternoon | **Output block**: one writing or speaking task (rotates: email, role-play with Claude as a colleague, 4/3/2 talk), prompt-first correction | 10 min | F4, F6 |
| Any time, once | **Daily Check**: 4-7 min adaptive quiz; moves the private level estimate and the trend arrow | 5 min | F5, F7 |
| Evening close (before 22:30 quiet hours) | Recap of today's new items, "capture from life" (3 phrases the learner needed in today's meetings), quests close, Tena eats (vitality up), streak ticks | 5 min | F4, F8, F9 |
| Night | Tena is asleep; nothing appears | - | F14 |
| Thursday-Sunday | Weekly Mock as 3 sections of about 12 min on any 3 days (or one 35-40 min sitting) in Exam Mode | 3 × 12 min | F5 |
| Sunday | 5-minute weekly review: what worked, hatch and penalty counts, which rules to keep, one if-then plan | 5 min | F10, F16 |
| Every 4 weeks | Monthly Full Mock (about 90 min in total), taken section by section within a 72-hour window: the only thing that moves the public band and unlocks Tena's evolution | 4-5 sections | F5, F7, F8 |
| First week only | Placement as 5-minute probes, one a day inside the Daily Check slot (the level in the initial level estimate is the prior, so day 1 needs no test) | 5 min | F5, F7 |

**Minimum viable day** (keeps the streak and Tena fed): 10 correct retrievals + 1 produced sentence, which takes about 4 minutes. Resolved in section 2, row 2.

---

## 2. Rulings on conflicts between the reports

| # | Topic | Conflict | Ruling | Why (discriminating constraint) |
|---|---|---|---|---|
| 1 | FSRS implementation | swift-fsrs [03 §4.3], port the earlier prototype, wrap + pin [10 §5] | **Own FSRS-6 port in `TenazCore`** (about 250 lines) with py-fsrs-style learning steps. **No swift-fsrs dependency.** py-fsrs 6.3.2 is the oracle via generated fixtures | Same-session relearning (1 min / 10 min, relearn 10 min) is required so a forgotten word comes back before the gate ends; swift-fsrs `createEmptyCard()` is internal and has no release after v5.0.0 [10 §5]; rounding must match py-fsrs exactly |
| 2 | Daily minimum | 3 items / 60 s [01 R2], 5 min or 10 reviews [02 §4.5], 8-min MVD [03 §10.2] | **Overlay batch = 3 items (≤60 s). Daily minimum = 10 correct retrievals + 1 production item.** | A batch must be tiny (R2); the streak must not be farmable with trivial taps [07 gap 5] |
| 3 | Streak freezes | 2 [02 §4.5] vs 3 in the earlier prototype | **Hold max 2, earn 1 per 7 qualified days.** Headline metric is **days practiced in the last 7** (5 of 7 = weekly goal) | Broken streaks reduce later engagement and repair softens it ([Silverman & Barasch 2023](https://udspace.udel.edu/items/42ce576b-8e1f-429a-8541-e29e48dbcfbb), [01 §3.2]) |
| 4 | Skip costs and caps | -20 Vitality [11], token + -20 [02 §4.4], 5-min cap + recovery mode [01 R10] | One ladder (F10 table): gate emergency skip -20 Vitality (-10 with a Mercy token, 3 a month); **daily penalty cap -30 Vitality and ≤5 min of penalty tasks; after 3 penalty events in a day, recovery mode** | Proportionate, capped penalties prevent the punishment spiral that drives uninstalling [01 §3.6] |
| 5 | Unlock gate size | 1-3 sentences [01 R23], 40 words [11 §6.3], 50-80 words [03 E9] | **Default 2-3 sentences, 25-40 words, uses 1 target chunk. Max on screen 5 min.** A weekly optional "journal" mode asks 80-150 words | Working-memory cost and the escape rule [01 §2.1, R23] |
| 6 | Exam scale in stage gates | "E ≥ B2" [02 §4.2] vs TOEFL 1-6 [04 §0] | **One public scale: TOEFL-style 1-6 in 0.5 steps.** Labels: 3.0 B1, 3.5 B1 high, 4.0 B2 low, 4.5 B2 high, 5.0 C1 low, 5.5 C1 high. Stage gates are written in bands (F8). Never round up | ETS: same number = same CEFR in every section, 4 and 4.5 are both B2 ([ETS score scale 2026](https://www.mx.ets.org/content/dam/ets-org/pdfs/toefl/score-scale-update-2026.pdf), [04 §1.1, Gaps]) |
| 7 | Mastered-word gates | 100-5,000 [02 §4.2] vs 25-40 new items a week [03 §5] | **Gates live in a tunable config table** (`Content/config/stages.json`) with lower defaults (F8: stage 4 = 150 mastered notes + 4 weeks); stage 3 is granted provisionally on day 1 from the initial level estimate; the new-card budget counts **notes**, not cards (F3), so "35 new a week" means 35 notes; visible micro-growth every 25 mastered notes fills the gaps between stages | At 35 new notes a week, 5,000 mastered would take about 3 years; with per-card budgets and 6 siblings a note, intake was really 1-3 notes a day and Tena froze for months |
| 8 | Tivra read channel | Read the SQLite file [06 §1.1] vs "integrity bar from Tivra's MCP" [11 §6.4] | **Read-only SQLite file** `~/Library/Application Support/Tivra/tivra.db` (production folder only, never a dev or smoke-test variant folder). MCP and companion are not used in v1 | MCP and companion bind only to the Tailscale IP and need tokens/pairing [06 §0] |
| 9 | Exam with Tivra down | "refuses to start" [05 §6] vs "unranked" [06 §4.3] | **Always starts; result is `UNVERIFIABLE`** (practice stats only, no promotion, no XP, no streak credit) | Never block the learner (DECISIONS rule 2) |
| 10 | AI app bundle ids | `com.openai.chat`, `com.google.Gemini` [05 §6] | **During an exam section the only allowed frontmost app is Tenaz** (allowlist, F5). The bundle ids `com.openai.codex` (ChatGPT.app), `com.google.GeminiMacOS`, `com.anthropic.claudefordesktop` (resolved at runtime) plus terminals, Raycast and AI-enabled browsers are kept only in `denylist.json` for the Tivra post-hoc scan | Bundle ids checked against each app's Info.plist [06 Verification 11]; a deny-list always lags new AI tools, and realistic cheating paths (AI coding tools in a terminal, Raycast AI, a browser's built-in chat) were missing [05 §6] |
| 11 | Which exam to follow | Aptis [04 §1.8] vs TOEFL iBT (DECISIONS) vs IELTS | **Exams follow the TOEFL iBT 2026 blueprint, plus IELTS Speaking Part 2 cue cards and Writing Task 2 essays in the rotation, plus a Grammar & Vocabulary block.** Show an approximate IELTS band beside the Tenaz band (F7). Open question in section 7 | TOEFL is the only current, public, CEFR-tagged blueprint [04 §0.2]; IELTS is the other widely used exam; the IELTS Part 2 long turn is the exam task closest to talking in a meeting ([IELTS speaking format](https://ielts.org/take-a-test/test-types/ielts-academic-test/ielts-academic-format-speaking)); a grammar block covers the learner's accuracy weakness [04 §1.8] |
| 12 | Kill-switch hotkey | Cmd+Opt+Esc in the wireframe [11 §6.2] | **Ctrl+Opt+Cmd+Esc** (Cmd+Opt+Esc is the system Force Quit; keep it free) | [05 §5] default; avoid shadowing Force Quit |
| 13 | Menu bar | `NSStatusItem` [05 §5] vs `MenuBarExtra` [10 §6.3] | **`MenuBarExtra` in M1 (built); `NSStatusItem` + `NSPopover` hosting the same SwiftUI popover view from M6**, pulse = timed swaps of `button.image`. The menu bar is never the only warning: the pre-announcement also plays a tick and shows a non-key sticker (F1) | `MenuBarExtra` has no API to open its window programmatically or animate the item, and the item can be hidden by the notch or the menu-bar settings; the pulse is needed in M6, not M14 |
| 14 | Browser URL checks in exams | AppleScript per browser [05 §6] | **Not in v1.** Use frontmost bundle id (Tenaz-side) + Tivra `window_focus` domains | AppleScript needs a TCC prompt per browser; Tivra already records browser URLs [06 §1.1] |
| 15 | Foundation Models | Router for instant hints [05 §9] | **Not in v1** (backlog). Local deterministic checks give instant feedback; Claude gives rich feedback in about 3 s | Simplicity; core must not depend on Apple Intelligence being on |
| 16 | Mascot rendering | Canvas v1, Rive v2 [11 §7.2] | **SwiftUI Canvas only in v1**, behind `MascotRenderer` | Zero dependencies |
| 17 | Leech threshold | 6 lapses [03 §11.1] vs 8 [02 achievement 14] | **6 lapses**; achievement "Leech Hunter" uses the leech flag | One definition |

Do not cite in code, UI or docs: Ariely & Wertenbroch 2002 (retracted 2 Sep 2026 [01 §3.1]); Deci et al. "-0.40 tangible" (it is -0.34 [01 §3.3]); "FSRS needs 20-30% fewer reviews" [03 §4.2]; Duolingo blog percentages as causal [02 Gaps]; the "85% rule" as validated for humans; Listening "18 min" (it is 25-29 min [04 §1.1]).

---

## 3. Feature spec

Each feature lists defaults, mechanics, evidence and the milestone that builds it. "Off by default" means the toggle ships `false` and the onboarding never flips it silently.

### F1. Word overlays ("big words on screen") with recall, reward and penalty (M6)

**What it is.** A poster-sized retrieval prompt in a borderless `NSPanel` per screen. Two modes: **poster** (paper card over ~70% of the screen) and **sticker** (360x200 pt card in the bottom-right, no sound, for light interruption). Off by default.

**Mechanics.**
- Batch of 3 items from FSRS-due cards of auto-scorable types only (R, L, C, K; never P), chosen by `ReviewQueue` with sibling burying and interleaving [03 §11.1].
- Prompt types: big English chunk + 4 Spanish glosses (R, multiple choice) or big Spanish cue / cloze sentence + typed English answer (L, C, K). Focus goes to the answer field; Return submits; `?` shows a hint (R4, R2 in [11 §1.2]).
- **Never steal keystrokes meant for another app.** The panel appears only after **≥2 s with no keyDown** (`CGEventSource.secondsSinceLastEventType(.combinedSessionState, .keyDown)`; if the learner keeps typing, it waits, up to the trigger's 5-min validity, then drops the trigger). The answer field is **inert for the first 600 ms** after showing: input received in that window is discarded, and Return is **never accepted as submit within 1 s** of showing. If the panel appeared less than 2 s after a keyDown anyway (race), a wrong answer typed with no hint is logged `earlyInput` and **not penalized** (no Spirit loss, no relearning step).
- **AI-free answer field** (shared `AnswerField` → custom `NSTextView`, also used by F2 and F5): `writingToolsBehavior = .none` (macOS 15+, [Apple](https://developer.apple.com/documentation/appkit/nstextview/writingtoolsbehavior)), `inlinePredictionType = .no` (macOS 14+, [Apple](https://developer.apple.com/documentation/appkit/nstextview/inlinepredictiontype)), and `isAutomaticSpellingCorrectionEnabled`, `isContinuousSpellCheckingEnabled`, `isGrammarCheckingEnabled`, `isAutomaticTextCompletionEnabled`, `isAutomaticTextReplacementEnabled`, `isAutomaticQuoteSubstitutionEnabled` all `false`; the context menu drops Writing Tools, Spelling and Grammar, Substitutions and Services. Both properties are declared in the MacOSX26 SDK `NSTextView.h` (lines 434, 485). Otherwise typed recall turns into accepting a suggestion.
- **Reward if remembered** (feedback in under 100 ms, tier S [11 §5.4]): green + check glyph + "+12 XP" sticker, a kalimba pluck whose pitch rises with the combo, Tena blinks, Spirit +2. 3/3 correct = tier M. XP formula in F9.
- **Penalty if forgotten**: red border + the right answer shown big with a strike-through on the learner's wrong answer (no shake beyond 2 pt, no buzzer), Spirit -3, combo reset, and the card enters a **relearning step: it comes back in 1 min, then 10 min**, at the next overlay or gate. A card failed twice in one day is injected into the next unlock gate as the required chunk ("use *reliable* in your sentence"). This is the "punishment": the forgotten word becomes intrusive until it is retrieved [01 R8].
- **Triggers** (only at boundaries, never mid-task [01 §4, R4, R5]): unlock/wake (when the gate is off or already done), app switch after 25+ min of continuous single-app work (respects hyperfocus by waiting for it to end [01 §2.7]), return from 5+ min idle, the end of a Tivra focus block (read from `sessions` in Tivra's DB, M11). WaitChatter found learners most receptive right after finishing an action ([Cai et al. CHI 2015](https://sls.csail.mit.edu/publications/2015/Cai_CHI-2015.pdf), 20 participants, 57 words in 2 weeks [01 §4]).
- **Pre-announcement** (20 s before an overlay), on three channels so it never depends on the menu bar being visible (the item can sit behind the notch or be hidden by the menu-bar settings): the `NSStatusItem` icon pulses (timed `button.image` swaps), a soft tick plays (unless muted), and a **non-key 20-second sticker** "Words in 20 s — Not now" appears bottom-right. One click on "Not now" snoozes 15 min for free (R5 [11 §1.2]).
- **Caps (defaults)**: max 8 batches a day, at least 40 min apart, never in quiet hours (22:30-08:00), never when `InterruptionPolicy` defers (F14). A chat app frontmost with no hard signal limits the batch to sticker mode (F14).
- **Escape ladder** on the panel, always visible: `Esc` = skip this batch (-3 Vitality if Response cost is on, counted as a skip); `Ctrl+Opt+Cmd+S` = snooze 5 min (free, 3 a day); "I'm in a meeting" = defer 60 min (free when corroborated or within 2 a day, F10 "honest hatches"); global kill switch `Ctrl+Opt+Cmd+Esc` (F13). Watchdog closes the panel after **90 s** no matter what.
- **Meeting starts while it is on screen**: `IntrusionCoordinator` keeps every signal stream subscribed for as long as any surface is visible; any defer signal closes the panel **within 1 s**, outcome `deferredMidway`, no cost, any penalty already applied in this batch refunded, the unanswered items go back to the queue (F14).
- Window: level `.screenSaver`, `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`, `.nonactivatingPanel`, `canBecomeKey = true`, activation policy `.accessory`; after showing, check `isKeyWindow` at 300 ms and show "click to type" if activation was refused [05 §1.1-1.3]. Never `CGShieldingWindowLevel`, never `presentationOptions` disable flags [05 §3]. **Poster mode leaves the top-right notification area uncovered** (a 400 × 160 pt band below the menu bar on the screen with the menu bar), so an incoming-call banner stays visible above a `.screenSaver` panel [unverified whether banners draw above that level; the cut-out makes it irrelevant].
- Not over a full-screen meeting app: guaranteed by F14 (a call app with mic, camera or call audio ⇒ defer).

**Evidence.** Retrieval + spacing are the top-rated techniques ([Dunlosky 2013 via APS](https://www.psychologicalscience.org/news/releases/which-study-strategies-make-the-grade.html), [07 §1]); display alone is not retrieval [07 §2.11, gap 1]; immediate feedback for delay aversion (d = 0.43, [Jackson & MacKillop 2016](https://doi.org/10.1016/j.bpsc.2016.01.007), [01 §2.2]); response cost is the best-supported penalty form, evidence mixed [01 §2.9].

### F2. Unlock gate: post-unlock full-screen writing/recall gate with a safe escape (M7)

**What it is.** A full-screen `GatePanel` (same window recipe as F1, but `canBecomeKey` and activated) shown after unlock/wake. It is not a security boundary and never touches the login window; an Authorization Plugin is ruled out [05 §2, DECISIONS rule 1]. Off by default.

**Mechanics.**
- Trigger: `NSWorkspace.screensDidWakeNotification`, `sessionDidBecomeActiveNotification` and distributed `com.apple.screenIsUnlocked` (undocumented, [unverified] on Tahoe), merged and debounced 1.5 s, then confirm not locked via `CGSessionCopyCurrentDictionary` [05 §2]. Fires only if the Mac was locked/asleep ≥30 min, max 3 gates a day, ≥2 h apart; the first unlock of the day always qualifies.
- Content: Tena + a prompt about the learner's life (rotating templates: plan for today, yesterday, a work problem, an opinion), generated offline in batches by Claude with a canned fallback list of 60 prompts in `Content/prompts/gate.json`. Requirement: 25-40 words, English, and 1 target chunk (a twice-failed card from F1 if any, otherwise a due P-card chunk).
- Local gate checks run instantly (no network): word count; `NLLanguageRecognizer` says English with confidence ≥0.8; paste is blocked (custom `NSTextView` overriding `paste`, drag, services, Cmd-V [05 §6]); system AI and correction are off in the field (Writing Tools, inline predictions, autocorrect, spell/grammar check, completion, substitutions; same `AnswerField` settings as F1); the target chunk appears (lemma-tolerant); lexical-variety floor (type-token ratio ≥0.5). When all pass, the UNLOCK button fills orange; Return opens the Mac with a tier-L stamp. The same 600 ms inert window as F1 applies after the gate appears.
- Claude grading (F6) runs **after** the gate closes; feedback arrives as a toast and in the session view; errors feed the ledger. The gate never waits on Claude (DECISIONS rule 4).
- **"Joining a call" button** on the gate itself, always visible, free: closes the gate at once, defers gates for 60 min, outcome `deferredMeeting` (counts as a corroborated "I'm in a meeting" when any signal agrees within 10 min, F10 honest hatches). If any meeting signal (mic/camera/call audio attributed to a call app, calendar event, Focus) appears while the gate is open, the gate closes **within 1 s** for free, outcome `deferredMidway`, any cost already charged is refunded, and the prompt is re-offered at the next qualifying unlock. Like poster mode, the gate leaves the top-right notification band uncovered so an incoming-call banner stays visible.
- Escape: "Emergency skip" (Esc twice) → plain confirmation showing the cost (-20 Vitality, or -10 and 1 Mercy token, when Response cost is on) → closes. Max on-screen **5 min**, then Tena says "we'll finish later" and the gate closes with one of two outcomes: **`timeoutIdle`** (no keystroke in the gate and the user idle for the whole 5 min: the learner unlocked and walked away) is **free** and the gate is re-offered at the next qualifying unlock (still max 3 a day); **`timeoutAbandoned`** (the learner typed into the gate, then switched to another app over it) costs -10 Vitality when Response cost is on and counts toward the daily cap. Kill switch always works.
- Strict mode (opt-in, F10): the skip button appears only after a 10 s countdown; still never blocks the kill switch, defaults switch, file flag or watchdog [05 §11, Stretchly strict mode].

**Evidence.** Pushed output with noticing [03 §2]; short production bursts, long paragraphs optional [01 R23]; gate is a speed bump, the consequence design carries the commitment [05 §2]; escape ladders copied from LookAway/Stretchly [05 §11].

### F3. FSRS vocabulary engine and card types (M2)

**Model.** FSRS-6 with 21 default weights `[0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722, 0.1666, 0.796, 1.4835, 0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425, 0.0912, 0.0658, 0.1542]`, retrievability `R = (1 + factor·t/S)^(-w20)`, `factor = 0.9^(-1/w20) - 1` ([FSRS wiki](https://github.com/open-spaced-repetition/awesome-fsrs/wiki/The-Algorithm), [03 §4.1]). Port the update formulas from the earlier prototype's verified Kotlin implementation and re-check them against py-fsrs.
- **Learning steps**: new cards `[1 min, 10 min]`, relearning `[10 min]`, with py-fsrs 6.3.2 semantics (new card: Again 1 min, Hard 5.5 min, Good 10 min, Easy 8 d).
- **Rounding**: intervals use `.rounded(.toNearestOrEven)` to match Python `round`; a test vector lands on .5.
- **Fixtures**: `Tests/TenazCoreTests/Fixtures/fsrs_long_term.json` (the 6-step table in: S 2.3065 → 7.51332 → 26.407944 → 2.202716 → 4.863953 → 15.461535, intervals 2, 8, 26, 2, 5, 15) and `fsrs_with_steps.json`, generated by `scripts/fsrs-fixtures.py` run with `uv run --with 'fsrs==6.3.2'`, `enable_fuzzing=False`. Fuzz off in tests, ±5% on in the app [03 §11.1].
- **Desired retention**: 0.90 default, 0.93 for `mustKnow` meeting chunks, 0.85 for cognates [03 §11.1].
- **Load control**: **new notes** 5 a day (about 35 a week, [03 §5]): introducing a note spends 1 from the budget and unlocks its first card (L for chunks, R for single words); its sibling cards unlock later (C/K when the first card reaches S ≥3 d, P per the rule below) **without spending budget**, and siblings stay buried per the rules below; at most 1 new card per 4 reviews; daily review cap 120; suspend new cards while due > 80; the UI never shows a big due number, only "today's set" [03 §11.1, 07 gap 7].
- Leech at 6 lapses: flag, offer a Claude-made mnemonic / Spanish false-friend note / split.
- Review log from day 1 (everything an optimizer needs): card, timestamp, rating, state before/after, S/D before/after, elapsed and scheduled days, `durationMs`, `inputMode`, `surface`, `appFocusOk` [03 §4.3, §11.1]. Parameter optimization is backlog (after ~1,000 reviews).

**Notes and card types.** A *note* is a word or chunk; each note produces up to six independently scheduled cards [03 §11.1]:

| Type | Prompt | Answer | Auto-grade (no self-rating on production) |
|---|---|---|---|
| R recognition | English chunk | 4-option Spanish gloss / usage sentence | wrong = Again; right <6 s Good; 6-12 s Hard; no Easy |
| C cloze | sentence with blank | typed | exact after normalization = Good; accepted variant = Good; edit distance 1 on words ≥6 letters = Hard; else Again |
| L recall | Spanish cue or situation | typed English chunk | as C |
| K collocation | "make/do/take ___ a decision", preposition slot | typed or MC | as C |
| P production | situation ("Ask a colleague to review your PR") | typed sentence using the chunk | Claude rubric (F6): correct and natural = Good, minor errors = Hard, absent/wrong = Again; queued if Claude is down |
| S spelling/sound | TTS audio | typed / spoken | Levenshtein; STT match (intelligibility only) |

Rules: P unlocks only after the note's C or L card reaches stability ≥7 d; no two cards of one note on the same day; never more than 3 consecutive cards of the same type or topic [03 §3, §11.1].

**Seed content (built, Tenaz-original JSON, no licence issues)**: `Content/vocab/*.json`, 740 notes in 12 files (core B1+, B2 academic, C1, collocations/intensifiers, idioms, 50 false friends, linkers, phrasal verbs, prepositions, tech English, verb patterns, 70 workplace/meeting chunks), format in `Content/FORMAT.md`. M2 adds `Content/vocab/error-patterns.json` with the 12 common Spanish-L1 error patterns as K/C/P notes with the learner's own wrong form as the distractor. Open datasets come in M13.

### F4. Exercises (M3, M8, M12a, M12b, M13)

Built from the catalog in [03 §11.2]. Scoring: A = automatic in Swift, C = Claude via CLI.

| Exercise | Surface | Scoring | Milestone |
|---|---|---|---|
| E1 big-word flash, E2 typed recall, E3 cloze, E4 collocation, E5 false-friend duel, E6 preposition/article gap-fill, E7 error spotting | overlay, session | A | M3 |
| E8 sentence with target chunk, E9 unlock paragraph, E12 rewrite after feedback, E13 prompt-first correction loop, E19 summary writing, E22 capture from life | gate, session | A gate + C | M8 |
| E18 meeting role-play (Claude plays a colleague, 4-5 turns, typed first) | session | C | M8 |
| E10 reading with questions, E21 next-day retell | session | A + C | M13 |
| E11 dictation (TTS + typed), E16 minimal pairs (listen and pick) | session | A | M12a |
| E17 say-it test, E14 4/3/2 speaking, E15 shadowing, E20 elicited imitation, IELTS-style Part 2 cue card (spoken) | session | A (STT metrics) + C | M12b |
| E23 exam tasks | Exam Mode | A + C | M10-M12b |

Prompt-first feedback (the corrective-feedback finding: prompts beat recasts, [Lyster & Saito 2010](https://escholarship.mcgill.ca/downloads/6w924g64b), 15 studies, N = 827 [03 §6]): pass 1 highlights the span and names the category ("preposition?") and lets the learner fix it; pass 2 (after the learner's try or 60 s) shows the recast + a one-line rule. At most 3 error categories shown per text; the rest go silently to the ledger. Each repeated error spawns a K or C card with their own mistake as the distractor, and 24-48 h later a new task reuses the structure [03 §6].

Fluency track (learners' fluency typically runs ahead of accuracy): 4/3/2 on the same prompt at 90/60/40 s with WPM, pause count, filler "like" rate, repetitions, TTR from the transcript; the score is improvement from run 1 to run 3 plus a transfer run the next day [03 §7]. Fallback if SpeechTranscriber word timing is unreliable: WPM from total duration and word count [03 Gaps].

### F5. Exams with anti-cheat (M10, M11a, M11b, M12a, M12b)

**Types** [04 §6.1]. No sitting is longer than about 25 minutes unless the learner chooses "one sitting" (R2/R6: tiny, fixed tasks [01]).

| Exam | Cadence | Length | Content | Moves |
|---|---|---|---|---|
| Prior (day 1) | onboarding, no test | 0 min | the initial level estimate estimate: theta -0.3 (B1+) per skill, SD 1.0 | provisional stage 3 (F8) |
| Placement | first 7 days, one **5-min probe a day** inside the Daily Check slot | 5 × 5 min (+ optional 2-3 min dictated monologue, typed 150 words if no mic) | day 1-2 vocabulary-size probe (VST design, own items, [04 §5.1]); day 3 mini reading; day 4 mini listening; day 5 grammar & vocabulary; days 6-7 fill the widest-SD skill | initial theta per skill; confirms or corrects the provisional stage 3 (never removes it, F8) |
| Daily Check | daily, optional, counts toward a quest | 4-7 min, 12-20 items, stops when SD(theta) < 0.35 | Complete the Words, Choose a Response (text), Build a Sentence, grammar cloze, 1 Listen & Repeat (if mic) | private theta (weight 0.5), trend arrow |
| Weekly Mock | **3 sections of ~12 min on any 3 days Thursday-Sunday** (or one 35-40 min sitting), each its own Exam Mode attempt sharing a `mockGroupId` | 3 × 12 min | (1) router + 1 module Reading + 1 Build-a-Sentence set; (2) router + 1 module Listening + 1 Build-a-Sentence set; (3) Write an Email (10 min) **or**, alternating weeks, an **IELTS-style Speaking Part 2 cue card** (1 min preparation, up to 2 min long turn, 1-2 follow-ups; [IELTS](https://ielts.org/take-a-test/test-types/ielts-academic-test/ielts-academic-format-speaking)) + 30 s retell; typed long turn if no mic | private theta (weight 1.0; a group with <3 sections counts per section), error deck |
| Monthly Full Mock | every 4 weeks, **section by section within a 72-hour window**, each section its own Exam Mode attempt in one `mockGroupId` | ~90 min total in 4-5 sections | TOEFL 2026 structure: Reading 18-21, Listening 25-29, Writing 23, Speaking 8 min; + an **IELTS-style Writing Task 2** opinion essay as its own section (≥250 words, 40 min, [IELTS](https://ielts.org/take-a-test/test-types/ielts-academic-test/ielts-academic-format-writing)); + optional 10-min Grammar & Vocabulary block | **public band**, promotion, evolution; promotion needs **every section CLEAN** (or confirmed WARNING) inside the 72 h window |

Task types from IELTS (Part 2 cue cards, Task 2 essays) are items in `Content/items/` (`speaking.json`, `writing-prompts.json`) tagged `exam: "ielts-style"`, graded with the same F6 rubric. Tenaz says "IELTS-style", never "IELTS".

TOEFL 2026 facts used: Reading and Listening are two-stage adaptive (router, then lower/upper module), Writing and Speaking linear; 120 items; AI-scored items max 5 points; total 1 h 23 to 1 h 29 ([ETS blueprint](https://www.ets.org/content/dam/ets-india/pdfs/toefl/toefl-ibt-test-specifications-2026.pdf), [04 §1.1, Verification 1-2]). Tenaz says "TOEFL-style", never "TOEFL".

**Items.** A bank in SQLite. Objective items are scored locally and deterministically [04 §4.3]: exact/set match; Complete the Words exact on missing letters; Build a Sentence against 1-3 stored accepted orders; Listen & Repeat by word error rate mapped to 0-5 (0% = 5, ≤10% = 4, ≤20% = 3, ≤35% = 2, ≤50% = 1, thresholds [unverified, calibrate]). Sources: a starter bank written into `Content/items/*.json` during M10 (tagged `source: "tenaz-original, unreviewed"`), and later batches from `scripts/generate-items` (Claude CLI, offline, never during an exam) with Swift validators: schema, exactly one key, distractor length parity, stimulus words at or below target band, second-call CEFR check (discard if >1 level apart) [04 §6.3]. About 60 hand-checked anchor items (10 per level) keep the scale stable [04 §4.2].

**Getting harder over time** [04 §6.6]: each public band rise shifts the target mix up 0.25 band; texts move from FK grade 7-9 toward 11+; TTS rate rises; writing moves from personal emails to workplace emails with tone constraints, then academic discussion with a counter-argument; mediation tasks at B2+.

**Exam Mode** (Tenaz-side prevention, no Tivra needed) [04 §7, 05 §6, 06 §4.1]:
1. Pre-commitment screen: "I will not use AI, translators or notes. During exams only Tenaz may be in front." Preflight shows Tivra witness status (healthy / not watching → "this exam will be unranked"), never blocks. Preflight also reads Tivra's `sessions` table (read-only) and, if a protection session is active, warns "A Tivra protection session is active and will close Tenaz. Your answers are saved as you go." (Tivra exempts only `com.chere3.focusflow*`, [06 §0 item 4]).
2. Full-screen `ExamPanel` (window recipe from F1, activated). No presentation-option disable flags.
3. Paste and drag blocked in every answer field, and the system AI is off in it (Writing Tools, inline predictions, autocorrect, spell/grammar check, completion, substitutions; F1 `AnswerField`); `NSPasteboard.general.changeCount` polled at 2 Hz (change = flag); keystroke telemetry (insertions >8 chars that are not IME, WPM >150 with zero backspaces = flag, thresholds [unverified]).
4. **Allowlist, not deny-list.** During a section the only allowed frontmost app is Tenaz, plus a small system set that cannot answer questions (`com.apple.loginwindow`, `com.apple.notificationcenterui`, `com.apple.controlcenter`, `com.apple.UserNotificationCenter`, Tivra `com.chere3.focusflow*`). Frontmost-app timeline via `didActivateApplicationNotification`: any other app (terminal, browser, Raycast, Spotlight, dictionary, AI app, anything new) is hidden at once (`NSRunningApplication.hide()`), Tenaz comes back to the front, and an `integrity_event` is logged; frontmost **1-3 s ⇒ WARNING, ≥3 s (cumulative per section) ⇒ VIOLATION**. A **call app with a hard meeting signal** (F14) is not hidden or flagged: the exam pauses instead (step 5). Tenaz never terminates other apps [06 §4.1]. Background `claude`/`codex` processes (found with `NSWorkspace.runningApplications` + `ps -axo comm`) are logged as `aiProcessRunning` for the results timeline only, not as a violation: the learner often has Claude Code sessions running for other projects, and a background process cannot see the exam unless it comes to the front.
5. Meeting signal (F14 hard signal) ⇒ the exam **pauses** (timer stops, not flagged) until it clears; a meeting in the calendar now ⇒ the exam does not start.
6. **Crash- and quit-safe.** Each `exam_response` row is written as soon as the item is answered. If Tenaz is terminated (Tivra protection session, crash, force quit) and relaunched **within 15 min**, the attempt resumes at the next unanswered item, the gap goes into `pausedMs`, and the attempt is marked `integrity: interruptedByTivra` when a Tivra session was active at that time (otherwise `interrupted`); interrupted is not void and is judged by the normal verdict. After 15 min it closes as `abandoned` (practice stats only).
7. Abort: hold Esc 3 s → confirm → attempt void (0 for promotion). Kill switch voids too. Section watchdog = section time + 10 min.
8. No feedback, no sounds and no penalties during the test; results screen only [11 §6.4].

**Integrity verdict** (Tivra witness, read-only, runs 90 s after the exam and again at +15 min for phone data; SQL in [06 §4.2]): capture health first (max gap between `capture_tick` events ≤150 s, `source_health` ok for `window_titles` and `browser_url.<browser>`, no `paused`/`excluded` spans) else `UNVERIFIABLE`; then deny-list matches in `activity_spans` and `tivra_events` (`app_active`, `window_focus`, `tab_active`) on `bundle_id` and domain; then non-Mac devices (`device_usage`). Verdict: `UNVERIFIABLE` > `VIOLATION` (any deny match ≥5 s in Tivra, or Tenaz-side: any non-allowlisted app frontmost ≥3 s, >3 flags) > `WARNING` (non-allowlisted app 1-3 s, short flashes, phone use) > `CLEAN`. Effects: CLEAN and WARNING count (WARNING asks the learner to confirm in the review screen); VIOLATION and UNVERIFIABLE are kept for personal review but excluded from promotion, XP, streak and achievements; Tena looks worried, not dead [04 §7.2].

Honest UI copy: "Tenaz can catch common AI shortcuts. It can't prove you didn't use another device." [04 §7.2.9].

### F6. Writing and speaking grading through the `claude` CLI, with a rubric (M8)

**Bridge**: section 4.6. **Routing**: gate paragraphs, P cards, role-plays, exam writing/speaking transcripts. Never during an exam attempt, always after submit.

**Rubric** (one call per criterion for mock exams; one combined call for daily items) [04 §5.2, §3.3, 03 §11.2]:
- Writing criteria, each 0-5: task fulfilment (answers the prompt, register), organization and cohesion, grammatical range and accuracy, lexical range and precision. Speaking (on the transcript + local fluency metrics): delivery/fluency, language use, topic development; intelligibility is capped by ASR confidence and labelled "estimate".
- Anchors: the CEFR B1/B2/C1 descriptor table in [04 §2] (paraphrased; [unverified] against the CoE PDF), plus 2 anchor responses per band once the anchor set exists.
- Input to Claude: learner level (band), task prompt, response, local surface metrics (word count, TTR, mean sentence length, connector inventory, repeated-word rate; [04 §3.1]), the allowed error-category list (Spanish-L1 categories from [03 §8] and ).
- Output JSON (enforced with `--json-schema`): `{criteria: [{name, score, evidence_quotes[], cefr}], grade: 1-4, errors: [{span, category, correction, rule_short}], chunks_used: [], feedback_line}`.
- Reliability: a single LLM call is not a calibrated rater; human-LLM agreement is moderate to good (QWK mostly 0.30-0.80, [arXiv 2512.14561](https://arxiv.org/abs/2512.14561)); per-criterion scoring and calibration examples help ([arXiv 2502.11368](https://arxiv.org/pdf/2502.11368), [Yancey et al. BEA 2023](https://aclanthology.org/2023.bea-1.49)) [04 §3.3]. So: monthly mock = 3 runs, median per criterion, re-run twice if the range is >1 point and flag low confidence; monthly re-grade of the anchor set (30 writing + 20 speaking samples), drift MAE >0.5 freezes promotion; monthly pairwise check "which of these two answers is stronger" (new vs last month) as the progress signal; a "this correction is wrong" button that logs disagreement [04 §6.4]. One Claude grade alone can never demote anything (nothing demotes anyway, F7).
- Fallback when Claude is unavailable: queue the job; production cards stay "pending" and do not count as failures; gate XP uses length + variety floors [02 §3.2].

### F7. Level estimation and promotion (M10, M12a)

- Per skill (reading, listening, writing, speaking, grammar-vocab): a Rasch (1PL) posterior on an 81-point theta grid from -4 to 4 (`AbilityEstimator`), prior N(-0.3, 1) (B1+, from the initial level estimate) on day 1, updated by each placement probe; EAP estimate and SD; objective items with guessing floor c = 1/options [04 §4.1-4.2].
- Item difficulty prior from CEFR tag (A1 -2.5, A2 -1.5, B1 -0.5, B2 +0.5, C1 +1.5, C2 +2.5) + word-band and readability adjustments [04 §4.2]. AI-scored tasks map 0-5 to theta evidence through a fixed table.
- Theta → band thresholds are **Tenaz thresholds, configurable** in `Content/config/bands.json` (defaults A2/B1 -1.0, B1/B2 0.0, B2/C1 +1.0, C1/C2 +2.0, half-bands interpolated). Labelled "Tenaz band, TOEFL-style". Replace with ETS's published theta cut points (Tables 4-5 of the score-scale report) when someone extracts them [04 Gaps]. Display "3.5 to 4.0", never rounded up [04 Gaps].
- **IELTS-equivalent band** shown beside the Tenaz band in smaller type, labelled "≈ IELTS 5.5 (approx.)". Mapping: ETS's own IELTS → TOEFL 1-6 concordance (Table B1 in the [ETS 2026 score-scale report](https://www.mx.ets.org/content/dam/ets-org/pdfs/toefl/score-scale-update-2026.pdf), copied in [04 §1.1 Table B]), inverted per skill and overall and stored in `Content/config/ielts-concordance.json`. Overall inverse: Tenaz 3.5 → IELTS 5.5, 4.0 → 6.0, 4.5 → 6.5, 5.0 → 7.0, 5.5 → 7.5, 6.0 → 8.0+; below 3.5 show "≤ 5.0". Where the inverse is ambiguous, show the **lower** IELTS band (never round up). Caveat in the info popover: IELTS-to-CEFR claims are more generous than TOEFL's (IELTS 5.5 is claimed B2 but is B1 by TOEFL, [04 §1.1]); the number is an estimate, not a score.
- **Public promotion** (e.g. 3.5 → 4.0) [04 §6.5]: P(theta > threshold) ≥ 0.80 on the two most recent Monthly Mocks, each complete within its 72-hour window with **every section** CLEAN or confirmed WARNING; no skill more than one band below the target; anchor drift check green; one Weekly Mock in the window agrees within 0.4.
- **No demotion** of the public band; a bad mock shows "plateau" and prescribes drills; two consecutive weekly mocks 0.5+ below a skill's last good level trigger a "rescue plan".
- Monthly re-assessment of the dictated 2-3 min sample, compared with the first-run sample the same way.
- Goals shown: next milestone 4.0 overall with no skill below 3.5; "meeting ready" = 4.5 overall with speaking ≥4.0 (product judgment, not an ETS claim) [04 §6.5].

### F8. Mascot Tena with growth stages (M4, M14)

Axolotl "Tena": regeneration is the punishment metaphor (injury heals with a repair task, never death) [02 §4.1]. Riso art: flat pink body, 3 pt indigo outline, orange gills, halftone belly [11 §7.1]. v1 = SwiftUI `Canvas` + `TimelineView` + `keyframeAnimator` rig (body, tail, gills, 2 eyes, brows, 6 mouth shapes), 12 mood poses, 30 fps, paused when not visible [11 §7.3].

**Stages** (never regress; gate = evidence AND time floor; numbers are defaults in `Content/config/stages.json`):

| # | Stage | Gate (all of) | Time floor |
|---|---|---|---|
| 0 | Egg | install | 0 |
| 1 | Hatchling | onboarding + level paragraph | 0 |
| 2 | Larva | first set of reviews done | 0 |
| 3 | Juvenile (baseline, B1+) | **provisional on day 1** from the initial level estimate prior (theta -0.3); the placement probes in week 1 confirm it or show "catching up" (Tena keeps the stage, stages never regress) | first qualified day |
| 4 | Sub-adult | 150 mastered notes; public band ≥4.0 | 4 weeks |
| 5 | Adult | 400 mastered; band ≥4.5; writing median ≥4.0; one meeting role-play ≥4 | 8 weeks |
| 6 | Elder (golden) | 800 mastered; band ≥5.0; writing median ≥4.5 | 10 weeks |
| 7 | Metamorph (rare land form) | 1,400 mastered; band ≥5.0 on two monthly mocks; writing median ≥5.0 | 12 weeks |

"Mastered" is counted **per note on its primary card** (L recall if the note has one, else C cloze): stability ≥21 d and the last 3 recalls correct [02 §4.2]. Siblings never count twice. At 5 new notes a day a note reaches S ≥21 d after about 3-4 successful reviews (2.3 → 7.5 → 26 d with Good ratings,), so 150 mastered is reachable in about 8-10 weeks; stage 4 then waits only on the band. The bundled bank has 740 notes, so stages 6-7 need the M13 datasets (noted in `stages.json`). Evolution ceremony: XL tier, max 20 s, Esc closes it.

**Micro-growth between stages** (never regresses, so Tena changes visibly every week or two): every **25 mastered notes** one step of size (+2%), gill length or a new belly spot (cycled), and at every qualified week (5 of 7 days) one more gill frond; a cosmetic unlock at **weeks 2, 4, 8 and 12** (R15 novelty schedule, F16). Defaults live in `stages.json` (`microGrowthEvery: 25`).

**Meters** (0-100): Vitality (start 80, floor 15; +2 per 5 due reviews done, up to the day's loss; Sick at ≤30) and Spirit (correct recall +2, wrong -3, writing +5, decays 6 a day without a session; Spirit is the mood meter) [02 §4.3]. **Vitality only drops through the F10 Response cost rule.** With Response cost off, a missed day changes only Tena's mood (hungry, then sad), with no Vitality or Scales loss. **Moods**: ecstatic, happy, focused, curious, neutral, hungry (due ≥10), nagging (overdue >24 h), sad (Spirit <30), sick/injured (Vitality ≤30, cosmetics hidden not lost), regenerating (repair task running), proud (after healing), asleep (night, quiet hours, meeting; never interrupts) [02 §4.3]. Disappointment is mild and lasts under 3 s; no shaming copy ("we go again", never "you failed") [01 R12].

Menu-bar glyph states by shape, not colour alone: normal, due dot, hungry mouth, bandage, closed eyes [11 §6.1].

### F9. XP, levels, achievements, quests, streak (M4, M9b)

- **XP only for verified retrieval and production**, never for opening the app [01 R13, 02 §1.2]: due review recalled `10 × (1.0 + 0.6·(D-1)/9)` (D = FSRS difficulty), failed then corrected in the same session +3, written sentence 15-40 by quality, exam section 100-300 by band, quest 50-150. Anti-farming: an item's XP halves after 2 repeats in a day [02 §3.2].
- **Level curve**: `xpToNext(L) = round(60 + 40·L^1.4)` (L1 100, L5 441, L10 1,065, L20 2,712; about 57,900 XP to level 30, ~4-5 months) [02 §3.3, Verification 10]. **Level never decreases.**
- **Scales** (one currency, ~1 per 10 XP): sinks are 12 launch cosmetics (identity items: meeting headset, hard hat, the Drosophila pet-of-the-pet); a missed day costs 20 Scales **only when the F10 Response cost rule is on**, floor 0; no real money [02 §3.4].
- **Mystery drop**: ~25% after a completed session, cosmetic only, odds shown in Settings [02 §3.2, 01 R14].
- **Achievements**: the 53 in [02 §5] as data (`Content/achievements.json`: id, name, type P/M/D/S/H, condition key, threshold, reward). Ship the ~30 computable by M9b; exam ones arrive with M10-M12b. Hidden ones show "???". Unlock banner max 4 s, no focus steal; XL only for rarity ≥ double [11 §6.6].
- **Daily quests** (3, generated at 04:00 from live data): Core "clear your due set" (min(due, 30)), Skill (rotates by weakest category in the ledger), Stretch (optional, risky, mystery drop). Weekly "meeting prep" 3-min spoken summary. Targets adapt: >85% success over 7 days ⇒ +10%; <50% ⇒ -15% [02 §6].
- **Streak**: qualified day = minimum viable day (section 1.2), done in-app; a day on which the kill switch or "Pause 1 h" was used qualifies **only if the minimum was done in-app that day** (no freeze can cover it; F10 honest hatches); day boundary 04:00; freezes per section 2 row 3; best streak kept forever; headline is "5 of the last 7 days" [01 R11]. After 3+ missed days the first prompt is "welcome back, 1-minute restart", penalties paused for that day [01 R26].
- First 7 days are generous (XP ×1.5, guaranteed growth beats) [02 §2.1].

### F10. Commitment-device punishments configured by the learner (M7 arm step, M9a contract)

The learner writes a **Contract** in a calm planning session (the "Arm Tenaz" step, then the Sunday review), never in the moment [01 R9]. Each rule is a toggle and **ships off** (DECISIONS rule 2), except the passive Vitality/Spirit display. The rule that fired is shown with "You chose this on <date>" [02 §1.2].

**Arm Tenaz** (the last onboarding step; built in M7 as a sheet reachable from onboarding, the popover and Settings, folded into the full onboarding in M9c). Shipping defaults stay off, but the app does not leave the core feature for the learner to find later in Settings (an ADHD user rarely goes back to switch it on). The step shows a **recommended preset**: sticker overlays 4 a day in week 1, poster mode from week 2; gate once a day (first unlock); and from M9a, Response cost on and Repair task on. It lists every escape hatch (kill-switch hotkey, `defaults` key, file flag, watchdogs, "I'm in a meeting", "Joining a call", Emergency skip) in plain words, requests Calendar access inline (or the explicit "mic/camera/app detection only" acknowledgement, F14), and arms only after the learner **types "I choose this"** (exact text, case-insensitive). "Not now" leaves everything off and re-offers the step once, on the next Sunday review. Nothing is enabled without that typed confirmation.

**Asymmetric change delay** (the commitment device slows loosening, not tightening) [01 R9]:
- **Tightening** (turn a rule on, raise a cost or cap, add a fun app, switch sticker → poster): takes effect at the **next 04:00 day boundary**.
- **Loosening** (turn a rule off, lower a cost, raise a free-hatch allowance, turn overlays/gate off from the Contract): takes effect **24 h later**, shown as a pending change with a countdown and a one-click cancel.
- **The kill switch, "Pause 1 h", quiet hours and every hatch in 5.2 stay instant** and are not Contract changes.

| Rule | Default | Effect | Clears by |
|---|---|---|---|
| Response cost | off (preset: on) | Vitality/Scales per the cost table below | doing due reviews |
| Repair task | off (preset: on) | at Sick (Vitality ≤30): 15 no-hint reviews + a 60-word paragraph; each part regrows a limb | finishing it (≤5 min) |
| Forgotten word returns | on with overlays | twice-failed word becomes the gate's required chunk | using it correctly |
| Strict gate | off | skip button appears after 10 s | - |
| Extra cards | off | +5 review cards on a missed day (inside the daily cap) | reviewing them |
| Exam stake | off | a failed or VIOLATION mock schedules a retake in 48 h and -15 Vitality [01 R21] | the retake |
| **Fun-app speed bump** | off | after a deadline the learner picks (default 20:00), if today's minimum is not done and a fun app is frontmost, the 3-item **sticker** overlay appears over it; it returns at most every 10 min until the minimum is done; it never hides or quits the app, never fires on any meeting signal, counts as an intrusion inside the daily caps (8 a day, quiet hours) | doing today's minimum |
| Tivra fun-app block | **disabled, "needs Tivra patch P1"** | proposal only (section 4.7); the speed bump above is the read-only version available now | - |

Fun apps live in `Content/funapps.json`: seeded from Tivra's read-only `social` classification rules (read through `TivraReader`, bundle ids only) plus these seed bundle ids: Discord `com.hnc.Discord`, Steam `com.valvesoftware.steam`, Spotify `com.spotify.client`, WhatsApp `net.whatsapp.WhatsApp`, Telegram `ru.keepcoder.Telegram` (Minecraft launcher `com.mojang.minecraftlauncher` [unverified]). M9a resolves each with `NSWorkspace.urlForApplication(withBundleIdentifier:)` and drops missing ones. Browsers are not fun apps (too broad); YouTube in a browser is covered only when Tivra's latest `window_focus`/`tab_active` domain for the frontmost browser window is `youtube.com` (read-only, checked at most once a minute) [06 §1.1].

**Cost table** (all inside Response cost; nothing here applies while it is off): overlay skip -3 Vitality; gate emergency skip -20 (-10 with a Mercy token, 3 a month, never required); gate `timeoutAbandoned` -10 (`timeoutIdle` is free, F2); missed daily minimum -10 Vitality and -20 Scales; uncorroborated "I'm in a meeting" beyond the free allowance -3 (see below). **Soft freeze**: after **2 missed days in a row** the drain stops (no further Vitality or Scales loss) until the learner comes back, and the welcome-back day restores +10 Vitality and pauses penalties for that day [01 R26]. **Caps**: -30 Vitality a day; penalty tasks ≤5 min a day; after 3 penalty events in a day ⇒ recovery mode (easier items, no more penalties today) [01 R10]. Level, mastered words and access to the Mac are never touched [02 §4.4].

**Honest hatches** (every hatch stays instant and always works, section 5.2; they are counted, not blocked):
- **"I'm in a meeting" / "Joining a call"** is free when **corroborated**: any meeting signal (mic, camera or call audio from a call app, a calendar event within ±15 min, a call app frontmost) at the moment of the click or within the next 10 min (a later corroboration refunds the cost). Uncorroborated claims are also free **2 times a day**. After that it still works at once, is logged `meetingClaimUncorroborated`, and counts as a skip (-3 Vitality only if Response cost is on **and** a work calendar is configured and visible, F14; with no visible work calendar corroboration is impossible, so it stays free and is only counted).
- **Kill switch and "Pause 1 h"** stay penalty-free, but that day qualifies for the streak only if the minimum is done in-app (F9). **2 or more kill-switch uses in a week** trigger a contract-renegotiation prompt in the next Sunday review ("the kill switch fired 3 times; which rule was too much?"), never a penalty.
- The weekly review (F16) shows the count of every hatch by kind.

Local experiment log per rule (fired, dismissed, escaped, led to a session within 30 min). The weekly review suggests turning off any rule whose escape rate is >60% for 2 weeks [02 §8, 01 R24]. Commitment-device evidence is thin (Ariely & Wertenbroch retracted; Giné et al. 2010 is modest, [AEJ Applied](https://doi.org/10.1257/app.2.4.213)), so this log is the real safeguard [01 Gaps].

### F11. Recommendations: books, podcasts, knowledge (M13)

- **Two-lane reading** [08 §0]: lane A graded readers at ≥98% coverage for fluency; lane B authentic tech/science books at ~95% with a dictionary tap; only one lane B book at a time.
- **Coverage service**: `NLTokenizer` + `NLTagger(.lemma)`, proper nouns counted as known, compared with the learner's known set (FSRS notes with R ≥0.9 + a bulk-markable tech seed list + placement) [08 §1.1, §8, Gaps]. Bands: <90% frustration, 90-95% with help, 95-98% stretch, ≥98% fluency. Lemma counts read lower than family-based literature figures; calibrate [08 Gaps].
- **Catalog**: `Content/catalog.json` with the 37 titles in [08 §2] and the podcast/YouTube ladder in [08 §3], all levels `[est]` until the learner's coverage tool measures them. Metadata only, no book text bundled. The learner can add an ePub/plain text the learner owns; text stays local.
- **Scoring**: `score = 0.35 fit + 0.25 interest + 0.15 novelty + 0.15 goal + 0.10 momentum - penalties` with the definitions in [08 §6.3]; show 1 primary + 2 alternates with a one-line "why" and finish time in days [08 §6.5].
- **Knowledge cards ("Brain bite")**: ~30 at launch, 120-200 words at B1+/B2 on TECH/AI/PSY/NEURO/STARTUP, each tagged with 3 target notes, a "use this word about your work" question, and a "go deeper" link to a catalog item. Written offline by `scripts/generate-knowledge` (Claude CLI), marked "check source", rejected if >5% words outside level+1 [08 §7].
- Reading log: minutes, words, wpm, 3-question comprehension; wpm counts only with comprehension ≥70% [08 §1.2].

### F12. Menu bar presence (M1, M4, M6, M14)

`MenuBarExtra` in M1-M5 (built); from M6 an `NSStatusItem` + `NSPopover` hosting the same SwiftUI view (ruling 13), so the app can open the popover and pulse the icon. Popover per the wireframe in [11 §6.1]: Tena + stage + streak, Vitality/Spirit bars, the one primary button ("Review 12 words", Return), text buttons (Write, Exam, Quests), and the safety row: **Pause intrusions 1 h**, Quiet hours, Open Tenaz. Activation policy `.accessory`; switches to `.regular` while the main window is open [05 §1.2, 10 §11]. The icon is the Tena glyph with state shapes (F8) and a small due count.

### F13. Settings with kill switches (M5, M14)

Settings (SwiftUI `Settings` scene + reachable from the popover, never only from the main window [10 rule 32]). Sections: Intrusions (overlay on/off, mode, caps, quiet hours, triggers, "Arm Tenaz" re-entry), Meetings (which calendars count as work, manual meeting hours, optional ICS URL, call/chat app lists, mic-holder allowlist; F14), Gate (on/off, size, strict), Contract (F10), Exams (days, Tivra witness on/off), Claude (enabled, model alias, test connection), Sound (on, volume, "calm celebrations"), Data (export JSON, backups), Credits & licences, Safety (shows every kill switch and how to use it). Kill switches in section 5.2.

### F14. Meeting / DND awareness: never interrupt a work meeting (M5)

`InterruptionPolicy` (pure decision logic in `Sources/TenazCore/Safety/InterruptionPolicy.swift`, signal probes in `Tenaz/Services/Safety/SignalProbes.swift`) returns **`.allow(maxMode: .poster | .sticker)`**, **`.deferred(until:reason:)`** or **`.deny(reason)`** (M5 extends today's `.allow/.deferred(reason:)`). **Any provider error ⇒ defer** [05 §4], except the mic process list, which falls back to the device-level check.

**Signals are attributed.** `InterruptionSignals` changes from one `Bool?` per signal to holders: `micHolders: [String]?` and `audioOutHolders: [String]?` (bundle ids), `cameraInUse: Bool?` (CMIO cannot attribute), `frontmostBundleId: String?`, `assertionHolders: [String]?`, `calendarEventNow: Bool?`, `meetingHoursNow: Bool`, `focusOn: Bool?`, `idleSeconds: Double?`, `locked: Bool?`. The policy classifies holders with `Content/meeting-apps.json`:

```json
{ "callApps": ["us.zoom.xos", "com.microsoft.teams2", "com.apple.FaceTime", "com.tinyspeck.slackmacgap",
               "Cisco-Systems.Spark", "com.hnc.Discord", "net.whatsapp.WhatsApp"],
  "chatApps": ["com.microsoft.teams2", "com.tinyspeck.slackmacgap", "com.hnc.Discord",
               "net.whatsapp.WhatsApp", "ru.keepcoder.Telegram"],
  "presentationApps": ["com.apple.iWork.Keynote", "com.microsoft.Powerpoint", "us.zoom.xos"],
  "browsers": ["com.apple.Safari", "com.google.Chrome"],
  "ignoreMicHolders": ["com.chere3.tenaz", "com.chere3.tenaz.dev"],
  "ignoreAudioOutHolders": [] }
```
(Teams `com.microsoft.teams2`, Zoom `us.zoom.xos` and PowerPoint `com.microsoft.Powerpoint` are the vendors' published bundle ids; Slack, Webex `Cisco-Systems.Spark` and Keynote ids are [unverified]; re-check every id against the app's Info.plist at install time; the bundle ids of other local voice assistants can be added to `ignoreMicHolders` in M5.)

| Signal | API | Class | Effect |
|---|---|---|---|
| Mic input, **per process** | enumerate `kAudioHardwarePropertyProcessObjectList`; for each process object read `kAudioProcessPropertyIsRunningInput` and `kAudioProcessPropertyBundleID` (both in the MacOSX26 SDK `AudioHardware.h`, [Apple](https://developer.apple.com/documentation/coreaudio/kaudioprocesspropertyisrunninginput)). If the list call errors, fall back to `kAudioDevicePropertyDeviceIsRunningSomewhere` on the default input (unattributed ⇒ hard) | hard, unless every holder is in `ignoreMicHolders` | defer. A holder that is in no list counts (fail-safe); Settings shows "Mic held by <app> — this isn't a call" to add it to `ignoreMicHolders` in one click. Best effort: may miss some Bluetooth mics [11 Verification 9] |
| Call audio out, per process | same list, `kAudioProcessPropertyIsRunningOutput` | hard when a **callApp** holds an output stream ≥10 s continuously | defer (catches a muted call with no mic stream). If M5's probe shows a call app holding output while idle (no call), the learner adds it to `ignoreAudioOutHolders` |
| Camera in use | CoreMediaIO `kCMIODevicePropertyDeviceIsRunningSomewhere` over `kCMIOHardwarePropertyDevices` | hard | defer |
| Display-sleep assertion, **per holder** | `IOPMCopyAssertionsByProcess` (`PreventUserIdleDisplaySleep`/`NoDisplaySleep`, skipping `useractivity`), pid → bundle id via `NSRunningApplication(processIdentifier:)` | hard if the holder is a presentationApp or callApp, or a browser that also holds mic/camera; otherwise **"media playing"** | hard ⇒ defer; media playing (a YouTube tab in a browser, Spotify video, `caffeinate -d`) ⇒ `.allow(maxMode: .sticker)` |
| Call/chat app frontmost, no hard signal | `NSWorkspace.frontmostApplication` | soft | `.allow(maxMode: .sticker)`: sticker only, no sound, no poster, no gate. Tenaz is not silenced for a whole workday just because Teams is open |
| Calendar event now | EventKit on the calendars marked **work** in Settings (default: all), non-all-day, not declined, overlapping now-5 min ... now+10 min; 10-min grace after it ends | hard | defer until end + grace |
| Manual meeting hours | Settings schedule (weekday ranges), used when no work calendar is visible | hard | defer |
| Focus on | `INFocusStatusCenter.default.focusStatus.isFocused` | hard | defer (option "Tenaz ignores Focus" for a Study Focus) |
| Screen locked / user idle >120 s | `CGSessionCopyCurrentDictionary`, `CGEventSource.secondsSinceLastEventType` | - | defer (queue, never stack); 120 s matches `maxIdleSeconds` in code: the learner must be at the desk to answer |
| Quiet hours, kill switch, pause | settings | - | deny |

**While a surface is visible.** `IntrusionCoordinator` subscribes to every signal stream (CoreAudio property listeners, CMIO listeners, `didActivateApplicationNotification`, `EKEventStoreChanged`, Focus, a 1 s assertion poll) for as long as any overlay, gate, sticker or exam is on screen, not only before showing. Any hard signal closes the overlay, sticker or gate **within 1 s**, logs outcome `deferredMidway`, costs nothing, refunds any penalty already applied by that surface, and puts its items back in the queue. An open exam pauses (F5). A newly frontmost call/chat app with no hard signal downgrades a poster to a sticker.

**Work meetings must be visible.** If the learner's work calendar is not synced to macOS Calendar, the calendar signal is empty and a muted meeting is invisible. So `--tenaz-probe-guard` and `guard-state.json` list every EventKit calendar with today's event count; Settings → Meetings lets the learner mark which calendars are work. If none is marked or none has events on a weekday, Tenaz shows **"Work meetings not visible"** in the popover and offers (a) a manual recurring **meeting-hours** schedule and (b) an optional **ICS subscription URL** (read-only HTTPS fetch every 15 min, parsed locally, never written back; network-dependent, so never part of an overnight acceptance).

Rules: **Overlays and the gate cannot be enabled until calendar access is granted**, or the learner explicitly acknowledges "mic/camera/app detection only" (a meeting without mic activity, e.g. listening muted, could otherwise be missed); with "Work meetings not visible", enabling also asks for meeting hours or the same acknowledgement. One-click "I'm in a meeting" defers 60 min (F10 honest hatches). Sound auto-mutes on any meeting signal [11 §5.5]. Every decision is logged to `intrusion_log` with the reason **and the holders** (`micHolders`, `audioOutHolders`, `assertionHolders`, `frontmostBundleId`), so a false positive or negative can be traced.

### F15. Error ledger and "capture from life" (M8)

Persistent `error_ledger` (category, example, correction, count, first/last seen) seeded with the suspect Spanish-L1 categories (articles, prepositions, verb patterns, present perfect, agreement, false friends, intensifier stacking, filler "like") [03 §8]. Capture from life (E22): the learner types or dictates 3 phrases the learner needed in a real meeting; Claude normalizes, flags L1 errors and creates notes. **Confidentiality**: a warning on the capture field ("don't paste work confidential text"); a per-entry "local only" switch that skips Claude [07 gap 2].

### F16. Instrumentation and the weekly review (M9c)

Local only: session start/skip/abandon, time to first answer, overlay dismiss/skip/kill rates, `deferredMidway`/`earlyInput`/`timeoutIdle` counts (false-positive and app-caused events), penalty events, escape-hatch use by kind, Claude failures [01 R24, 11 §9.7]. Sunday review (5 min, F10): consistency (days in last 7/30), **hatch counts** (kill switch, Pause 1 h, corroborated and uncorroborated meeting claims, emergency skips) with the renegotiation prompt when the kill switch fired 2+ times, mastered-notes growth, error categories trending, which rules worked, one new if-then plan stored as a cue ("If I unlock after lunch, then 3 words") [01 R4, R25], and every 2 weeks a 1-7 self-rated automaticity question [01 R16]. Scheduled novelty at weeks 2, 4, 8, 12 (new cosmetic set, quest template, exam section, seasonal palette) while the 20-second core loop stays the same [01 R15].

---

## 4. Architecture

### 4.1 Targets and dependencies

| Target | Kind | Isolation default | Depends on |
|---|---|---|---|
| `TenazCore` | SwiftPM library (root `Package.swift`), no SwiftUI/AppKit imports | nonisolated, Swift 6, upcoming features `NonisolatedNonsendingByDefault`, `InferIsolatedConformances` | GRDB 7.11.1+ |
| `TenazCoreTests` | Swift Testing | - | TenazCore |
| `Tenaz` | macOS app (XcodeGen `project.yml`) | `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_STRICT_CONCURRENCY = complete`, warnings as errors | TenazCore; KeyboardShortcuts 3.1.0 for the kill-switch hotkey, **added in M5, not M1** (fallback: Carbon `RegisterEventHotKey`, ~60 lines) |

No helper, XPC, widget or extension target in v1 [10 §3.1]. No dependency on `TivraCore` (Tivra pins GRDB 6.29, dirty checkout) [10 §7]. `project.yml` and `Package.swift` start from the build-verified skeleton in [10 §6], minus swift-fsrs (section 2 row 1), plus the KeyboardShortcuts package on the app target.

Identity: Debug `com.chere3.tenaz.dev` / `TenazDev.app` / Application Support folder `TenazDev`; Release `com.chere3.tenaz` / `Tenaz.app` / `Tenaz`. Team `<TEAMID>`, Automatic signing, Apple Development, hardened runtime, **not sandboxed**, `LSUIElement = true`, `LSApplicationCategoryType = public.app-category.education` [10 §0, §6]. Never build with `CODE_SIGNING_ALLOWED=NO` [10 §8].

Entitlements start empty and grow per milestone. Hardened runtime blocks a protected resource unless the matching entitlement is present (Tivra carries `calendars` for this reason [10 §2]):

| Milestone | Entitlement / Info.plist key | Note |
|---|---|---|
| M5 | `com.apple.security.personal-information.calendars` + `NSCalendarsFullAccessUsageDescription` | plain signed entitlement, no portal work |
| M5 | `NSFocusStatusUsageDescription`; Focus status may also need the App-ID capability `com.apple.developer.usernotifications.communication` [unverified on macOS] | **best effort**: if the capability is missing or authorization fails, the Focus provider reports `"unavailable"` and the guard relies on the other signals; enabling the capability is a morning item, never an overnight dependency |
| M12b | `com.apple.security.device.audio-input` + `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` | [05 §7] |
| none | camera/mic "is running somewhere" queries and the CoreAudio process-object list (`kAudioProcessPropertyIsRunningInput/Output`, `BundleID`) | they do not capture, so no camera or audio-input entitlement [unverified that the process list needs none on macOS 26; M5's probe proves it either way, and on error the device-level fallback applies] |

### 4.2 Folder layout

```
tenaz/
  CLAUDE.md DECISIONS.md docs/ (PLAN.md, research/, proposals/)
  Package.swift  project.yml  .swiftformat  .gitignore  .mcp.json
  scripts/        verify.sh  fsrs-fixtures.py  build-data.py  generate-items.py
                  generate-knowledge.py  install-tenaz.sh (never run overnight)
  Content/        FORMAT.md  vocab/*.json (740 notes)  items/*.json (436 items)  prompts/*.json  config/*.json
                  catalog.json  achievements.json  denylist.json  meeting-apps.json  funapps.json
  data/raw/       (gitignored downloads)   data/build/ (generated SQLite, committed)
  Sources/TenazCore/
    CEFRLevel.swift
    SRS/          FSRS.swift (built)  ReviewQueue.swift  AnswerMatcher.swift  CardType.swift
    Content/      ContentModels.swift  ContentValidator.swift (built)
    Persistence/  TenazDatabase.swift  Migrations.swift  Paths.swift (built)  Records/*.swift
    Learning/     ErrorLedger.swift  Coverage.swift  Rubric.swift
    Exams/        AbilityEstimator.swift (built: estimator + ObjectiveScorer)  Blueprint.swift  Promotion.swift  MockGroup.swift
    Gamification/ XP.swift  Streak.swift  Mascot.swift  Achievements.swift  Quests.swift  Penalties.swift  Contract.swift
    Safety/       InterruptionPolicy.swift (built; M5 adds attribution + modes)  Watchdog.swift  MeetingApps.swift  Hatches.swift
    Claude/       ClaudeCLI.swift (built)  ClaudeJobQueue.swift  Prompts/*.swift  Schemas/*.json
    Tivra/        TivraReader.swift  IntegrityVerifier.swift  DenyList.swift  ExamAllowlist.swift
    Design/       Palette.swift  Contrast.swift   (hex tokens + WCAG math, testable)
    Support/      Clock.swift  DayBoundary.swift
  Tests/TenazCoreTests/{Scheduling,Persistence,Safety,Gamification,Exams,Claude,Tivra,Design}/
    Fixtures/     fsrs_long_term.json  fsrs_with_steps.json  tivra_fixture.sql  claude_*.json
  Tenaz/
    App/          TenazApp.swift  MenuPopover.swift  AppEnvironment.swift  LaunchArguments.swift
                  Snapshot.swift  Smoke.swift  SelfTest.swift  SnapshotRegistry.swift (built)  StatusItem.swift (M6)
    Features/     Home/ Review/ Overlay/ Gate/ Exam/ Mascot/ Achievements/ Quests/
                  Contract/ Arm/ Library/ Onboarding/ WeeklyReview/ Settings/
    Services/     Safety/{KillSwitch,SignalProbes,OverlayPanel}.swift (built)  Safety/GuardHeartbeat.swift
                  ClaudeService.swift  TivraService.swift  SystemEvents.swift
                  Speech/*.swift  Sound/*.swift  LoginItem.swift  Notifications.swift
    Shared/DesignSystem/  Tokens.swift Typography.swift Motion.swift Components/*.swift
    Resources/    Info.plist  Tenaz.entitlements  Assets.xcassets  Fonts/  Sounds/  Data/
```

One type per file, folders by feature [10 rule 17].

### 4.3 Data model (GRDB migrations, one file `tenaz.sqlite`)

All timestamps are Unix milliseconds (`INTEGER`), days are `yyyymmdd` integers with a 04:00 boundary. Records are `Codable, Sendable` structs. Migrations are append-only, named `v1`, `v2`, ... Tables (migration in brackets):

| Table | Key columns | Milestone |
|---|---|---|
| `note` | id, kind (word/chunk/pattern/falseFriend), display, lemma, glossEs, exampleEn, exampleEs, cefr, freqRank, tags JSON, mustKnow, source, sourceRef, suspended | M2 |
| `card` | id, noteId, type (R/C/L/K/P/S), state (new/learning/review/relearning), step, due, stability, difficulty, reps, lapses, lastReview, desiredRetention, leech, buriedUntilDay | M2 |
| `review_log` | id, cardId, ts, rating, stateBefore, stateAfter, sBefore, sAfter, dBefore, dAfter, elapsedDays, scheduledDays, durationMs, inputMode, surface (overlay/gate/session/exam/notification), answerText, appFocusOk | M2 |
| `day_stat` | day, correctRetrievals, productions, qualified, frozen, minutesActive | M4 |
| `xp_event` / `scales_event` | id, ts, amount, source, refId | M4 |
| `mascot_state` (1 row) / `mascot_event` | stage, stageSince, vitality, spirit, cosmetics JSON / id, ts, kind, vitalityDelta, spiritDelta | M4 |
| `intrusion_log` | id, ts, surface, trigger, decision, reason, outcome (shown/deferred/deferredMidway/deferredMeeting/snoozed/skipped/completed/timeout/timeoutIdle/timeoutAbandoned/killed/meetingClaimUncorroborated/earlyInput), mode (poster/sticker), micHolders JSON, audioOutHolders JSON, assertionHolders JSON, frontmostBundleId, refundedCost, durationMs | M5 |
| `hatch_event` | id, ts, kind (killSwitch/pause1h/meetingClaim/joiningCall/snooze/emergencySkip), corroborated, cost, day | M5 (counts), M9a (costs) |
| `writing_entry` | id, ts, surface, promptId, prompt, text, wordCount, metrics JSON, localGate JSON, gradeStatus, gradeJSON, rubricVersion, localOnly | M7 |
| `claude_job` | id, kind, payload JSON, status (queued/running/done/failed), attempts, nextAttemptAt, createdAt, finishedAt, result JSON, error | M8 |
| `error_ledger` | id, category, example, correction, count, firstSeen, lastSeen, noteId | M8 |
| `penalty_rule` / `penalty_event` | id, kind, enabled, params JSON, createdAt, effectiveAt, direction (tighten/loosen), pendingCancelled / id, ruleId, ts, cost, task, cleared, clearedAt, refunded | M9a |
| `arm_record` | id, ts, preset JSON, typedConfirmation, accepted | M7 |
| `achievement` / `quest` | id, unlockedAt, progress / id, day, slot, template, target, progress, done | M9b |
| `if_then_plan` / `weekly_review` | id, cue, action, active / id, weekStart, answers JSON, automaticity, hatchCounts JSON | M9c |
| `item` | id, type, skill, cefrTarget, bPrior, bAdj, guess, stimulus JSON, key JSON, accepted JSON, tags, source, anchor, createdAt | M10 |
| `exam_attempt` / `exam_response` | id, kind, mockGroupId, section, startedAt, endedAt, status (running/paused/interrupted/abandoned/void/done), integrity (incl. `interruptedByTivra`), integrityJSON, pausedMs, resumedAt / id, attemptId, itemId, answer, correct, latencyMs, scoreRaw, scoreSource, answeredAt (**written per item as soon as answered**) | M10 |
| `grade_run` | id, targetKind, targetId, criterion, score, evidence JSON, model, runIndex, rubricVersion, calibrationVersion | M8 |
| `skill_state` / `band_history` | skill, posterior BLOB (81 doubles), thetaHat, sd, updatedAt / id, day, skill, band, low, high, verified | M10 |
| `integrity_event` | id, attemptId, ts, kind (app/paste/clipboard/burst/focusLoss/tivra/aiProcessRunning/interrupted), bundleId, durationMs, detail | M11a |
| `catalog_item` / `reading_log` / `knowledge_card` | per [08 §6.2] / id, itemId, ts, minutes, words, wpm, comprehension / id, title, body, cefr, topics, targetNoteIds, source | M13 |

Bundled read-only content databases (M13), kept as **separate files** so share-alike stays contained [08 Gaps]: `Resources/Data/content.sqlite` (Tenaz-original + CEFR-J + Tatoeba CC BY with per-sentence author), `Resources/Data/ngsl.sqlite` (CC BY-SA 4.0), `Resources/Data/wikdict-en-es.sqlite` (CC BY-SA 4.0). Each has a `source` table (name, url, version, licence, retrievedAt) that feeds Credits.

Settings live in `UserDefaults` (domain = bundle id), never in SQL [10 §4]. Nightly `VACUUM INTO` backup under Application Support, keeping 7 [10 §4]. Export/import JSON from Settings.

### 4.4 Persistence

GRDB 7: `DatabasePool` (WAL) in the app at `~/Library/Application Support/<Tenaz|TenazDev>/tenaz.sqlite`, in-memory `DatabaseQueue()` in tests [05 §10, 10 §4]. UI reads through `ValueObservation` → `AsyncSequence` consumed in a store's `.task` (no Combine) [10 §3.2].

### 4.5 Concurrency

Rules from [10 §3.3], binding:
- App target is MainActor by default; five `@Observable` stores built in `TenazApp` and injected with `@Entry` environment keys: `ReviewSession`, `ProgressStore`, `MascotStore`, `IntrusionCoordinator` (owns the kill switch and every panel), `SettingsStore`. No `ObservableObject`, `@Published`, `@AppStorage` inside `@Observable`.
- `TenazCore` = value types + actors: `ClaudeCLI` (built as a `Sendable` struct; M8 wraps its process launch in an actor if needed), `ClaudeJobQueue` (actor, one job at a time), `TivraReader` (actor), DB writes through the pool.
- Time via an injected `Clock` protocol (`Task.sleep(for:)`, never `DispatchQueue` or `Task.sleep(nanoseconds:)`); every policy with a timeout takes the clock so tests run instantly.
- System callbacks (NSWorkspace, distributed notifications, CoreAudio listeners, EventKit) become `AsyncStream`s at the edge.
- `Task.detached`, `@unchecked Sendable`, `nonisolated(unsafe)`, `@preconcurrency` need a written invariant [10 rules 5-6].

### 4.6 Claude CLI bridge

Verified with a recent CLI (2.1.x): a structured-output call returned `is_error: false`, `subtype: "success"`, a valid `structured_output`, `num_turns: 2`, in about 3 s. **`--max-turns 1` must not be used** (structured output takes 2 turns here, and `--max-turns` exits with an error when hit [05 Verification 10]).

```
executable  ~/.local/bin/claude   (fallback: resolve once via /bin/zsh -lc 'command -v claude', cache)
arguments   -p --output-format json --json-schema <schema-string>
            --tools "" --restricted --strict-mcp-config
            --no-session-persistence --permission-prompts none
            --model <settings, default "sonnet">
stdin       the prompt, written then closed
cwd         ~/Library/Application Support/<app>/claude-cwd   (empty folder: no CLAUDE.md, no project settings)
env         ProcessInfo env minus ANTHROPIC_API_KEY and ANTHROPIC_AUTH_TOKEN;
            PATH=$HOME/.local/bin:/opt/homebrew/bin:/usr/bin:/bin; NO_COLOR=1
never       --bare (needs an API key, breaks the subscription rule [05 Gaps])
timeout     90 s → SIGINT, then SIGTERM after 2 s; exit 143 and max-turn errors are handled outcomes, not retry storms
```

Flag semantics from `claude --help` with the reference toolchain: `--tools ""` disables all built-in tools; `--restricted` removes code-running tools and ignores user/project/local settings files; `--strict-mcp-config` with no `--mcp-config` loads no MCP servers; `--permission-prompts none` denies anything that would prompt; `--no-session-persistence` keeps grading calls out of `~/.claude` transcripts. `ClaudeCLI` parses the single JSON result, requires `structured_output` (absent means a failed run), then decodes it with `Codable` against the schema.

Health: at launch and every 6 h, `claude auth status --json` must report `authMethod == "claude.ai"`; otherwise Claude features show "unavailable" (never a blocking error). Jobs go through `claude_job` (persistent queue, 1 at a time, backoff 1/5/30 min, max 4 attempts, usage-limit errors pause the queue for 1 h). **Everything core (deck, FSRS, mascot, overlays, gate, objective exams) works with Claude unavailable** (DECISIONS rule 4); M8 proves it.

### 4.7 Tivra bridge (read-only)

- `TivraReader` actor opens `~/Library/Application Support/Tivra/tivra.db` with GRDB `Configuration.readonly = true` + `PRAGMA query_only = 1`, reads, closes; never holds locks; never opens a dev or smoke-test variant folder [06 §1.1, 10 Gaps]. If the file is missing, unreadable, encrypted, or a required table/column is missing (check `sqlite_master` against the expected subset), every answer is `UNVERIFIABLE` [06 Gaps].
- API: `health(window:)`, `foregroundEvidence(window:)`, `otherDeviceUsage(window:)`, `learningMinutes(day:)`, `focusBlockEnded(since:)` (from `sessions`). SQL from [06 §4.2, §7].
- `IntegrityVerifier` (pure) turns evidence + Tenaz's own integrity events + `DenyList` into the verdict JSON in [06 §4.2]. Tenaz stores only booleans, counts and `{start, end, kind, label}`, never Tivra titles or URLs [06 §1.1].
- `DenyList` = `Content/denylist.json`, used **only for the Tivra post-hoc scan** (Tenaz-side, exams use the allowlist in F5 step 4, `ExamAllowlist`): bundles `com.anthropic.claudefordesktop`, `com.anthropic.operon` (Claude Science), `com.openai.codex`, `com.google.GeminiMacOS`, `com.apple.Translate`, terminals `com.mitchellh.ghostty` and `com.apple.Terminal` (Claude Code / Codex CLI run there), `com.raycast.macos` (Raycast AI), `com.steipete.codexbar`, and `company.thebrowser.dia` **whole-app** (its built-in assistant is not a chatgpt.com/claude.ai URL, so a domain list cannot see it [unverified how Tivra records it]); ids read from the apps' `Info.plist` files; plus [unverified] DeepL/Perplexity ids; domains chatgpt.com, chat.openai.com, claude.ai, gemini.google.com, copilot.microsoft.com, perplexity.ai, poe.com, deepl.com, translate.google.com(.mx), reverso.net, linguee.com, wordreference.com, grok.com, you.com, character.ai, huggingface.co/chat, bing.com/translator; Android companion packages [06 §3.3, §4.2]. Exam mode = strict list (dictionaries too); practice = no checks [01 R20].
- **No writes**: nothing under `~/Library/Application Support/Tivra/`, no Tivra defaults, no `4242` secret, no companion pairing in v1 [06 §8.5]. Patches P1 (per-request block list + exemptions on `start`) and P2 (seed rule classifying `com.chere3.tenaz` as `aprendizaje`) are written as proposals in `docs/proposals/` only (DECISIONS rule 3).
- Known risk: if the learner starts a Tivra protection session with the learner's default list, Tivra will quit Tenaz (only `com.chere3.focusflow*` is exempt) [06 §2.3]. Handled in Tenaz (F5 step 6): per-item `exam_response` writes, resume within 15 min as `interruptedByTivra`, and a preflight warning from Tivra's `sessions` table. A bundle id under the exempt prefix (e.g. `com.chere3.focusflow.tenaz`) would avoid the quit, but must first be checked against Tivra's capture exclusion (`capture_tick.frontExcluded`, [06 §1.1]): if Tivra also stops capturing its own prefix, the witness would go blind during exams. Morning question 12.

### 4.8 Content pipeline

| Source | Licence | Use | How |
|---|---|---|---|
| Tenaz-original JSON (`Content/vocab`, `Content/items`, built; format in `Content/FORMAT.md`) | own | error patterns, false friends, phrasebank, prompts, achievements, configs | hand/agent-authored; `ContentTests` (built) check schema and duplicates |
| CEFR-J Wordlist 1.6 | free incl. commercial with citation ([cefr-j.org](https://www.cefr-j.org/download.html)) | CEFR level A1-B2 per word | `scripts/build-data.py` downloads, cites v1.6 |
| NGSL 1.2 / NAWL | CC BY-SA 4.0 ([NGSL](https://www.newgeneralservicelist.com/new-general-service-list)) | frequency bands, coverage, VST-style probe | separate `ngsl.sqlite` |
| Tatoeba en-es | CC BY 2.0 FR, author must be cited ([terms](https://tatoeba.org/en/terms_of_use)) | example sentences, cloze, dictation | from the detailed export with usernames; sentence filter from the earlier prototype's deck script (5-11 tokens, no names); store `sentence_id` + author |
| Earlier prototype deck (368 cards) | CEFR-J + Ngram CC BY 3.0 + Tatoeba | B1/B2 starter words | regenerate via the adapted script with attribution, never copy the Kotlin literals |
| CMU Pronouncing Dictionary | unrestricted, credit requested | stress/IPA for S cards and minimal pairs | `content.sqlite` |
| WikDict en-es | CC BY-SA 4.0 | offline gloss lookup | separate `wikdict-en-es.sqlite` |
| Not bundled | - | Oxford 3000/5000, EVP, SUBTLEX-US (until licence confirmed), book text, transcripts | [08 §5] |

Raw downloads go to gitignored `data/raw/`; generated SQLite files are committed under `Tenaz/Resources/Data/` with a `source` table. The Credits & Licences screen is generated from those tables.

### 4.9 Design system tokens

- **Direction**: "Riso Arcade" (indigo + orange on warm paper, pink reserved for Tena, halftone, mis-registration, arcade juice) [11 §3]. Pending the learner's sign-off (morning question 4).
- **Single source of colour truth**: `Sources/TenazCore/Design/Palette.swift` (hex values for Paper and Night Press themes from [11 §3.3]) + `Contrast.swift` (WCAG luminance math). `PaletteContrastTests` assert every declared pair (e.g. ink on paper 13.59, orangeDeep text 4.93, correct `#1A7344` 4.96, ink on orange 4.38 only as ≥20 pt Bold) [11 §3.3, Verification 1-2].
- App-side: `Tenaz/Shared/DesignSystem/Tokens.swift` (dynamic `NSColor` from Palette, spacing scale 4/8/12/16/24/32/48/72, radii 14/28/999, hard offset shadow 0,6), `Typography.swift` (Bricolage Grotesque variable TTF + `OFL.txt` in `Resources/Fonts/`, registered with `CTFontManagerRegisterFontsForURL`; SF Pro Rounded for UI; overlay word size from a stored multiplier, since `Font.scaled(by:)` is not in the macOS SDK [10 §9]), `Motion.swift` (tokens tap/settle/pop/slam/float/reduced; returns `reduced` under Reduce Motion [11 §5.2]), `Components/` (FatButton, AnswerField, InkBand, Chip, Sticker toast).
- Rules: one primary (orange, filled) button per screen; state never by colour alone (glyph + word); no Liquid Glass on content (word card, gate, exam are opaque paper); glass only on popover/toolbar chrome [11 §0, 10 §9]; no flashes >3 per second ([WCAG 2.3.1](https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html)); Quiet mode disables sound, particles, halftone and shake [11 §8].
- Debug "Gallery" window shows every token, tier and mascot mood (also a snapshot target).

---

## 5. Safety

### 5.1 Defaults (what ships off)

| Surface or rule | Default | Can be turned on by |
|---|---|---|
| Word overlays | **off** | Settings, after calendar access or explicit ack (F14) |
| Unlock gate | **off** | Settings |
| Strict gate | off | Contract (24 h delay) |
| Every penalty rule (F10) | **off** | Contract (24 h delay) |
| Exam Mode Tivra witness | on (read-only, harmless) | - |
| Tivra blocking requests | **not implemented** (proposal P1) | - |
| Login item | **off** | Settings toggle (`SMAppService.mainApp`) |
| Sound | on, low volume, auto-mute in meetings | Settings |
| Claude features | on if `auth status` is claude.ai | Settings |
| Notifications (pre-meeting warm-up) | off | Settings |

### 5.2 Escape hatches and kill switches (every one tested)

1. **Global hotkey `Ctrl+Opt+Cmd+Esc`** (KeyboardShortcuts / Carbon `RegisterEventHotKey`, no Accessibility permission [05 §5]): dismisses every panel at once and disables overlays + gate until the next 04:00 day boundary. No penalty; logged.
2. **`defaults write com.chere3.tenaz killSwitch -bool true`** (dev: `com.chere3.tenaz.dev`), observed live via `UserDefaults` KVO: dismiss all, disable all intrusions until set back to false.
3. **File flag** `~/Library/Application Support/<Tenaz|TenazDev>/DISABLE_OVERLAYS`, watched with a `DispatchSource` file-system source (the one sanctioned DispatchSource use, documented): same effect as 2, works from SSH or another agent [05 §1.4].
4. **Watchdog** per surface, independent of UI state: overlay 90 s, gate 5 min, evolution 20 s, exam section time + 10 min.
5. **Emergency skip** on every intrusive surface, always visible, priced, never blocked (F1, F2).
6. **Snooze / "I'm in a meeting" / Pause 1 h** from the panel and the menu bar.
7. **Force quit works**: banned APIs are `.disableForceQuit`, `.disableProcessSwitching`, `.disableSessionTermination`, `.disableHideApplication`, `CGShieldingWindowLevel`, Authorization Plugins, LaunchAgent `KeepAlive` [05 §3, §5]. Panels belong to the process, so a force quit removes them. Nothing relaunches Tenaz.
8. On `willTerminate` and SIGTERM: close panels, flush logs.
9. Penalty caps and recovery mode (F10) are safety too: a bad day cannot snowball.

### 5.3 What must be tested (named suites; an escape-hatch test must fail if the hatch is removed)

| Suite (`swift test --filter`) | Asserts |
|---|---|
| `SafetyTests/killSwitchDismissesAllSurfaces` | coordinator with fake panels: hotkey, defaults key, file flag each dismiss everything within one tick and block new intrusions until the day boundary/flag clears |
| `SafetyTests/watchdogClosesEachSurface` | with a test clock, each surface closes at its max time even if the UI never answers |
| `SafetyTests/guardDefersOnEachSignal` | each signal alone (mic, camera, meeting app, assertion, calendar, focus, idle, locked) ⇒ defer; provider throws ⇒ defer |
| `SafetyTests/cannotEnableWithoutCalendarOrAck` | enabling overlays/gate without calendar access or ack fails |
| `SafetyTests/capsAndQuietHours` | max batches, min interval, quiet hours, gates per day |
| `SafetyTests/emergencySkipAlwaysAvailable` | skip works with 0 Mercy tokens, in strict mode (after countdown), in recovery mode |
| `SafetyTests/penaltyCapAndRecovery` | -30 Vitality cap, 3-event recovery mode, Vitality floor 15, level never decreases |
| `SafetyTests/contractChangeDelay` | rule changes become effective only after 24 h |
| `SafetyTests/bannedPresentationOptions` | a static list check: the app's presentation-option helper rejects banned options |
| `ExamTests/meetingPausesExam`, `ExamTests/abortVoidsAttempt`, `ExamTests/tivraDownIsUnverifiable` | exam safety rules |
| `ClaudeTests/runnerScrubsEnvironment`, `ClaudeTests/neverPassesBare` | env has no `ANTHROPIC_API_KEY`, args never contain `--bare` |
| `TivraTests/readerIsReadOnly` | reader opens a fixture DB read-only; any write attempt throws |

App-level smoke (no TCC): `--tenaz-smoke overlay|gate|exam` shows the surface with fake content for ≤3 s, closes it through the watchdog path, writes `intrusion_log`, and exits; the verify script checks the log row and that the process ended.

### 5.4 Rules for the autonomous overnight builder

- Build and run **Debug only** (`TenazDev`). Never run `scripts/install-tenaz.sh`, never copy anything to `/Applications`, never enable the login item, never add a LaunchAgent.
- Intrusive surfaces only through `--tenaz-smoke` (auto-dismiss ≤3 s) or `--tenaz-snapshot` (renders off-screen). Never leave overlays or the gate enabled in `TenazDev` defaults at the end of a milestone; finish every verification with `pkill -x TenazDev`.
- No TCC grants will be clicked overnight. Every milestone that touches Calendar, mic, camera queries, Speech, Focus or notifications must pass its acceptance with permission **denied or not determined** (guard ⇒ defer; speech ⇒ "unavailable"). The learner grants permissions in the morning and re-runs.
- `screencapture -x` needs Screen Recording for the terminal; if the image is missing windows, the `--tenaz-snapshot` PNG (rendered by the app with `ImageRenderer`, no permission) is the evidence. Build + tests are the hard gate; images are evidence.
- Tivra: read-only, through `TivraReader` only. Do not open, build, edit or check out anything in the Tivra repo. Tests use `Tests/TenazCoreTests/Fixtures/tivra_fixture.sql`.
- Claude calls overnight: only the M8 connection test and small batches for prompts/items/knowledge cards (≤50 calls per milestone). If `auth status` is not `claude.ai`, skip and note it in the private status log.
- After each milestone: `swift test` green, Debug build green, smoke/snapshot done, status log updated (milestone checked, what the learner must check; the log is kept privately), commit (the orchestrator decides). Never leave the tree broken.
- No scratchpad paths in the repo. Scripts live in `scripts/`, fixtures in `Tests/TenazCoreTests/Fixtures/`.

---

## 6. Milestones

Each milestone ends with a runnable app. Acceptance commands use the block in section 0; `V` below means "`scripts/verify.sh Mn` passes", which runs `swift test`, `xcodegen generate`, the Debug build, the listed snapshots/smokes, and `pkill`.

### M1. Scaffold: builds and launches

- **Scope**: `Package.swift` (GRDB only), `project.yml` (the build-verified [10 §6.2] as is: no extra packages in M1; Debug/Release identities), `.swiftformat`, `.mcp.json` (XcodeBuildMCP 2.7.0 [10 §1]), `.gitignore` (+ `.derived/`, `data/raw/`, `*.xcodeproj`), `Tenaz/App/TenazApp.swift` with `MenuBarExtra(.window)` showing "Tenaz" + a placeholder Tena circle + "Open Tenaz" + "Quit", a `Window("Tenaz", id: "home")` placeholder, `LaunchArguments` (`--tenaz-snapshot <screen> --out <png>`, `--tenaz-smoke <surface>`), `Snapshot.swift` (ImageRenderer → PNG → exit), `TenazCore/Persistence/Paths.swift` (Application Support folder per bundle id), `Support/Clock.swift`, `scripts/verify.sh`, CLAUDE.md commands updated to `.derived`.
- **Tests**: `SmokeTests/pathsUseBundleSpecificFolder`, `SmokeTests/clockSleepsWithTestClock`.
- **Acceptance**: `swift test` passes; `xcodegen generate` and the Debug build print `BUILD SUCCEEDED` with zero warnings; `TenazDev --tenaz-snapshot popover --out .derived/shots/m1-popover.png` creates a non-empty PNG and exits 0; `open TenazDev.app` → `pgrep -x TenazDev` succeeds after 4 s → `pkill`; `codesign -dvv` shows `Identifier=com.chere3.tenaz.dev` and `TeamIdentifier=<TEAMID>`.
- **The learner (morning)**: click the menu-bar item, see the popover; confirm the name.

### M2. Core data and FSRS engine

- **Scope**: GRDB migrations v1 (`note`, `card`, `review_log`); `FSRS6` port + `LearningSteps` (py-fsrs semantics); `ReviewQueue` (due first, new cap 5/day, 1:4 ratio, daily cap 120, sibling burying, ≤3 same type in a row); `AnswerMatcher` (normalization, accepted variants, edit-distance-1 = Hard); grade mapping per card type; seed content JSON (12 error patterns, ~25 false friends, ~120 phrasebank chunks, ~40 workplace words) and a loader that creates cards on first launch; `scripts/fsrs-fixtures.py`.
- **Tests**: `FSRSTests/longTermGoldenVectors` (the 6-step table, 1% relative / 0.02 absolute tolerance), `FSRSTests/withStepsGoldenVectors`, `FSRSTests/roundsHalfToEven`, `FSRSTests/newCardStepIntervals` (1 min / 5.5 min / 10 min / 8 d), `QueueTests/*`, `AnswerMatcherTests/*`, `MigrationTests/freshAndUpgrade`, `ContentValidationTests/seedIsValid`.
- **Acceptance**: V; `uv run --with 'fsrs==6.3.2' scripts/fsrs-fixtures.py` regenerates `fsrs_with_steps.json` with no diff; launching the app creates `~/Library/Application Support/TenazDev/tenaz.sqlite` with >150 notes (`sqlite3 ... 'select count(*) from note'`).
- **The learner**: skim `Content/seed/*.json` (are the chunks and the learner's error patterns right?).

### M3. Design system and the review session

- **Scope**: `Palette`/`Contrast` + app tokens, Typography (Bricolage download + OFL, fallback SF Rounded Heavy if the TTF is unavailable), Motion, FatButton, AnswerField, InkBand, Chip, Sticker; main window **Home** (placeholder Tena + one primary "Start today's set") and **Review** screen (E1-E7: MC for R, typed for C/L/K; tier S/M feedback and penalty tier; relearning steps visible as "again in 1 min"); `ProgressStore`/`ReviewSession` wired to the DB; Gallery debug window.
- **Tests**: `PaletteContrastTests/everyDeclaredPairMeetsItsRatio`, `MotionTests/reducedWhenFlagSet`, `ReviewSessionTests/wrongAnswerSchedulesOneMinute` (TenazCore session state machine), `ReviewSessionTests/logsEveryAnswer`.
- **Acceptance**: V; snapshots `home`, `review-question`, `review-correct`, `review-wrong`, `gallery` exist; a scripted session (`--tenaz-selftest review`) answers 10 seeded cards via the session API and writes 10 `review_log` rows.
- **The learner**: the look (Riso Arcade sign-off), the font, does typing an answer feel instant.

### M4. Mascot, XP, streak (gamification core)

- **Scope**: `XP` (formula, anti-farming, level curve), `Streak` (qualified day = 10 correct + 1 production, freezes, 5-of-7, day boundary 04:00; port the earlier prototype's streak-engine tests as the base), `Mascot` (meters, moods, stages 0-3 with catch-up, stage gate evaluator reading `Content/config/stages.json`), Scales; `day_stat`, `xp_event`, `scales_event`, `mascot_state`, `mascot_event`; Canvas Tena rig with 12 moods + `MascotGallery`; Home shows Tena, stage, Vitality/Spirit, streak; popover shows the same; XP stickers.
- **Tests**: `XPTests/curveValues` (L1 100, L5 441, L10 1065, L20 2712), `XPTests/levelNeverDecreases`, `StreakTests/*` (freeze bridging, best streak kept, welcome-back after 3 days), `MascotTests/moodTable`, `MascotTests/stagesNeverRegress`, `MascotTests/vitalityFloor15`.
- **Acceptance**: V; snapshots `home`, `mascot-gallery` (all 12 moods), `popover`.
- **The learner**: does Tena look right (axolotl, pink riso), name "Tena".

### M5. Safety core and Settings (before any intrusive surface)

- **Scope**: add the KeyboardShortcuts 3.1.0 package to the app target (if it breaks the Swift 6 build, use Carbon `RegisterEventHotKey` instead); `KillSwitch` (hotkey, defaults KVO, file flag), `Watchdog`, `InterruptionGuard` + `IntrusionPolicy` (caps, quiet hours, intervals), signal providers (CoreAudio mic, CMIO camera, frontmost meeting app, `IOPMCopyAssertionsByProcess`, EventKit, `INFocusStatusCenter` (best effort), idle, locked), `intrusion_log`; Settings scene (all toggles off, the Safety page listing every hatch); the M5 entitlements and Info.plist keys from section 4.1; `--tenaz-probe-guard` prints the current decision and each signal as JSON and exits. Fold spikes 3, 4, 5 of [05 §12] in here.
- **Tests**: every `SafetyTests/*` row in section 5.3 except exam ones.
- **Acceptance**: V; `TenazDev --tenaz-probe-guard` prints valid JSON with a value for every signal (calendar may be `"notDetermined"`, focus may be `"notDetermined"` or `"unavailable"`; decision must be `defer` or `allow`, never a crash); `defaults write com.chere3.tenaz.dev killSwitch -bool true` while the app runs → probe reports `deny(killSwitch)`; reset it.
- **The learner**: grant Calendar and Focus; run the probe during a Teams/Meet call and check it says defer (mic, camera, app, calendar).

### M6. Word overlays

- **Scope**: `OverlayPanel` per screen (window recipe F1), poster and sticker modes, batch of 3 from `ReviewQueue`, triggers (unlock/wake merge + debounce, app switch after 25 min single-app, idle return), 20 s pre-announcement pulse, escape ladder, relearning returns, `IntrusionCoordinator` integration (guard → caps → show → log); notifications are not used yet. Fold spike 1 and 2 of [05 §12] (panel over a full-screen Space; which unlock notifications fire).
- **Tests**: `OverlayTests/batchOnlyAutoScorableTypes`, `OverlayTests/missedWordReturnsInOneMinute`, `OverlayTests/deferWhenGuardDefers`, `OverlayTests/killSwitchClosesMidAnswer`, `OverlayTests/skipCostsThreeVitality`.
- **Acceptance**: V; `TenazDev --tenaz-smoke overlay` shows the poster with fake content, closes within 3 s, exits 0, and `intrusion_log` has a row with outcome `timeout` or `completed`; snapshots `overlay-poster`, `overlay-sticker`, `overlay-wrong`; `defaults read com.chere3.tenaz.dev overlaysEnabled` is false after the run.
- **The learner**: turn overlays on for an hour; test the kill switch, Esc, snooze, full-screen apps, a secondary display; report anything that felt hostile.

### M7. Unlock gate

- **Scope**: `GatePanel` (activated, key, custom paste-proof `NSTextView`), prompt rotation from `Content/prompts/gate.json` (60 canned), local checks (word count, `NLLanguageRecognizer`, chunk present, TTR floor), twice-failed word injection, emergency skip with Mercy tokens, 5-min watchdog with timeout cost, Return to unlock with tier-L stamp, `writing_entry` rows (gradeStatus `pending`).
- **Tests**: `GateTests/localChecks` (Spanish text rejected, pasted text impossible through the API, missing chunk rejected), `GateTests/maxThreePerDayTwoHoursApart`, `GateTests/skipWorksWithZeroTokens`, `GateTests/timeoutCostsTenAndCounts`.
- **Acceptance**: V; `--tenaz-smoke gate` opens, auto-closes ≤3 s, logs; snapshots `gate-empty`, `gate-ready` (counter full, button orange).
- **The learner**: enable the gate for a day; is 25-40 words right; does the skip feel honest.

### M8. Claude bridge, writing grading, error ledger

- **Scope**: `ClaudeRunner` (section 4.6), `ClaudeJobQueue` + `claude_job`, `auth status` health check, schemas in `Sources/TenazCore/Claude/Schemas/`, rubric prompts (gate paragraph, P card, role-play turn), `grade_run`, prompt-first two-pass feedback UI in the Review/Write screens, `error_ledger` + card spawning from repeated errors, P cards enabled, capture-from-life (E22) with "local only", role-play E18 (typed), prompt-batch generator for gate prompts.
- **Tests**: `ClaudeTests/runnerScrubsEnvironment`, `ClaudeTests/neverPassesBare`, `ClaudeTests/argumentsExact`, `ClaudeTests/decodesFixtureResult` (stored real result JSON), `ClaudeTests/missingStructuredOutputIsFailure`, `ClaudeTests/timeoutInterruptsThenTerminates` (fake executable script in Fixtures that sleeps), `LedgerTests/repeatErrorSpawnsCard`.
- **Acceptance**: V; `TenazDev --tenaz-selftest claude` grades one fixture paragraph through the real CLI and prints the decoded JSON (if `auth status` is not claude.ai, prints `unavailable` and exits 0); **offline proof**: run `swift test --filter OfflineTests` where the runner points at a missing executable and the full review → gate → XP path still completes, jobs stay `queued`.
- **The learner**: read 5 real gradings; are the corrections right; is the feedback tone OK.

### M9. Contract, penalties, quests, achievements, onboarding, weekly review

- **Scope**: `Penalties` (rules, cost table, caps, recovery mode, 24 h delay), Contract screen, repair task flow (regrowing limb), quests (3 daily + weekly), achievements from `Content/achievements.json` (~30 computable now), mystery drop with disclosed odds, 12 cosmetics, onboarding (welcome, level paragraph typed, daily minimum, if-then plan, intrusions explained and left off, contract left empty), weekly review screen, experiment log per rule, `if_then_plan`, `weekly_review`.
- **Tests**: `SafetyTests/penaltyCapAndRecovery`, `SafetyTests/contractChangeDelay`, `QuestTests/adaptiveTargets`, `AchievementTests/conditions`, `PenaltyTests/escapeRateSuggestsDisable`.
- **Acceptance**: V; snapshots `contract`, `quests`, `achievements`, `onboarding-1..4`, `weekly-review`, `mascot-injured`, `mascot-regenerating`.
- **The learner**: write a real contract (which penalties, how strong); go through onboarding once.

### M10. Exams I: item bank, Daily Check, level estimation, placement (objective parts)

- **Scope**: `item`, `exam_attempt`, `exam_response`, `skill_state`, `band_history`; `ObjectiveScorer` (all objective types), `RaschGrid` (81 points, EAP, SD stop), band mapping from `Content/config/bands.json`; starter bank of ≥150 objective items in `Content/items/` (Complete the Words, Build a Sentence, grammar/vocab cloze, key-word transformation, short Read in Daily Life passages) + ~60 anchors marked; item validators; `scripts/generate-items.py` (offline Claude batches, validated before import); Daily Check UI (normal window, not Exam Mode); placement objective parts (vocabulary-size probe by NGSL band once M13 data exists, interim seed list now; reading); grants stages 0-3.
- **Tests**: `ExamTests/raschPosteriorMovesTowardEvidence`, `ExamTests/stopsWhenSDBelowThreshold`, `ExamTests/bandNeverRoundsUp`, `ExamTests/buildSentenceAcceptsListedOrders`, `ItemValidationTests/bankIsValid`, `PromotionTests/needsTwoVerifiedMonthlies`.
- **Acceptance**: V; `--tenaz-selftest daily-check` runs a simulated learner at theta 0.3 through the Daily Check and ends with a band within ±0.5 of the truth (seeded RNG); snapshot `daily-check-question`, `daily-check-result`.
- **The learner**: take one Daily Check; do items feel B1+/B2; spot wrong keys.

### M11. Exams II: Exam Mode, anti-cheat, Tivra witness, Weekly Mock

- **Scope**: `ExamPanel`, pre-commitment and preflight screens, paste/clipboard/burst monitors, frontmost timeline + deny-list hide, meeting pause, Esc-hold abort, `integrity_event`; `TivraReader` + `IntegrityVerifier` + `DenyList` with runtime bundle resolution; post-exam verification at +90 s and +15 min; results screen with the integrity timeline and "contest" action; Weekly Mock blueprint (Reading/Listening router + module with text-only listening placeholders until M12 TTS, Build a Sentence, Write an Email graded by Claude after submit); dashboard line "Tivra says N Learning minutes today"; `docs/proposals/tivra-P1-guard.md` and `tivra-P2-seed-rule.md` (text only).
- **Tests**: `TivraTests/readerIsReadOnly`, `TivraTests/verdictClean|Violation|Warning|Unverifiable` (fixture DB with spans touching claude.ai, a capture gap, a paused span, a phone span [06 §8.2]), `TivraTests/missingTableIsUnverifiable`, `ExamTests/meetingPausesExam`, `ExamTests/abortVoidsAttempt`, `ExamTests/tivraDownIsUnverifiable`, `ExamTests/denyAppActivationFlags`.
- **Acceptance**: V; `--tenaz-smoke exam` opens Exam Mode with a 3-item fake section, closes ≤3 s; `--tenaz-selftest tivra` runs the reader against the **live** Tivra DB read-only and prints health JSON (or `unavailable`), verifying with `lsof` afterwards that Tenaz holds no handle on `tivra.db`; snapshot `exam-reading`, `exam-results`.
- **The learner**: take one Weekly Mock; deliberately open ChatGPT for 5 s and check it is flagged; confirm the Tivra witness reads correctly.

### M12. Speech, listening and the Monthly Full Mock

- **Scope**: TTS via `AVSpeechSynthesizer` (best premium/enhanced en-US/en-GB voice, pre-rendered and cached as audio files) [05 §8]; listening items (Choose a Response, Conversation, Announcement, Academic Talk) rendered from transcripts; `SpeechAnalyzer` + `SpeechTranscriber` with `.audioTimeRange` and `.transcriptionConfidence`, fallback to `SFSpeechRecognizer` on-device [05 §7]; fluency metrics (WPM, pauses, fillers, repetitions, TTR) with duration-based fallback; Listen & Repeat (WER → 0-5), Take an Interview (45 s), 4/3/2, shadowing, minimal pairs, dictation; speaking grading through Claude on the transcript; Monthly Full Mock blueprint (~90 min) with 3-run median grading and promotion; dictated monthly sample. Entitlement `com.apple.security.device.audio-input` and Info.plist `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` (section 4.1). Spike 6 of [05 §12].
- **Tests**: `SpeechMetricsTests/fromFixtureTranscript` (timestamped JSON fixture), `SpeechMetricsTests/durationFallback`, `ExamTests/werToBand`, `ExamTests/monthlyMedianOfThree`, `SpeechTests/unavailableWithoutPermission`.
- **Acceptance**: V; `--tenaz-selftest tts` renders 3 listening items to cached audio files (no permission needed); snapshot `speaking-4-3-2`, `monthly-mock-sections`; with mic permission not determined, speaking tasks show "Microphone needed" and the mock offers typed fallbacks.
- **The learner**: grant mic + speech; record 20 sentences to check transcription accuracy on the learner's accent [05 §12.6]; take the first Monthly Mock when ready.

### M13. Content pipeline, recommendations, knowledge cards

- **Scope**: `scripts/build-data.py` (uv; downloads CEFR-J 1.6, NGSL 1.2/NAWL, Tatoeba en-es detailed export with authors, CMU dict, WikDict en-es; writes the three SQLite files with `source` tables); regenerate the earlier prototype's 368-card deck with attribution; Credits & Licences screen; vocabulary-size probe by NGSL band (placement upgrade); `Coverage` service (NLTagger lemmas, proper nouns known); `Content/catalog.json` (37 books + podcast ladder); recommendation scoring; Library screen (1 primary + 2 alternates, "why" line); ePub/plain-text import (local only); reading log with wpm/comprehension; ~30 knowledge cards via `scripts/generate-knowledge.py`; E10 reading, E21 retell.
- **Tests**: `CoverageTests/goldenText`, `RecommendationTests/monotonicInterest`, `RecommendationTests/oneLaneBAtATime`, `RecommendationTests/coldStartDeterministic`, `ContentLicenceTests/everyRowHasSource`, `ContentLicenceTests/shareAlikeInSeparateFiles`.
- **Acceptance**: V; `uv run scripts/build-data.py` completes and is idempotent; the three SQLite files exist with `source` rows; snapshot `library`, `knowledge-card`, `credits`.
- **The learner**: are the book picks interesting; mark tech words as known in bulk.

### M14. Polish: sound, menu-bar states, notifications, login item, novelty schedule

- **Scope**: sound palette (~30 short original samples via `AVAudioEngine`, auto-mute on meeting signals) [11 §5.5]; menu-bar Tena glyph states + pulse (switch to `NSStatusItem` if needed, section 2 row 13); pre-meeting warm-up notification with `UNTextInputNotificationAction` (off by default) [05 §5]; login item toggle via `SMAppService.mainApp` (off); Quiet mode; seasonal palettes (re-checked by the contrast test); scheduled novelty at weeks 2/4/8/12; remaining achievements; nightly `VACUUM INTO` backups; JSON export/import; `scripts/install-tenaz.sh` (written and shellchecked, **not run**); README.
- **Tests**: `PaletteContrastTests/seasonalPalettes`, `SoundTests/mutedDuringMeeting`, `BackupTests/vacuumIntoRestores`, `ExportTests/roundTrip`.
- **Acceptance**: V; snapshots `popover-hungry`, `popover-sick`, `popover-asleep`, `settings-safety`; `bash -n scripts/install-tenaz.sh` passes.
- **The learner**: run `scripts/install-tenaz.sh` themself when the learner wants the Release build in `/Applications`; decide on the login item.

**Backlog (not scheduled)**: FSRS parameter optimization from the learner's review log (fsrs-rs on exported logs) [03 §4.3]; Foundation Models hints [05 §9]; Rive mascot [11 §7.2]; Kokoro TTS [05 §8]; Tivra patches P1/P2 in a Tivra worktree after the learner approves; global "select text anywhere → save card" service [07 §5.4]; monthly tutor-brief export [07 §5.10]; pronunciation scoring beyond intelligibility.

---

## 7. Open questions (product decisions for the learner)

1. **Name**: is "Tenaz" OK? And the mascot: axolotl "Tena" (vs the fly or a tree)?
2. **Exam family**: Aptis (British Council), IELTS, or TOEFL iBT? The plan uses the TOEFL 2026 structure plus an Aptis-style grammar/vocabulary block.
3. **Is a certificate needed** for work, or only meeting fluency? That decides whether to schedule a real exam (Aptis Advanced or TOEFL) to calibrate Tenaz's band once or twice a year.
4. **Visual direction**: sign off "Riso Arcade" (indigo + orange on paper, pink Tena) or pick one of the rejected alternatives; is Bricolage Grotesque the right display font?
5. **Daily minimum**: 10 correct retrievals + 1 sentence (about 4 min). Too little or too much?
6. **Intrusion strength**: overlays up to 8 a day, at least 40 min apart; gate up to 3 a day with 25-40 words. OK as starting values once the learner turns them on?
7. **The learner's contract**: which penalties are on (response cost, repair task, strict gate, extra cards, exam stake), and how strong?
8. **Sound**: on by default at low volume (auto-muted in meetings), or off?
9. **Exam length**: is a ~90-minute monthly mock acceptable? Which day for the weekly mock?
10. **Anti-cheat strictness**: dictionaries allowed in normal practice (AI forbidden only in exams)? Exam violations: flag only, or flag + retake + Vitality cost?
11. **Tivra**: should patch P1 be built (Tenaz can ask Tivra to block named AI apps/sites during exams, ~2 days in a Tivra worktree), or should Tenaz stay detect-only? Should Tivra classify Tenaz as Learning (patch P2, or one correction in Tivra's Review)? Should there be a Learning calendar block?
12. **Tivra quits Tenaz** if the learner starts a protection session with their default block list (only `com.chere3.focusflow*` is exempt). Accept, or plan an exemption in P1?
13. **Permissions to grant** (Calendar, Focus status, microphone, speech recognition, notifications) and which calendars count as work meetings. Focus status may need the Communication Notifications capability enabled for the App ID in the developer portal; until then Tenaz ignores Focus and uses the other meeting signals.
14. **Confidentiality**: may "capture from life" phrases from work meetings go to Claude through the learner's subscription, or should capture default to local only?
15. **Claude model for grading**: `sonnet` by default (lighter on the learner's subscription usage), or `opus` for monthly mocks?
16. **Goal framing**: first milestone "balanced B2" (band 4.0, no skill below 3.5), "meeting ready" at 4.5 with speaking ≥4.0, C1 later without a fixed date. Agree?
17. **Install**: when is the Release build installed to `/Applications` (via `scripts/install-tenaz.sh`), and should Tenaz start at login?
18. **Rive** (external editor) for a richer mascot later, or stay with native Canvas?
