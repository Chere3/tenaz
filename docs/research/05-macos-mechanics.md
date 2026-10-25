# 05 - macOS 26 mechanics for Tenaz's intrusive features

Date: 2026-10-22. Scope: feasibility and exact APIs. Constraints come from `DECISIONS.md` (overlays off by default, escape hatches, never block meetings, Tivra read-only, Claude only via local CLI, non-sandboxed, Swift 6).

Evidence labels: **[web]** = found in a source this session (URL inline); **[api]** = long-standing public API I am confident of from Apple docs/experience, but I did not re-fetch the page this session (the doc URL is given so you can check); **[unverified]** = needs a test on macOS 26 before relying on it. Web search this session was limited (no primary Apple page fetched in full), so treat [api] items as "verify with a 10-line spike" and every [unverified] as a spike task.

---------------------------------------------------------------------------

## 0. Summary of decisions

1. Overlay = one `NSPanel` per screen, `.nonactivatingPanel`, level `.screenSaver` (not `CGShieldingWindowLevel`), `canJoinAllSpaces + fullScreenAuxiliary + stationary`, app activation policy `.accessory`. A text-input gate needs `canBecomeKey = true` and an explicit `NSApp.activate` + `makeKeyAndOrderFront`.
2. The "unlock gate" is triggered by `NSWorkspace.sessionDidBecomeActiveNotification` / `screensDidWakeNotification`, with the undocumented `com.apple.screenIsUnlocked` as a secondary signal. It is a window, never an authorization plugin.
3. Never use `NSApplication.PresentationOptions` `.disableForceQuit`, `.disableProcessSwitching`, `.disableSessionTermination`. Use at most `.hideDock`/`.hideMenuBar` for exam mode, and only with the kill switch tested.
4. "Do not interrupt" is a composite score: mic running (CoreAudio), camera running (CMIO), meeting app frontmost, display-sleep power assertions, EventKit event now, Focus status via `INFocusStatusCenter`. Any positive means defer. Fail-open (if a detector errors, treat as "do not interrupt").
5. Anti-cheat is best-effort deterrence, not proof. The honest design is: exam mode = fullscreen panel + paste/drag disabled + typing-pattern signal + Tivra blocklist of AI apps/sites + a "integrity flag" on the result, not a hard guarantee (a phone defeats everything).
6. Speech: `SpeechAnalyzer`/`SpeechTranscriber` for on-device English dictation; pronunciation scoring is NOT provided by Apple, so use transcript-match + confidence as a proxy.
7. TTS: system premium/enhanced voices first (zero dependency); Kokoro via FluidAudio (CoreML) as an optional upgrade, watching the eSpeak-NG GPL note.
8. Foundation Models (4096-token window) for instant hints/grading of tiny items; Claude CLI for essays and rich feedback.
9. Claude CLI: `Process` with absolute path, scrubbed env, closed stdin, `--output-format stream-json --verbose`, hard timeout, cancel on app quit.
10. Persistence: GRDB (SQLite) in `TenazCore`; not SwiftData.

---------------------------------------------------------------------------

## 1. Full-screen overlay windows

### 1.1 Window levels
Levels, low to high (values from `CGWindowLevel.h`) [api]: `.normal` 0, `.floating` 3, `.mainMenu` 24, `.statusBar` 25, `.popUpMenu` 101, `.screenSaver` 1000 (101 and 1000 re-checked against a mirror of `CGWindowLevel.h`, see Verification), and `CGShieldingWindowLevel()` (display-capture level; the number 2147483628 previously quoted here is **[unverified]**, read it at runtime instead of hard-coding it). Docs: https://developer.apple.com/documentation/appkit/nswindow/level and https://developer.apple.com/documentation/coregraphics/1455371-cgshieldingwindowlevel

- `.screenSaver` is enough to cover full-screen apps, the Dock, and the menu bar. It does not cover the actual lock screen/login window (correct and desired).
- `CGShieldingWindowLevel()` sits above even system alerts and Mission Control's chrome; if a bug leaves the window stuck, the user cannot reach Force Quit dialogs visually. For Tenaz (never lock the learner out) prefer `.screenSaver` so system panels (Force Quit via Cmd-Opt-Esc, power dialog) can still appear above. Use `.screenSaver` + 1 only if a specific app beats it. [judgment]

### 1.2 Collection behavior and activation policy
```swift
final class GatePanel: NSPanel {
    override var canBecomeKey: Bool { true }   // needed for text input
    override var canBecomeMain: Bool { false }
}

func makeGatePanel(for screen: NSScreen) -> GatePanel {
    let p = GatePanel(contentRect: screen.frame,
                      styleMask: [.borderless, .nonactivatingPanel],
                      backing: .buffered, defer: false, screen: screen)
    p.level = .screenSaver
    p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    p.isOpaque = false
    p.backgroundColor = .clear
    p.hidesOnDeactivate = false
    p.isReleasedWhenClosed = false
    p.hasShadow = false
    p.isMovable = false
    return p
}
```
Key points [api] (https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior):
- `.canJoinAllSpaces` puts it on every Space; `.fullScreenAuxiliary` lets it sit alongside a full-screen app's Space; `.stationary` keeps it fixed during Mission Control/Space switches. Do not combine `.canJoinAllSpaces` and `.moveToActiveSpace` (they express opposite intents; Apple's per-option pages do not state that combining throws, so "throws" is **[unverified]**, just never combine them).
- A window of a regular (`.regular` policy) app does NOT appear over another app's full-screen Space reliably; an `.accessory` (LSUIElement) app with `.fullScreenAuxiliary` does. Set `NSApp.setActivationPolicy(.accessory)` (Tenaz is a menu-bar app anyway) and switch to `.regular` temporarily only while the main window (Dashboard) is open. [api; unverified on 26 for the switch-flicker]
- Create one panel per `NSScreen.screens`; listen to `NSApplication.didChangeScreenParametersNotification` to rebuild. Mirror mode and external displays "Displays have separate Spaces" both matter; test with a secondary monitor.
- Do not use `NSWindow.toggleFullScreen`; it creates its own Space and animation, and breaks "above other full-screen apps".

### 1.3 Key window and text input in non-activating panels
- A `.nonactivatingPanel` can become key without activating the app, but a borderless panel returns `false` from `canBecomeKey` unless overridden (done above).
- For the typing gate, do the full sequence: `NSApp.activate()` (macOS 14+ `activate()` replaces `activate(ignoringOtherApps:)`; cooperative activation can be refused if another app is frontmost, so activation may not take on a freshly unlocked session) then `panel.makeKeyAndOrderFront(nil)`, then `panel.makeFirstResponder(textView)`. If activation is refused, the panel still shows but key events go to the previous app: detect with `panel.isKeyWindow` after 300 ms and, if false, show a big "click here to type" affordance (a click makes it key because of `canBecomeKey`).
- Cooperative activation reference: https://developer.apple.com/documentation/appkit/nsapplication/activate() [api; behavior on 26 unverified].
- Do not call `NSApp.presentationOptions` for this (see section 3).
- For SwiftUI content, host with `NSHostingView` as `contentView`; `@FocusState` works but set first responder at AppKit level first.

### 1.4 Kill switches (mandatory)
- Global hotkey (section 5) that calls `GateController.dismissAll(reason: .killSwitch)`.
- A watchdog `Task` that dismisses all panels after `maxOnScreen` seconds regardless of state.
- `defaults write app.tenaz.Tenaz overlaysEnabled -bool false` read through `UserDefaults` change observation (KVO on `UserDefaults.standard`), so Terminal over SSH or a second login can disable it. Also honor a file flag `~/Library/Application Support/Tenaz/DISABLE_OVERLAYS` (poll by `DispatchSource.makeFileSystemObjectSource`) so another machine/agent can disable it. [design]
- On `NSApplication.willTerminateNotification` and via `signal(SIGTERM)` handler, close panels (a force-quit already removes the windows since they belong to the process).

---------------------------------------------------------------------------

## 2. Unlock / wake / session detection

| Signal | Kind | Notes |
|---|---|---|
| `NSWorkspace.shared.notificationCenter` `.screensDidWakeNotification` / `.screensDidSleepNotification` | public | display wake. https://developer.apple.com/documentation/appkit/nsworkspace/1535985-screensdidwakenotification [api] |
| `NSWorkspace.didWakeNotification` / `.willSleepNotification` | public | system sleep/wake (no lock info). |
| `NSWorkspace.sessionDidBecomeActiveNotification` / `.sessionDidResignActiveNotification` | public | fast-user-switching session changes; also fires on lock/unlock in practice? Not guaranteed: it is about console session ownership. [api; lock behavior unverified] |
| `DistributedNotificationCenter` `com.apple.screenIsLocked` / `com.apple.screenIsUnlocked` | undocumented | widely used: Chromium idle detection registers both (https://chromium.googlesource.com/chromium/src/+/e8a107c96/ui/base/idle/idle_mac.mm) and a recent IME project observes them via Combine (https://testgitea.trustie.net/floraachy/vChewing-macOS/commit/85833c40d94a43e2dae78ee9a557239b7d55d3bd) [web]. Tahoe behavior: **[unverified]** (my search found no Tahoe-specific confirmation). |
| `com.apple.screensaver.didstart` / `didstop` | undocumented | screen saver start/stop. [api-ish, unverified on 26] |
| `CGSessionCopyCurrentDictionary()` -> `kCGSessionOnConsoleKey`, `CGSSessionScreenIsLocked` | semi-public | poll to confirm "currently locked?" Key `CGSSessionScreenIsLocked` is undocumented. [unverified on 26] |

Implementation: subscribe to all, debounce 1.5 s, require `CGSSessionScreenIsLocked` to be absent/false (poll after the event) before showing the gate, and keep a per-day cap (e.g. at most N gates/day, min interval 20 min) so waking the laptop 15 times does not spawn 15 gates.

```swift
let ws = NSWorkspace.shared.notificationCenter
let dn = DistributedNotificationCenter.default()
let events = merge(
  ws.publisher(for: NSWorkspace.screensDidWakeNotification),
  ws.publisher(for: NSWorkspace.sessionDidBecomeActiveNotification),
  dn.publisher(for: .init("com.apple.screenIsUnlocked")))
  .debounce(for: .seconds(1.5), scheduler: RunLoop.main)
```

### Why not replace the login window (SFAuthorizationPluginView)
- macOS lets you add custom UI to the login/unlock flow only via **Authorization Plugins** (`SFAuthorizationPluginView`, `AuthorizationPlugin.h`), bundles installed in `/Library/Security/SecurityAgentPlugins`, root-owned, loaded into `SecurityAgent` and then wired through edits to the authorization database (`security authorizationdb`). Reference: https://developer.apple.com/documentation/securityinterface/sfauthorizationpluginview [api]. Apple's own page and sample are old, and the Security Interface framework is only lightly maintained. [judgment]
- Risks: a crash or bad mechanism ordering at login can prevent logging in (recovery mode needed); it runs before the user session with elevated privilege; needs notarization and admin install; SIP/SSV and MDM (a work-managed Mac may enforce them) may block it; it directly violates DECISIONS rule 1. **Decision: never.** Gate after unlock only.
- Consequence to communicate to the learner: the gate is a speed bump, not a lock. The learner can quit the app. The commitment device must therefore be consequence-based (mascot/XP/Tivra blocks), plus optional macOS Screen Time/Tivra-based friction.

---------------------------------------------------------------------------

## 3. Kiosk presentation options

`NSApplication.presentationOptions` (https://developer.apple.com/documentation/appkit/nsapplication/presentationoptions) [api]: `.hideDock`, `.autoHideDock`, `.hideMenuBar`, `.autoHideMenuBar`, `.disableAppleMenu`, `.disableProcessSwitching` (blocks Cmd-Tab), `.disableForceQuit` (blocks Cmd-Opt-Esc), `.disableSessionTermination` (blocks power/logout), `.disableHideApplication`, `.disableMenuBarTransparency`, `.fullScreen`, `.autoHideToolbar`, `.disableCursorLocationAssistance`.

Rules/risks:
- Invalid combinations raise `NSInvalidArgumentException` (verified rules, per Apple's PresentationOptions page: `.hideMenuBar` requires `.hideDock` specifically; `.autoHideMenuBar` requires `.hideDock` or `.autoHideDock`; `.disableProcessSwitching`, `.disableForceQuit`, `.disableSessionTermination` and `.disableMenuBarTransparency` require `.hideDock` or `.autoHideDock`; dock and menu-bar hide/autoHide pairs are mutually exclusive). Wrap in a validated helper and unit-test with `defer`-style restoration. So `[.hideDock, .hideMenuBar]` is valid; `[.hideMenuBar]` alone crashes.
- The options apply only while the app is active; they reset on deactivation. If the app hangs while active with `.disableProcessSwitching + .disableForceQuit`, the learner can't Cmd-Tab or Force Quit => violates the hard rule. **Banned for Tenaz**: `.disableForceQuit`, `.disableProcessSwitching`, `.disableSessionTermination`, `.disableHideApplication`.
- Allowed for exam mode only: `[.hideDock, .hideMenuBar]` to remove distractions, restored on dismiss in a `defer`. Because a `.screenSaver`-level panel already covers Dock and menu bar visually, presentation options are optional. Recommendation: skip them entirely; less surface for bugs.

---------------------------------------------------------------------------

## 4. When NOT to interrupt

Compose a `InterruptionGuard` returning `.allow / .defer(until:) / .deny(reason)`. Fail-open: errors => `.defer`.

### 4.1 Microphone and camera in use
- **Mic**: CoreAudio `kAudioDevicePropertyDeviceIsRunningSomewhere` on the default input device (`AudioObjectGetPropertyData`; add a property listener for changes). https://developer.apple.com/documentation/coreaudio/kaudiodevicepropertydeviceisrunningsomewhere [api]. True if any process (Zoom, Teams, Meet in browser, dictation) is capturing. LookAway relies on exactly this: its 1.12 meeting detection "relies solely on microphone activity", with per-app exclusions to cut false positives [web] https://alternativeto.net/news/2025/4/lookaway-1-12-adds-app-exclusions-from-meeting-detection-smarter-drag-handling-and-more
- **Camera**: CoreMediaIO `kCMIODevicePropertyDeviceIsRunningSomewhere` per device from `kCMIOHardwarePropertyDevices` via `CMIOObjectGetPropertyData`. Example of a working implementation: Sindre Sorhus' `is-camera-on` package (https://swiftpackageregistry.com/sindresorhus/is-camera-on) [web]. Caveats [web]: an Apple Forums report of the listener firing for unrelated apps on macOS 12 (https://developer.apple.com/forums/thread/697124); Camera Extension virtual cameras may not appear in `kCMIOHardwarePropertyDevices` (https://developer.apple.com/forums/thread/718128). Apple deliberately does not expose which app uses it (CVE-2022-32913 context: https://zh-cn.tenable.com/cve/CVE-2022-32913).
```swift
func isAnyCameraRunning() -> Bool {
    var addr = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
        mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal), mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
    var size: UInt32 = 0
    guard CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &addr, 0, nil, &size) == 0 else { return false }
    var ids = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
    var used = size
    guard CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &addr, 0, nil, size, &used, &ids) == 0 else { return false }
    return ids.contains { id in
        var a = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal), mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var running: UInt32 = 0; var sz = UInt32(MemoryLayout<UInt32>.size); var u: UInt32 = 0
        return CMIOObjectGetPropertyData(id, &a, 0, nil, sz, &u, &running) == 0 && running != 0
    }
}
```
- No TCC prompt is needed for these "is running" queries [api; unverified on 26]. `AVCaptureDevice.isInUseByAnotherApplication` is an alternative that needs a device object [api].
- Treat "mic running" as a meeting AND as "Tenaz's own dictation exercise" (exclude own PID by checking whether Tenaz holds an active `AVAudioEngine`).

### 4.2 Screen sharing / recording
- No single public "is screen being captured" API. Signals: (a) frontmost/running meeting app + mic on; (b) `CGWindowListCopyWindowInfo` for the system "Sharing" indicator windows is fragile [unverified]; (c) macOS 15+ shows a purple screen-recording menu bar indicator (no API). Pragmatic: treat meeting app running + mic/camera active as sharing-possible; also treat `screencaptureui`/QuickTime recording by process name via `NSWorkspace.runningApplications` as "recording" [unverified process names]. Never prompt for Screen Recording permission just to detect this.

### 4.3 Focus / Do Not Disturb
- Public: `INFocusStatusCenter.default.focusStatus.isFocused` (Intents framework) after `requestAuthorization`, needs `NSFocusStatusUsageDescription`. Returns only a Bool (and may be nil) and works on macOS 12+. https://developer.apple.com/documentation/intents/infocusstatuscenter [api; behavior on 26 unverified].
- Reading `~/Library/DoNotDisturb/DB/Assertions.json` is a known hack requiring Full Disk Access; avoid. [unverified]
- Policy: if Focus is on, defer (this respects work meetings which often set Focus), but let the learner choose "Tenaz ignores Focus" since a learning gate during a self-set "Study" Focus is desired. Offer a Shortcuts Focus filter later [idea].

### 4.4 Full-screen presentations and video
- Power assertions: `IOPMCopyAssertionsByProcess` shows `PreventUserIdleDisplaySleep` / `NoDisplaySleepAssertion` held by Keynote/PowerPoint/Zoom/Teams/Meet/Netflix/etc. https://developer.apple.com/documentation/iokit/1557113-iopmcopyassertionsbyprocess [api]. This is the best generic "the user is presenting or watching video" signal and requires no permission. Distinguish Tenaz's own assertions.
- Frontmost app full screen: compare `CGWindowListCopyWindowInfo` window bounds of the frontmost app's PID to its screen's frame (owner PID and bounds are available without Screen Recording permission; titles are not) [api]. Or `NSRunningApplication.activationPolicy` + `NSWorkspace.frontmostApplication` bundle ID in a user list (zoom.us `us.zoom.xos`, Teams `com.microsoft.teams2`, Keynote `com.apple.iWork.Keynote`, Webex, Slack huddles `com.tinyspeck.slackmacgap`) [bundle IDs partly unverified: check with `osascript -e 'id of app "zoom.us"'`].

### 4.5 Calendar
EventKit: macOS 14+ `EKEventStore.requestFullAccessToEvents()`, plist key `NSCalendarsFullAccessUsageDescription`. https://developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoevents(completion:) [api]. Query `predicateForEvents(withStart:end:calendars:)`, treat any non-all-day, non-declined event overlapping `now ... now+10min` (and with attendees or a video URL) as a meeting. Tivra already reads the calendar (see Tivra's capture spec); Tenaz reads its own EventKit access, no Tivra dependency. Add a 5-minute pre-meeting buffer and a post-meeting grace (as LookAway does: "grace period after calls") [web] https://lookaway.app/docs/introduction

---------------------------------------------------------------------------

## 5. Hotkeys, menu bar, notifications, login item

- **Global hotkey**: Carbon `RegisterEventHotKey` still works on macOS 26, is sandbox-safe and does NOT need Accessibility permission [api]. Wrapper: `sindresorhus/KeyboardShortcuts` (https://github.com/sindresorhus/KeyboardShortcuts) gives a SwiftUI `Recorder`, user-customizable shortcuts and UserDefaults persistence [api; version unverified]. `NSEvent.addGlobalMonitorForEvents` needs Accessibility/Input Monitoring and cannot swallow keys; do not use it for the kill switch.
  ```swift
  extension KeyboardShortcuts.Name { static let killOverlays = Self("killOverlays", default: .init(.escape, modifiers: [.command, .option, .control])) }
  KeyboardShortcuts.onKeyUp(for: .killOverlays) { GateController.shared.dismissAll(reason: .killSwitch) }
  ```
- **MenuBarExtra** (SwiftUI, macOS 13+): `MenuBarExtra("Tenaz", systemImage: "bolt.fill") { ... }.menuBarExtraStyle(.window)`. https://developer.apple.com/documentation/swiftui/menubarextra [api]. Known gotchas: no programmatic open/close in the pure-SwiftUI API (use `NSStatusItem` for more control), `.window` style panel may not accept text focus without `NSApp.activate`. Tenaz already plans an `NSStatusItem` (DECISIONS). Always show a mascot-state icon and a "Pause overlays 1h" item.
- **Notifications**: `UNUserNotificationCenter` with `UNNotificationCategory` + `UNNotificationAction` (e.g. "Again / Good / Easy" for a word review) so the learner can answer from the banner without an overlay. https://developer.apple.com/documentation/usernotifications/unnotificationaction [api]. Time-sensitive interruption level (`.timeSensitive`) can break through Focus but needs a capability entitlement; keep `.active`. Text input actions: `UNTextInputNotificationAction` (type the translation in the banner). Banners are the "soft" tier below the overlay tier.
- **Login item**: `SMAppService.mainApp.register()` (macOS 13+), status via `.status` (`.enabled / .requiresApproval`), then deep link `SMAppService.openSystemSettingsLoginItems()`. https://developer.apple.com/documentation/servicemanagement/smappservice [api]. Works for non-sandboxed apps. For resilience also add a tiny `LaunchAgent` plist via `SMAppService.agent(plistName:)` that relaunches Tenaz if it dies (KeepAlive) [api] - but careful: it conflicts with "must survive a force-quit => NO" in DECISIONS rule 2. Therefore **do not KeepAlive**; plain login item only.

---------------------------------------------------------------------------

## 6. Anti-cheat signals (exam mode)

Reality check first: nothing on macOS can prove the learner didn't use another device or their own memory of an LLM. Goal = raise friction and flag, then rely on consequence design (an exam that is also random/personal: "write about yesterday's meeting" is hard to cheat, and AI-generated text is detectable by the learner's own history). Tivra owns app-level blocking; Tenaz only asks it (read-only integration).

| Signal | API | Notes |
|---|---|---|
| Frontmost app change | `NSWorkspace.shared.notificationCenter` `.didActivateApplicationNotification`, `userInfo[.applicationKey] as? NSRunningApplication` | no permission. Log bundle ID + timestamp during exam; flag any non-Tenaz app. [api] |
| App launch/terminate | `.didLaunchApplicationNotification` | detect ChatGPT etc. launched mid-exam. |
| Focus loss | `NSWindow.didResignKeyNotification`, `NSApplication.didResignActiveNotification` | count + duration of focus loss. |
| Paste block | subclass `NSTextView`: override `paste(_:)`, `pasteAsPlainText(_:)`, `pasteAsRichText(_:)`, `readSelection(from:)`, `performDragOperation(_:)` -> false, `registerForDraggedTypes([])` | also disable Services and the Edit menu paste item (validate `validateUserInterfaceItem`). Cmd-V still arrives via `performKeyEquivalent`; override to swallow. [api] |
| Clipboard change | `NSPasteboard.general.changeCount` polled at 2 Hz | change during exam = flag (copying from AI/translator in another window). |
| Keystroke bursts | In `NSTextView.insertText` / `shouldChangeTextIn`: record `(timestamp, deltaChars)`; flag deltas > ~8 chars in one event that are not IME/autocomplete, or sustained WPM > ~150 with zero backspaces | pure in-app, no permission. Use the learner's own baseline from typing sessions (median interkey interval, backspace rate) and compare. [design; thresholds unverified] |
| AI apps running | `NSWorkspace.runningApplications` bundle IDs | candidates [unverified, confirm with `osascript -e 'id of app "ChatGPT"'`]: ChatGPT `com.openai.chat`, Claude `com.anthropic.claudefordesktop`, Perplexity `ai.perplexity.mac`, DeepL `com.linguee.DeepLCopyTranslator`, Grammarly Desktop `com.grammarly.ProjectLlama`; also Codex/Cursor/terminal apps (`com.apple.Terminal`, `com.googlecode.iterm2`) since the learner runs Claude Code. |
| AI sites in browser | AppleScript to frontmost browser tab URL | Safari: `tell application "Safari" to get URL of current tab of front window`; Chrome-family: `tell application "Google Chrome" to get URL of active tab of front window`. Requires **Automation (Apple Events) TCC consent per target browser** and `NSAppleEventsUsageDescription`; Arc and other newer browsers' scripting support **[unverified]**. Match host against list: chatgpt.com, claude.ai, perplexity.ai, translate.google.com, deepl.com, gemini.google.com, copilot.microsoft.com, grammarly.com, quillbot.com. Execute via `NSAppleScript` off the main thread, poll at 1 Hz only in exam. |
| Screen content | `CGPreflightScreenCaptureAccess()` / ScreenCaptureKit | requires Screen Recording permission; macOS 15+ re-asks periodically [web-less; unverified]. Needed only to read window titles of other apps. **Avoid**; use URL + bundle IDs instead. |
| Strongest layer | Tivra | Tenaz asks Tivra (read-only) whether its AI blocklist is active for the exam window and records Tivra's block log for the exam interval. Exam refuses to start if Tivra is unreachable unless the learner picks "integrity: self-reported". |

Exam flow: pre-flight (Tivra active, no AI app running, browser tabs checked, Focus on, notifications muted) -> fullscreen panel -> continuous monitor -> result stores `integrityScore` and flags; a flagged exam counts but is labeled "unverified" and does not unlock the next difficulty. Escape hatch: "Abort exam" (penalty, never trapped).

---------------------------------------------------------------------------

## 7. On-device speech

- **New API (macOS 26 / iOS 26)**: `Speech` framework `SpeechAnalyzer` + modules `SpeechTranscriber` (long-form, dictation-grade) and `DictationTranscriber`; models are managed by the system and downloaded via `AssetInventory`. WWDC25 session "Bring advanced speech-to-text to your app with SpeechAnalyzer" (https://developer.apple.com/videos/play/wwdc2025/277/ [api; session number unverified]). AssetInventory page lists macOS 26.0 minimum (https://developer.apple.com/documentation/speech/assetinventory.md) [web].
- Sketch (names per third-party guides, verify against SDK) [web: https://dev.to/arshtechpro/wwdc-2025-the-next-evolution-of-speech-to-text-using-speechanalyzer-6lo, https://dev.to/simple_memo/ios-26s-speechanalyzer-on-a-live-mic-the-5-things-the-docs-dont-tell-you-2ng5]:
```swift
let locale = Locale(identifier: "en-US")
let transcriber = SpeechTranscriber(locale: locale,
    transcriptionOptions: [], reportingOptions: [.volatileResults],
    attributeOptions: [.audioTimeRange, .transcriptionConfidence])  // both cases exist on ResultAttributeOption (macOS 26.0+)
if let req = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
    try await req.downloadAndInstall()          // before using the locale (ordering gotcha in guides)
}
let analyzer = SpeechAnalyzer(modules: [transcriber])
// feed AVAudioPCMBuffer converted to analyzer's best format via an AsyncStream<AnalyzerInput>
for try await r in transcriber.results { r.isFinal ? commit(r.text) : preview(r.text) }
```
- **Accuracy [web]** (https://www.gigazine.net/gsc_news/en/20260714-apple-speech-analyzer-benchmark/): an Inscribe LibriSpeech test reports about 2.12% WER clean / 4.56% noisy for SpeechAnalyzer vs 3.74% / 7.95% for Whisper Small, and legacy `SFSpeechRecognizer` 9.02% / 16.25% (LibriSpeech test-clean 2,620 clips / test-other 2,939 clips, M2 Pro, run by the Inscribe team; confirmed on the Gigazine page); MacStories measured it faster than Whisper Large-v3 (https://9to5mac.com/2025/06/18/apple-devices-offer-amazing-speech-to-text-transcription-in-developer-betas-shows-test) [speed claim not re-checked this pass: **[unverified]**]. Caveats: vendor benchmark, read clean speech, native speakers, not B1 accented learners; no independent accent test found. **For the learner the risk is the opposite of usual**: a good recognizer "auto-corrects" mispronounced words into the right ones, so transcription success != correct pronunciation. Hidden upside for dictation exercises, hidden danger for pronunciation scoring.
- `SFSpeechRecognizer` remains available (`requiresOnDeviceRecognition = true`) as fallback for older locales; 1-minute limit applies to server mode only. [api]
- **Pronunciation assessment options**: Apple provides no pronunciation score API [api; I found none]. Options: (1) minimal pairs exercises with a transcript-must-match target + low-confidence words flagged; (2) per-word timing/gaps from `audioTimeRange` for fluency (pause length, words per minute); (3) send the audio's transcript + target to Claude for feedback (text only, can't hear phonemes); (4) heavier: forced-alignment/GOP scoring with a wav2vec2 phoneme model in CoreML **[unverified, research project, defer]**; (5) Azure Pronunciation Assessment is an API/key service and violates local-only/no-API rules. Recommendation: ship (1)+(2), call it "clarity", not "accent score".
- Permissions: `NSSpeechRecognitionUsageDescription`, `NSMicrophoneUsageDescription`, and entitlement `com.apple.security.device.audio-input` only if hardened-runtime. [api]

---------------------------------------------------------------------------

## 8. Neural TTS

- **AVSpeechSynthesizer**: `AVSpeechSynthesisVoice.speechVoices()` lists voices with `quality` `.default/.enhanced/.premium`; premium/enhanced voices must be downloaded in System Settings > Accessibility > Spoken Content > System Voice > Manage Voices. https://developer.apple.com/documentation/avfaudio/avspeechsynthesisvoice [api]. Pick the best English voice by `quality`, prefer `en-US` and `en-GB` (The learner's meetings: check accents). On macOS 26, Siri-grade voices may appear; whether apps can use them via AVSpeechSynthesizer is **[unverified]**. Personal Voice is irrelevant (and a privacy bump). Also `AVSpeechSynthesizer.write(_:toBufferCallback:)` gives buffers for caching to disk [api]. Quality: acceptable, noticeably less natural than neural models for long sentences.
- **Kokoro (82M, Apache-2.0 weights)** [web]:
  - FluidAudio (CoreML, Apple Neural Engine): `import FluidAudioTTS`, SPM product `FluidAudioWithTTS` (repo `FluidInference/FluidAudio`), `let m = TtSManager(); try await m.initialize(); try await m.synthesize(text:)` (the `TtSManager` spelling is as printed in the docs; `initialize()` is required first; Kokoro renders the whole utterance before playback, so pre-render and cache); model `FluidInference/kokoro-82m-coreml`; **phonemization uses eSpeak-NG (GPL-3.0)**, a licensing issue only if Tenaz is distributed; for personal use fine. https://docs.fluidinference.com/tts/kokoro
  - `mlalma/kokoro-ios` (KokoroSwift, MLX Swift): macOS 15+, last push around May 2025 so possibly stale. https://swiftpackageregistry.com/mlalma/kokoro-ios
  - Standalone CoreML conversion claims 2x faster than MLX (author's own benchmark): https://huggingface.co/mattmireles/kokoro-coreml ; soniqo notes `.cpuAndGPU` fallback when ANE output is wrong: https://soniqo.audio/guides/kokoro
- Recommendation: Phase 1 AVSpeech premium voice; Phase 2 FluidAudio/Kokoro behind a `Speaker` protocol, pre-render the vocabulary deck audio once and cache `.m4a` in Application Support (so the overlay is instant and no model runs at unlock time).

---------------------------------------------------------------------------

## 9. Apple Foundation Models framework

- On-device ~3B model, `import FoundationModels`, `SystemLanguageModel.default.availability` (check `.available`; unavailable reasons: Apple Intelligence off, device ineligible, model not ready), `LanguageModelSession(instructions:)`, `respond(to:)`, `streamResponse`, tools, and **guided generation** via `@Generable` structs with `@Guide` constraints. https://developer.apple.com/documentation/foundationmodels [api]
- **Hard limit: 4,096 tokens per session** covering instructions + prompts + tool schemas + @Generable schemas + outputs; overflow throws `GenerationError.exceededContextWindowSize`; ~3-4 Latin chars per token; `SystemLanguageModel.contextSize` and `tokenCount(for:)` were added in 26.4 and are back-deployed (TN3193 revision 2026-03-31; the error case is `.exceededContextWindowSize`) [web] https://developer.apple.com/tutorials/data/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window.md and https://infoq.com/news/2026/03/apple-foundation-models-context.
```swift
@Generable struct WordFeedback {
  @Guide(description: "true if the learner's sentence uses the word with correct meaning") var correctUse: Bool
  @Guide(description: "one short correction, max 15 words") var fix: String
  @Guide(.anyOf(["grammar","vocabulary","spelling","none"])) var errorType: String
}
let s = LanguageModelSession(instructions: "You grade B1 English sentences. Be brief.")
let r = try await s.respond(to: "Word: 'deadline'. Sentence: \(text)", generating: WordFeedback.self)
```
- Suitability for Tenaz: good for instant, offline, free micro-tasks: grade a one-sentence word use, give a hint, produce a cloze distractor, rephrase for a flashcard. A fresh session per item keeps within 4k. Weak for: paragraph-level CEFR scoring, TOEFL-rubric essay scoring, long-document recommendations (small model, quality variance; no published CEFR accuracy [unverified]). Keep a deterministic fallback when `availability != .available`. Route: Foundation Models (sub-second, hints) -> Claude CLI (rich feedback, essays, exam grading, async).
- Requires Apple Intelligence enabled and English supported (OK); behavior on the learner's specific Mac is a spike item.

---------------------------------------------------------------------------

## 10. Launching `claude` from a non-sandboxed GUI app

Facts from docs [web]: headless flags `-p`, `--output-format stream-json`, `--verbose`, `--include-partial-messages`; `system/api_retry` events are emitted on retryable errors. https://code.claude.com/docs/en/headless.md and CLI reference https://docs.anthropic.com/en/docs/claude-code/cli-reference.

Pitfalls and design:
- GUI apps launched by launchd/Finder have a minimal `PATH` and no shell profile: use absolute `URL(fileURLWithPath: "~/.local/bin/claude")` (DECISIONS rule 4), fall back to resolving once via `/bin/zsh -lc 'command -v claude'` and caching. Verified: the native installer places a launcher symlink at `~/.local/bin/claude` (into `~/.local/share/claude/versions/`); Homebrew installs elsewhere, so keep the resolve-once fallback. The `claude` binary is a native executable (the npm package just links the same binary) but may spawn helpers needing `PATH` containing `/usr/bin:/bin:/opt/homebrew/bin`: set explicitly.
- Env: copy `ProcessInfo.processInfo.environment`, **remove `ANTHROPIC_API_KEY`** and `ANTHROPIC_AUTH_TOKEN`, keep `HOME` (credentials come from the claude.ai login in Keychain/`~/.claude`), set `NO_COLOR=1`, `CI=1`.
- Close stdin (`standardInput = FileHandle.nullDevice`) or the CLI may wait for input.
- Run in an empty scratch `currentDirectoryURL` (Application Support/Tenaz/claude-cwd) so it doesn't load a project's CLAUDE.md or tools. Restrict tools so grading calls never touch files: `--tools ""` disables all built-in tools (verified, https://code.claude.com/docs/en/cli-reference.md); `--allowedTools` only auto-approves, it does not restrict. `--max-turns` exists but "exits with an error when the limit is reached", so treat that exit as a handled outcome. Add `--no-session-persistence` so grading calls do not litter `~/.claude` transcripts. **Do NOT use `--bare`**: bare mode never reads OAuth/keychain credentials and needs an API key, which violates the subscription-only rule. Structured output: `--output-format json --json-schema '<schema>'` exists (verified) and returns a `structured_output` field (absent if the run ended without valid output, so check for it); still validate with `Codable`. Note `-p` runs default to Manual permission mode (v2.1.302+), so any tool call that needs approval is denied.
- Streaming: `--output-format stream-json --verbose [--include-partial-messages]` emits one JSON object per line: `system` (init), `stream_event` (deltas, `text_delta`), `assistant`, `result` (final, with `is_error`, `result`, cost/usage). Parse line by line with `JSONDecoder` into an enum with `.unknown` fallback (schema evolves).
- Timeouts: `withThrowingTaskGroup` racing the process against `Task.sleep`; on timeout `process.interrupt()` (SIGINT), then `terminate()` after 2 s; also terminate on app quit.

```swift
actor ClaudeRunner {
    func run(prompt: String, timeout: Duration = .seconds(60)) -> AsyncThrowingStream<ClaudeEvent, Error> {
        AsyncThrowingStream { cont in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "~/.local/bin/claude")
            p.arguments = ["-p", prompt, "--output-format", "stream-json", "--verbose", "--tools", "", "--no-session-persistence", "--max-turns", "1"]
            var env = ProcessInfo.processInfo.environment
            env["ANTHROPIC_API_KEY"] = nil; env["ANTHROPIC_AUTH_TOKEN"] = nil
            env["PATH"] = "~/.local/bin:/opt/homebrew/bin:/usr/bin:/bin"
            p.environment = env
            p.currentDirectoryURL = Paths.claudeScratch
            p.standardInput = FileHandle.nullDevice
            let out = Pipe(), err = Pipe()
            p.standardOutput = out; p.standardError = err
            let task = Task {
                do {
                    try p.run()
                    for try await line in out.fileHandleForReading.bytes.lines {
                        if let e = ClaudeEvent(jsonLine: line) { cont.yield(e) }
                    }
                    p.waitUntilExit()
                    p.terminationStatus == 0 ? cont.finish() : cont.finish(throwing: ClaudeError.exit(p.terminationStatus))
                } catch { cont.finish(throwing: error) }
            }
            let killer = Task { try? await Task.sleep(for: timeout); if p.isRunning { p.interrupt() } }
            cont.onTermination = { _ in task.cancel(); killer.cancel(); if p.isRunning { p.terminate() } }
        }
    }
}
```
- Ensure Claude features degrade gracefully: queue requests while offline/limit-hit; surface "usage limit" as a state, never a blocking error.
- Not sandboxed => no entitlement needed; Hardened Runtime without `com.apple.security.cs.allow-jit` is fine since we exec an external binary.

### Persistence: SwiftData vs GRDB
- Recommendation: **GRDB** (https://github.com/groue/GRDB.swift). Reasons [judgment]: `TenazCore` must be a pure-Swift package testable on CLI (SwiftData ties models to macros and `ModelContainer`, awkward in a logic library); the review log is append-heavy and needs SQL queries (due cards, retention stats, streaks) and explicit migrations (`DatabaseMigrator`); `DatabasePool` (WAL) allows reads from the UI while the scheduler writes, and the file can be opened by external tools (Tivra, backup, `sqlite3`, Claude) - useful because the learner's other apps already read local data. SwiftData wins only for quick SwiftUI `@Query` binding and CloudKit sync, neither required (data stays local). Wrap with `ValueObservation` for live UI. Concurrency model fits Swift 6 (`Sendable` record structs).
- Store FSRS state per card (due, stability, difficulty, reps, lapses) + append-only `review_log` table; keep a `schema_version` and export/import JSON for safety.

---------------------------------------------------------------------------

## 11. Break/overlay apps: copy their escape hatches

- **LookAway** [web] https://lookaway.app/docs/introduction , changelog https://mac.softpedia.com/progChangelog/LookAway-Changelog-143376.html : skip policy configurable as "skip anytime / skip after a delay / lock (cannot skip)", an option to hide the skip button; snooze from the break screen by 1 or 5 minutes not counted as a skip (1.12); menu bar "pause for X minutes then auto-resume"; keyboard shortcut for "postpone break 1 min"; meeting detection by mic with app exclusions, a notification on entering a meeting with "ignore meeting detection this cycle", and a grace period after long calls. Blog on making reminders less annoying: https://lookaway.app/blog/2025/04/07/how-i-made-break-reminders-less-annoying
- **Stretchly** [web] https://github.com/hovancik/stretchly : postpone once (2 min mini-break, 5 min long break) and skip available after a delay or by `Cmd/Ctrl+X`; a **strict mode** where breaks cannot be ended early (opt-in); idle detection pauses breaks after 5 idle minutes.
- **Time Out, Pandan**: I could not retrieve their docs this session. **[unverified]** Time Out is known for "Skip/Postpone" buttons and an optional "Do not allow skip" setting; Pandan for a menu bar timer with simple pause. Check their sites before citing.

Escape ladder for Tenaz (copy + tighten):
1. **Snooze** 1/5/15 min (free, limited N/day, shown on the panel and via hotkey `Cmd+Opt+S`).
2. **Skip** after a short delay (e.g. 10 s countdown, button appears), with a "penalty" tier (lose small XP / mascot heart) - the DECISIONS rule "emergency skip with a penalty, not a lockout".
3. **Strict mode** per overlay type (opt-in like Stretchly), but still always bypassable by kill switch (Ctrl+Opt+Cmd+Esc), `defaults write`, DISABLE file, and max on-screen time watchdog.
4. **Auto-defer** on meeting signals (section 4) with an on-screen "I'm in a meeting" one-click that lasts 60 min (LookAway's "ignore for this cycle").
5. **Idle detection**: don't show a gate when `CGEventSource.secondsSinceLastEventType(.combinedSessionState, ...)` is large (the user isn't there) [api]; queue instead of stacking.
6. A visible "Why am I seeing this?" line and a log of every gate (when/why/outcome) for tuning.

---------------------------------------------------------------------------

## 12. Spike list (do these before building)

1. Panel over a full-screen presentation Space on a secondary display (level, behavior, key focus, typing) - section 1.
2. Which of `sessionDidBecomeActive`, `screensDidWake`, `com.apple.screenIsUnlocked` fire on lock/unlock on macOS 26.
3. CMIO + CoreAudio "running somewhere" during a real Teams/Meet call, including browsers.
4. `INFocusStatusCenter` authorization flow and values on macOS 26.
5. `IOPMCopyAssertionsByProcess` readings for Keynote/Zoom/Teams/YouTube.
6. SpeechAnalyzer with a B1 accent sample: WER on 20 dictated sentences, check what confidence/attribute options exist.
7. `FoundationModels` availability and latency for `WordFeedback`.
8. `claude -p --output-format stream-json` from a GUI-launched process: PATH, keychain access, stdin closure.
9. AppleScript URL reading from Arc/Chrome/Safari with Automation prompts.
10. Verify bundle IDs of AI apps on the learner's Mac with `osascript -e 'id of app "..."'`.

## Sources cited
- https://alternativeto.net/news/2025/4/lookaway-1-12-adds-app-exclusions-from-meeting-detection-smarter-drag-handling-and-more
- https://mac.softpedia.com/progChangelog/LookAway-Changelog-143376.html
- https://lookaway.app/docs/introduction
- https://github.com/hovancik/stretchly
- https://developer.apple.com/forums/thread/697124 , https://developer.apple.com/forums/thread/718128
- https://swiftpackageregistry.com/sindresorhus/is-camera-on
- https://www.gigazine.net/gsc_news/en/20260714-apple-speech-analyzer-benchmark/
- https://developer.apple.com/documentation/speech/assetinventory.md
- https://developer.apple.com/tutorials/data/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window.md
- https://docs.fluidinference.com/tts/kokoro , https://huggingface.co/mattmireles/kokoro-coreml , https://soniqo.audio/guides/kokoro
- https://code.claude.com/docs/en/headless.md
- https://chromium.googlesource.com/chromium/src/+/e8a107c96/ui/base/idle/idle_mac.mm

## Verification

Checked 2026-10-22 against primary sources. Apple pages were read through the `developer.apple.com/tutorials/data/documentation/...` JSON/markdown mirror because the HTML pages are JS-rendered.

| # | Claim | Verdict | Source |
|---|---|---|---|
| 1 | Foundation Models context window is 4,096 tokens per session; overflow throws `exceededContextWindowSize`; `contextSize`/`tokenCount(for:)` exist | Confirmed; corrected: those two APIs arrived in 26.4 (back-deployed), not "newer SDKs" | https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window |
| 2 | `NSApplication.presentationOptions` combination rules (`hideMenuBar` needs a Dock option; disable* options) | Corrected: `hideMenuBar` requires `.hideDock` specifically (not `.autoHideDock`); `disableForceQuit`/`ProcessSwitching`/`SessionTermination` require a Dock option; violations raise `NSInvalidArgumentException`. The "app must be frontmost" recollection is unverified. | https://developer.apple.com/documentation/appkit/nsapplication/presentationoptions-swift.struct |
| 3 | `NSApp.activate()` is macOS 14+, replaces `activate(ignoringOtherApps:)`, activation can be refused (cooperative activation) | Confirmed (macOS 14.0+, "doesn't guarantee"; `yieldActivation(to:)` is the other half) | https://developer.apple.com/documentation/appkit/nsapplication/activate() |
| 4 | `.canJoinAllSpaces` and `.moveToActiveSpace` are mutually exclusive and "throws if combined" | Unverifiable (Apple's pages describe opposite intents but do not say it throws); reworded to "never combine", throw claim marked [unverified] | https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct |
| 5 | Window level values: `.popUpMenu` 101, `.screenSaver` 1000, `CGShieldingWindowLevel()` about 2147483628 | 101 and 1000 confirmed (mirror of `CGWindowLevel.h`); 2147483628 unverified, now marked so | https://docs.rs/crate/rio-window/0.5.12/source/src/platform_impl/macos/ffi.rs ; https://developer.apple.com/documentation/appkit/nswindow/level-swift.struct/screensaver |
| 6 | `SpeechTranscriber` is macOS 26.0+, initializer takes locale + transcription/reporting/attribute option sets, `audioTimeRange` available | Confirmed; corrected: `.transcriptionConfidence` also exists in `ResultAttributeOption` (the old "[unverified]" is resolved and the sketch now uses it). The WWDC session number 277 remains unchecked. | https://developer.apple.com/documentation/speech/speechtranscriber |
| 7 | SpeechAnalyzer WER 2.12% clean / 4.56% noisy vs Whisper Small 3.74% / 7.95% | Confirmed (Inscribe, LibriSpeech, M2 Pro); added SFSpeechRecognizer 9.02% / 16.25%. The "faster than Whisper Large-v3" MacStories claim was not re-fetched: [unverified]. Vendor benchmark of native readers, as the file already cautions. | http://gigazine.net/gsc_news/en/20260714-apple-speech-analyzer-benchmark/ |
| 8 | Kokoro 82M, Apache-2.0; FluidAudio phonemization via eSpeak-NG GPL-3.0; `TtSManager().synthesize(text:)` | Confirmed Kokoro 82M and Apache-2.0; GPL-3.0 eSpeak-NG confirmed on FluidAudio docs. Corrected the API: `initialize()` must be called first, import is `FluidAudioTTS`, SPM product `FluidAudioWithTTS`; `TtSManager` spelling matches the docs. | https://huggingface.co/hexgrad/Kokoro-82M ; https://docs.fluidinference.com/tts/kokoro |
| 9 | Headless flags: `-p`, `--output-format stream-json` needs `--verbose`, `--include-partial-messages`, `system/api_retry` events | Confirmed (docs example always pairs stream-json with `--verbose`; api_retry fields documented) | https://code.claude.com/docs/en/headless.md |
| 10 | `--max-turns`, tool restriction flags, JSON schema option (previously [unverified]) | Confirmed and corrected: `--max-turns` exists but errors out when hit; `--allowedTools` only auto-approves, real restriction is `--tools ""`; `--json-schema` exists and returns `structured_output`. Sample code args updated. | https://code.claude.com/docs/en/cli-reference.md |
| 11 | Claude binary at `~/.local/bin/claude`, "node/native" | Confirmed path (native installer symlink into `~/.local/share/claude/versions/`); corrected "node": it is a native binary. Homebrew installs elsewhere. | https://code.claude.com/docs/en/setup.md |
| 12 | EventKit `requestFullAccessToEvents` macOS 14+, key `NSCalendarsFullAccessUsageDescription` | Confirmed | https://developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoevents(completion:) |
| 13 | `INFocusStatusCenter` macOS 12+ with `requestAuthorization` | Confirmed on availability and API; the `NSFocusStatusUsageDescription` key is not named on the Apple page (widely used, still [api]). Behavior on macOS 26 still needs the spike. | https://developer.apple.com/documentation/intents/infocusstatuscenter |
| 14 | `com.apple.screenIsUnlocked` works on Tahoe | Unverifiable (search found only long-standing Chromium usage, no Tahoe confirmation); stays [unverified], spike #2 | https://chromium.googlesource.com/chromium/src/+/e8a107c96/ui/base/idle/idle_mac.mm |

## Gaps found in verification

- **`--bare` breaks the subscription rule.** The docs say it is the recommended mode for scripted calls and will become the default for `-p`, but it never reads OAuth credentials or the keychain and wants `ANTHROPIC_API_KEY`. `ClaudeRunner` must never pass `--bare`, and the claude version pinned in tests should be re-checked when "bare by default for `-p`" ships (a future release could silently break Tenaz's login path; add a startup `claude auth status` check expecting `authMethod == "claude.ai"`).
- **`-p` permission default changed.** From v2.1.302 a `-p` run starts in Manual mode, so any tool call needing approval is denied. Grading prompts should disable tools (`--tools ""`) rather than rely on prompt wording, and add `--permission-prompts none` (v2.1.259+) if anything could ever wait on a prompt, since a hung child would stall the overlay pipeline.
- **Kill the child on SIGTERM semantics.** `claude -p` exits 143 on SIGTERM and records no result for the interrupted turn; SIGINT ends the turn cleanly. The runner's timeout path (interrupt then terminate) matches this, but the code should treat exit 143 and the `--max-turns` error exit as expected outcomes, not failures that trigger retries.
- **`SpeechTranscriber` availability is per device and locale.** Use `isAvailable`/`supportedLocales` and fall back to `DictationTranscriber` or `SFSpeechRecognizer`; the learner's Mac needs the spike before the dictation exercise is promised.
- **`SystemLanguageModel.contextSize` / `tokenCount(for:)`** (26.4) let the Foundation Models router measure prompts before sending instead of catching `exceededContextWindowSize`; use them in the `WordFeedback` path.
