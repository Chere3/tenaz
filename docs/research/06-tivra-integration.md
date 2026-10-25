# 06 - Tivra integration contract for Tenaz

Scope: read-only study of the source and schema of Tivra, the sibling focus-tracking app (nothing was edited or built). No web research was needed: every claim below comes from Tivra's own code and docs. Evidence tags: **[code]** read in the source or schema, **[unverified]** inferred, not exercised. Paths are relative to the Tivra macOS app source root unless absolute.

Everything in section 6 is a PROPOSAL. Nothing in Tivra was changed.

---

## 0. Executive summary (the five facts that drive every decision)

1. **Tivra has no loopback API for other apps.** Its only loopback listener is `127.0.0.1:4242`, which accepts HMAC-signed browser-extension events (`POST /events`) and nothing else [code: `CLAUDE.md`, `Sources/TivraCore/TivraEventReceiver.swift`]. The MCP server (4243) and the companion server (4244) bind **only to the Mac's Tailscale address** (a Tailscale 100.x address). If Tailscale is down, both vanish. Tenaz must treat them as optional.
2. **The best read-only channel for Tenaz is the SQLite file itself**: `~/Library/Application Support/Tivra/tivra.db` (WAL mode, plain SQLite, mode 0644, not encrypted - SQLCipher is not linked) [code: `Sources/TivraCore/DatabaseManager.swift`, `CLAUDE.md`]. It needs no tokens, no Tailscale and no Tivra patch. Tenaz is non-sandboxed (DECISIONS.md), so it can open it with `SQLITE_OPEN_READONLY`.
3. **The only supported way for another app to START a protection session is the companion server's `POST /v1/commands`** (kind `start`). It requires pairing as a "device" (HMAC), over the tailnet. It can pick `durationMin` (5-240) and a *category rule* (`blocking`), but **it cannot pass a list of apps/sites**. The apps/sites blocked are whatever is in the learner's single "Default Protection" block list [code: `PhoneCommandHandler.swift`, `ProtectionController.engage`].
4. **A typical default block list is not suitable for an exam**: it can block 22 App Store categories (almost everything, including `other`), has no blocked sites by default, and Tivra's only exempt app bundle prefix is `com.chere3.focusflow` [code: `ProtectionPolicy.fixedExclusions`]. A list session started for Tenaz would **quit Tenaz itself** and would **not block chatgpt.com/claude.ai in the browser**. So exam-time blocking needs either a learner-side config change or a small Tivra patch (section 6).
5. **Tivra does not classify AI or translator tools in any special way.** There is no AI/translator taxonomy; ChatGPT, Claude, DeepL, Google Translate are not in the seed rules. Activity data can contain them (e.g. `claude.ai`, `chatgpt.com`, `com.anthropic.claudefordesktop`), so verification works by matching bundle ids and domains **that Tenaz owns**, not by a Tivra category [code].

Bottom line for the contract:

| Feature | Possible today with zero Tivra change? | Recommended path |
|---|---|---|
| Verify after the exam that no AI/translator was in focus | **Yes** (read DB) | Direct read-only SQLite, Tenaz-owned deny list (section 4.2) |
| Request blocking during the exam | **Partly** (needs pairing + Tailscale + config edits; risks killing Tenaz) | Prefer Tenaz-side detection + proposed Tivra patch P1 (section 6) |
| Punishment: block fun apps until reviews are done | **Partly** (works only through the same weak mechanism) | Tenaz-owned overlay by default; Tivra block after patch P1 (section 5) |
| Report learning time | **No direct API**; indirect via classification of Tenaz's own window | Patch P2 (one seed rule), or the learner classifies once in Review (section 7) |

---

## 1. What read-only interfaces exist

### 1.1 SQLite database (recommended read channel)

- **Path** [code]: `~/Library/Application Support/Tivra/tivra.db` plus `tivra.db-wal` and `tivra.db-shm`. Debug variants (bundle `com.chere3.focusflow.dev`) use their own separate folders. Production is the folder `Tivra`. File name constant: `DatabaseManager.databaseFileName = "tivra.db"` [code].
- **Access**: open with `file:...tivra.db?mode=ro` or `SQLITE_OPEN_READONLY` and `PRAGMA query_only=1`. WAL readers need write access to the `-shm` file in the same directory (normal for the same macOS user). Tivra's own MCP server does exactly this (`MCPReadOnlyDatabase`, `Configuration.readonly = true`) [code: SPEC section 8.2]. Never take locks for long; read, close.
- **Not encrypted** [code: `CLAUDE.md` "SQLCipher is not actually linked yet"]. If Tivra later enables SQLCipher, this channel breaks; Tenaz must degrade to "unverifiable" (section 4.4).
- **Main tables** (from the schema) [code]:

| Table | Use for Tenaz |
|---|---|
| `tivra_events` (`id, type, ts ms, source, payload BLOB(JSON), device_id, tz_offset_min`) | Raw stream. Types seen: `app_active`, `window_focus`, `capture_tick` (every 60 s), `idle_start/idle_end`, `tab_active`, `heartbeat` (browser extension), `system_state`, `protection_engaged/released`, `session_*`, `device_usage` / `device_screen` (Android) |
| `activity_spans` (`start_ts, end_ts, kind active/passive/idle/away/paused/excluded, source, bundle_id, app_name, title, url, domain, project_cwd, category, method, band, device_id`) | Resolved intervals, easiest to query |
| `minute_ledger` | One row per minute: planned vs observed category, seconds per state, verdict |
| `category_rules` (`kind bundle/domain/url_prefix/title_regex/context_*, pattern, category, origin seed/registry/user/review`) | Classification rules |
| `exclusions` (`bundle/domain/title_regex/path_prefix` with mode `drop/redact/no_frames/hide_remote`) | Things Tivra never records or hides |
| `source_health` (`source, state ok/degraded/no_permission/off, last_ok_ts`) | Is capture trustworthy right now? Sources seen: `capture_tick`, `window_titles`, `browser_url.<browser>`, `browser_url.safari (off)`, `calendar`, `knowledgec`, ... |
| `sessions`, `session_templates`, `protection_profiles`, `protection_profile_apps`, `protection_profile_domains`, `release_attempts`, `active_release_cooldown` | Protection state and history |
| `devices` | Paired companion devices (e.g. `mac-local` and paired phones) |
| `plan_blocks`, `day_reports`, `access_audit` | Calendar plan, adherence, remote access log |

- **Event payload examples** [code]:
  - `app_active`: `{"bundleIdentifier":"com.example.browser","localizedName":"Browser","processIdentifier":4001}`.
  - `window_focus`: `{"title":"Example video title","titleSource":"ax","redacted":false,"excluded":false,"bundleId":"com.example.browser","appName":"Browser","url":"https://www.example.com/watch","contextKey":"yt:video/EXAMPLE","domain":"www.example.com","pid":4001}`. This carries `url`/`domain` for the browser.
  - `capture_tick`: `{"audioOutRunning":true,"micRunning":false,"frontExcluded":false,"frontBundleId":"com.example.browser","mediaAssertionBundleId":"...","idleSeconds":7}`. This is the heartbeat Tenaz uses to prove capture was alive.
- **Timestamps** are Unix milliseconds. `activity_spans` is written by the live span builder with a short lag [code]. For verification, query `tivra_events` (immediate) and `activity_spans` (resolved), and wait at least 90 s after the exam ends before concluding.
- **Privacy caveat**: apps/sites in `exclusions` with mode `drop` are never written (seeded: 1Password, Bitwarden) [code]. `hide_remote` spans are hidden from MCP but visible in the file. Treat the file as the learner's private data; Tenaz stores only booleans and counts, never copies titles/URLs into its own DB (suggested rule, consistent with Tivra's own privacy stance).

### 1.2 Widget snapshot / App Group

- App Group `<TEAMID>.com.chere3.focusflow` (a `group.com.chere3.focusflow` variant may also exist on disk) [code: entitlements]. `WidgetSnapshotPublisher` writes `widget-snapshot.json` there every 60 s: today's active time, focus/deep blocks, context switches, top app/domain, headline [code: `CLAUDE.md`]. Without the App Group entitlement the file falls back to `~/Library/Caches/Tivra/`.
- Verdict: **do not use it**. It is aggregated (no per-window data) and the group container is entitlement-gated; a non-sandboxed Tenaz could still read the folder but gains nothing over the DB. Optionally useful as a cheap "Tivra is alive" hint (file mtime < 2 min).

### 1.3 MCP server (port 4243) - built for a remote agent client, awkward for Tenaz

- **Class**: `FocusFlow/Services/DeepCapture/TivraMCPServer.swift`; pure logic in `Sources/TivraCore/DeepCapture/Remote/` (`MCPServerCore`, `MCPTools`, `MCPAccessControl`).
- **Transport**: HTTP/1.1 `POST /mcp`, JSON-RPC 2.0, MCP "Streamable HTTP" minus SSE and sessions. Methods `initialize`, `tools/list`, `tools/call`; notifications get 202. Protocol versions 2024-11-05, 2025-03-26, 2025-06-18. `Connection: close`. A request with an `Origin` header gets 403 (F1d design).
- **Bind**: `requiredLocalEndpoint` = the Mac's `100.64.0.0/10` address on a `utun`, port `4243`, max 4 connections, 60 req/min, headers <= 8 KB, body <= 64 KB, response <= 256 KB [code]. **Not on loopback.**
- **Auth**: `Authorization: Bearer tivra_a_<64 hex>` (scope A) or `tivra_ab_<64 hex>` (scope AB). Tivra stores only the SHA-256 digest in the Keychain, so **a token can only be copied when it is generated** in Settings > Deep Capture > Remote reader [code: `MCPToken`, `MCPTokenVerifier`]. Five bad tokens in 10 minutes lock the server until the learner clears it. Peer IP must also be in `UserDefaults remoteReader.allowedPeers` (default `["100.x.y.z"]`, a single fixed peer). The switch `remoteReader.enabled` is off by default and requires Deep Capture on.
- **Tools** (all read-only, `readOnlyHint: true`):

| Tool | Tier | Args | Returns |
|---|---|---|---|
| `tivra_health` | A | none | version, Deep Capture state on/paused/off, last tick/activity, per-source state, active protected session, free disk, audit state |
| `tivra_adherence_day` | A | `date` `YYYY-MM-DD` | day report numbers |
| `tivra_adherence_range` | A | `from`, `to` (<= 62 days) | daily series |
| `tivra_blocks` | A | `date` | plan blocks without titles (with AB: `captured_title`) |
| `tivra_spans` | **B (AB token)** | `from`, `to` (<= 24 h), `category?`, `limit?` (<= 100), `cursor?` | spans with `captured_app`, `captured_title`, `captured_url`, `captured_domain`, `bundle_id`, `category`, `method`, `band`; `hidden` count |
| `tivra_minutes` | B | `from`, `to` (<= 24 h) | minute ledger as columns+rows |
| `tivra_access_log` | B | `from`, `to`, `limit?` | Tivra's audit of remote reads |

  Responses are wrapped: `{"content":[{"type":"text","text":"<envelope>"}],"isError":false}` with envelope `{"aviso":"...","data":{...}}`; free text lives under `captured_*` keys and is untrusted [code: SPEC 8.3, F1d].
- **There is no write tool.** Level C (OCR/frames) does not exist.
- **Why not use it from Tenaz**: (a) needs Tailscale up; (b) Tenaz would have to add its own tailnet IP (`100.x.y.z`) to `remoteReader.allowedPeers` and the learner would have to generate a third token and paste it into Tenaz's Keychain; (c) `hide_remote` filtering drops spans the learner marked private, which makes "nothing found" ambiguous; (d) it gives strictly less than the file. Use only as a fallback transport if the file ever becomes encrypted. **[unverified]**: that a same-host connection to the Mac's own tailnet IP arrives with that IP as `peer` (it should, since the kernel picks the interface address as source), so the allowlist entry would be `100.x.y.z`.

### 1.4 Companion server (port 4244) - the only command channel

- **Class**: `FocusFlow/Services/Companion/TivraCompanionServer.swift`, core in `Sources/TivraCore/Companion/CompanionServerCore.swift`, routes in `CompanionRoutes.swift`, contracts `docs/mobile/M0-M1-contract.md` and `M3-M4-contract.md` (sections 3-5, 10, 18).
- **Bind**: tailnet IP only, port `4244` (`CompanionProtocol.port`), never loopback/LAN [code: contract M0 section 2]. Switch `companion.enabled` (UserDefaults, off by default).
- **Pairing** (contract M0 section 3): The learner presses "Pair phone" in Settings > Devices; Tivra opens a window with an **8-digit single-use code, 5 minutes, 5 attempts**. `POST /v1/pair` (the only unsigned route) with body `{"v":1,"code":"48203917","deviceName":"Tenaz (Mac)","appVersion":"0.1.0","sdk":0}` returns `{"v":1,"deviceId":"android-<uuid>","secret":"<43 base64url chars>","serverTs":...,"macName":"..."}`. The peer must be in `100.64.0.0/10`. The device row has `kind='android'` (the registry only accepts that kind: `CompanionDevice.androidKind`), so Tenaz appears in the list as another "phone". The Mac keeps `last_ip` pinned; later requests from another IP get 403.
- **Signing every other request**: headers `X-Tivra-Device: android-<uuid>`, `X-Tivra-Timestamp` (epoch seconds, +-60 s), `X-Tivra-Nonce` (16 random bytes as 32 hex), `X-Tivra-Signature` = lowercase hex of `HMAC-SHA256(key = ASCII bytes of the secret string as received, message = METHOD + "\n" + path-with-query + "\n" + timestamp + "\n" + nonce + "\n" + rawBody)` [code: `LocalhostRequestAuthenticator.sign`, contract M0 section 4]. Anti-replay per device (120 s), 60 req/min per device, five bad signatures lock the device until the learner presses Unlock. Store the secret in Tenaz's Keychain.
- **Routes** [code: `CompanionRoutes.swift`]: `POST /v1/pair`, `POST /v1/unpair`, `GET /v1/health`, `GET /v1/state`, `GET /v1/events` (long-poll, 25 s), `POST /v1/commands`, `POST /v1/web/check`, `POST /v1/apps/classify`, `PUT /v1/apps/category`, `GET|PUT /v1/phone/packages`, `GET /v1/analytics/{overview,attention,patterns}`, `GET /v1/videos`, `GET /v1/plan/days`, `GET /v1/plan`, `POST /v1/plan/rebuild`, `GET /v1/sessions`, `POST /v1/capture/pause`, `POST /v1/capture/resume`, `GET|PATCH /v1/settings`, `GET /v1/review`, `POST /v1/review/{open,answer,resolve,approve,hide,correct}`, `POST /v1/usage/batch`.
- **Errors**: `{"error":"<code>","serverTs":<ms>}`; codes include `missing_auth, unknown_device, device_revoked, bad_signature, timestamp_out_of_range, nonce_replay, forbidden, device_locked, rate_limited, session_running, no_session, not_current, invalid_blocking, unknown_template, command_expired, command_mismatch, busy, server_disabled`.
- **State** (`GET /v1/state`): includes `session` (`id, trigger calendar|manual, reason, origin, mode, blocking, category, templateId, startTs, plannedEndTs, paused`), today's plan blocks (no titles), baseline counters, `settings.templates[]`. Titles, window titles and domains are never sent (privacy section 13.8 of the contract).
- **Dependency risk**: needs Tailscale up on the Mac. If `TailnetAddress.current()` returns nil, the controller reports "no tailnet" and nothing listens (re-checked every 60 s) [code: `RemoteReaderController`, `CompanionController`].

### 1.5 Loopback event receiver (4242)

- `POST http://127.0.0.1:4242/events`, headers `X-Tivra-Timestamp`, `X-Tivra-Nonce`, `X-Tivra-Signature`, HMAC key = the Tivra secret (Keychain; mirrored in `~/Library/Application Support/Tivra/native-host-secret.json` as `{"secret": "...", "savedAt": <epoch seconds>}`, mode 0600) [code].
- Accepts only extension event types and sources `chromium`, `firefox`, `safari`, `macos`; `calendar` and `android` sources and "Mac-only" event types are rejected [code: `TivraEventReceiver`]. Useless for commands. Not recommended for Tenaz: injecting fake events would pollute the learner's analytics.

---

## 2. Question (b): can Tenaz ask Tivra to block apps/sites for N minutes?

**Answer: technically yes, through one route, but with three serious gaps.**

### 2.1 The route

`POST http://100.x.y.z:4244/v1/commands` (host = current tailnet IP; read it from `GET /v1/health` pairing data or recompute it from `ifconfig utun*`), signed as in 1.4. Body [code: `PhoneCommandRequest`]:

```json
{
  "v": 1,
  "commandId": "<8-64 chars: ASCII letters, digits, '-'>",
  "kind": "start",
  "issuedTs": 1792727400000,
  "sessionId": null,
  "templateId": "study",
  "blocking": "list",
  "durationMin": 30,
  "local": null
}
```

- `kind` values: `start, end, extend, pause, resume, allow, timer_start, timer_pause, timer_stop, reopen_app, allow_app`.
- `durationMin` for `start` is 5-240; `extend` 5-120. Minimum block is therefore **5 minutes**, which fits every exam section (TOEFL sections are 18-60 min, so one `start` per section or one long start).
- `blocking` must satisfy `SessionBlocking.decode(x).encoded == x`: `"list"`, `"focus:<cat>"` (cat in escuela, trabajo, aprendizaje, proyectos, comunidad, finanzas, social, viajes), or `"block:<cat>,<cat>"` (those plus rutina). Anything else gives 422 `invalid_blocking`.
- `templateId` must exist: seeded ids are `deep_work` (90 min, profile-default), `admin` (45), `study` (60), `custom` (25) [code, column `default_duration_minutes`]. Note `study` and `admin` have no `protection_profile_id` (NULL), so it is [unverified] whether `blocking: "list"` with `templateId: "study"` falls back to `profile-default`; test before relying on it. Do **not** use `deep_work` when "Follow my calendar" is on: `launchFromPhone` turns that template into plan-scope mode (it ignores the block list) [code: `PomodoroViewModel.launchFromPhone`].
- Response 200: `{"v":1,"serverTs":...,"commandId":"...","result":"applied","sessionId":"<id>","state":{...}}`. Conflicts: 409 `session_running` if a manual session or Pomodoro is running; a calendar session is released (`manual_override`) and replaced. Commands older than 10 minutes by `issuedTs` get 410 `command_expired`. Replays with the same `commandId` + same body return the stored result; same id with a different body is 409 `command_mismatch`.
- End early: `{"kind":"end","sessionId":"<id>", ...}`; extend: `{"kind":"extend","sessionId":"<id>","durationMin":15}`.

### 2.2 Gap 1 - you cannot pass the list

The apps and sites blocked are those in the single profile `profile-default`:

- Apps (default profile): **22 category entries** (`public.app-category.business, developer-tools, education, entertainment, finance, games, graphics-design, healthcare-fitness, lifestyle, medical, music, news, photography, productivity, reference, social-networking, sports, travel, utilities, video, weather` and `tivra.app-category.other`) and zero individual bundle ids.
- Sites: **none** by default (`protection_profile_domains` is empty).
- The only remote way to change the list is `PATCH /v1/settings` with `protection.blockList.categories` (replaces all `category:` rows) and `protection.blockList.sites` (replaces the whole site list), which requires `If-Match` with the ETag from `GET /v1/settings` (428 without, 412 on mismatch) [code: `CompanionSettingsSchema`, `PhoneCommandHandler.apply`]. `protection.blockList.apps` (individual bundle ids) is **read-only** remotely. So Tenaz cannot add `com.anthropic.claudefordesktop` or `com.openai.chat` by bundle id. It *can* add sites like `chatgpt.com`, `claude.ai`, `deepl.com`, `translate.google.com`, but that edit is permanent and global until Tenaz restores it (read, remember, patch, then restore). A crash in between leaves the learner's list modified. That is poor hygiene for a "read-only, never leave a mess" integration.

### 2.3 Gap 2 - Tenaz would be killed by its own exam session

`ProtectionPolicy.decideBlockList` quits any regular app whose category is in the list, except a fixed list (`finder, dock, loginwindow, notificationcenterui, systemuiserver, windowmanager, systempreferences`) and bundle ids equal to or prefixed with `com.chere3.focusflow` [code: `ProtectionPolicy.isFixedExclusion`]. Tenaz (`com.chere3.tenaz`, presumably) falls under `education` or `other` and both are blocked in the learner's profile. **A list session would terminate Tenaz** (a soft `terminate()`, with `forceTerminate` only within 5 s of launch). Zero-patch workarounds, both on the learner's side:
 1. In Tivra Settings, untick the `Education` category from the block list, set Tenaz's `LSApplicationCategoryType` to `public.app-category.education`. (Loses blocking of other education apps; acceptable.)
 2. Or add a `PUT /v1/apps/category` override mapping Tenaz's bundle to a category that is not in the list - impossible today, because every `AppBlockCategory` value is in the list.

Browsers are never quit by category (`browserByCategory`); only websites are blocked in them, via the Chromium/Firefox extension. The browser extension reports via a `chromium` heartbeat [code].

### 2.4 Gap 3 - web blocking needs the extension and a site list; apps need a bundle list

- Site blocking in Chromium-family browsers works only through the Tivra extension and the `blockedSites` field of `WebProtectionSnapshot` (published when mode is `blockList` with non-empty `blockDomains`, or a category session with a rule) [code: `ProtectionController.publishWebSnapshot`]. Fail-open: the snapshot expires after 90 s without refresh [code: `WebProtectionSnapshot.ttlMs`]. Safari is guarded by `SafariWebGuard` (source `browser_url.safari` is off by default).
- `ChatGPT`, `Claude` desktop apps would be blocked only by category. The Claude and ChatGPT desktop apps declare `public.app-category.developer-tools`, which is in a typical default block list, so a list session would quit them; the Gemini desktop app declares no `LSApplicationCategoryType`, so it falls to `tivra.app-category.other` (also in the list). DeepL/Perplexity categories are [unverified].
- Escape hatches exist and are the learner's: the Mac's End/Release button (with an optional cooldown, tables `release_attempts` and `active_release_cooldown`), "Allow N min" snooze (0/60/180/300/600 s, default 180; `AllowPolicy.options`), and quitting Tivra (`releaseBeforeTermination`). Tenaz must assume the learner can end the session at any time; hence verification after the fact (section 4) matters more than prevention.

### 2.5 Verdict for (b)

Possible today only as: pair Tenaz as a device, patch the permanent site list, hope Tenaz is exempt, start `study` for N minutes, restore the list. I recommend **not** doing this in v1. Use Tenaz-side prevention (section 4.1) plus Tivra for detection (section 4.2), and propose patch P1 (section 6) to make the blocking request clean.

---

## 3. Questions (c) and (d): Learning category and AI/translator classification

### 3.1 Taxonomy [code: `Sources/TivraTaxonomy/TivraCategory.swift`, SPEC 5.5]

Raw values (ASCII, persisted in `plan_blocks.category`, `activity_spans.category`, `minute_ledger`): `escuela, trabajo, aprendizaje, proyectos, comunidad, finanzas, social, viajes, sueno, rutina, utilidad (data only), sin_clasificar (data only)`. Overlap priority: finanzas 3 > escuela 4 > sueno 5 > aprendizaje 6 > trabajo 7 > comunidad 8 > proyectos 9 > social 10 > viajes 11 > rutina 99.

- **`aprendizaje` ("Learning") is a first-class category** in Tivra's taxonomy [code]. It maps to the calendar color key `aprendizaje`. Settings has "Away counts as on plan" for it (`deepCapture.awayOnPlan.aprendizaje`).
- Do not confuse it with Settings > Deep Capture > **Learning** (`deepCapture.learning.enabled`, "Learn from my answers"), which is the classifier's feedback loop, not a time tracker [code: `CompanionSettingsSchema`, `LearnedMetaKey`].
- A second, independent taxonomy exists for blocking only: `AppBlockCategory` (Apple's `LSApplicationCategoryType`, 22 values) [code: `AppBlockCategory.swift`]. Plus the legacy productive/distraction/neutral lists in `AnalyticsAggregator` (productive domains include `docs.anthropic.com`, `platform.openai.com`; **nothing** for chatgpt.com, claude.ai, deepl.com or translators).

### 3.2 How AI and translator tools are classified: they are not

- Seed rules (`Sources/TivraCore/DeepCapture/Seeds/seed_rules_v1.json`) are conservative: Canvas -> escuela, Mexican banks -> finanzas, streaming -> sueno, WhatsApp/Telegram/iMessage -> social, Finder/System Settings/Spotlight/password managers -> utilidad. **No AI or translator entry** (grepped for chatgpt, openai, deepl, translate, claude.ai, gemini, perplexity: only the two productive-domain mentions above).
- Classification cascade (SPEC 6.3): user lock > rules (`category_rules`) > registry (repo cwd) > catalog > seed > absorbed > FM (Foundation Models) > Claude batch > none, with confidence bands. AI-tool domains and apps (`claude.ai`, `chatgpt.com`, `com.anthropic.claudefordesktop`, `com.openai.codex` which is the ChatGPT desktop app, the Android Claude package) can show up in activity data, but their categories depend on the learner's corrections and the learned classifier, so **a category-based check ("was anything outside aprendizaje in focus?") is unreliable for exam integrity**. Use an explicit deny list.
- A learner can add rules such as work-collaboration tools -> `trabajo` or games -> `social`. Work tools typically sit in `trabajo`, which matters for the "never block a work meeting" rule (section 5).

### 3.3 Recommended Tenaz-owned deny list (ships inside Tenaz, editable)

Bundle ids [partly **unverified**, confirm with `mdfind`/`osascript -e 'id of app "X"'` at install time]: `com.anthropic.claudefordesktop` (Claude desktop), `com.openai.codex` (the bundle id of the ChatGPT desktop app, not only a CLI), `com.google.GeminiMacOS` (Gemini desktop; the earlier guess `com.google.Gemini` was wrong and `com.openai.chat` does not exist), `com.deepl.macos.DeepLCopyTranslator` (DeepL, [unverified]), `ai.perplexity.mac` ([unverified]), `com.apple.Translate` (Apple Translate, high confidence), `com.todesktop.230313mzl4w4u92` (Cursor, unverified; probably out of scope).
Domains: `chatgpt.com`, `chat.openai.com`, `openai.com`, `claude.ai`, `gemini.google.com`, `bard.google.com`, `copilot.microsoft.com`, `perplexity.ai`, `poe.com`, `deepl.com`, `translate.google.com`, `translate.google.com.mx`, `reverso.net`, `linguee.com`, `wordreference.com`, `bing.com/translator` (path match, use `url` prefix), `grok.com`, `x.com/i/grok`, `you.com`, `character.ai`, `huggingface.co/chat`. Whether dictionaries are allowed is a **product decision**: TOEFL forbids all of them, but daily practice should allow dictionaries. Exam mode = strict list; practice mode = AI only.

---

## 4. Integration contract A - Exam mode

### 4.1 Prevention (Tenaz-owned, always on, no Tivra needed)

Exam mode is a full-screen Tenaz window. Tenaz should itself:
- Observe `NSWorkspace.didActivateApplicationNotification` and, when a deny-listed bundle activates, hide it (`NSRunningApplication.hide()`), bring Tenaz forward and log an "integrity event" (it can *not* and should not `terminate()` other apps; Tivra already does that when asked, and killing apps contradicts "never lock the learner out").
- Pause or invalidate the section when integrity events occur, per the scoring rule below.
- Treat Tivra as a second witness, not the primary control.

### 4.2 Verification (read-only, zero Tivra changes) - the core of the contract

Run after the exam, and optionally every 60 s during it. Inputs: `T0`, `T1` (ms epoch, exam start/end as recorded by Tenaz), grace `G = 90 s` after `T1` for span flush.

**Step 1 - Capture health (is the witness reliable?)**

```sql
-- capture ticks, expected ~1 per 60 s [code: cadence 60 s]
SELECT ts FROM tivra_events
 WHERE type='capture_tick' AND ts BETWEEN :T0 - 120000 AND :T1 + 120000 ORDER BY ts;
-- source health now
SELECT source, state, last_ok_ts FROM source_health
 WHERE source IN ('capture_tick','window_titles','browser_url.<browser>','system_state');
```

Rules: let `gap` = largest difference between consecutive ticks inside `[T0-60 s, T1+60 s]`. If `gap > 150 s`, or no tick within 90 s of `T0`/`T1`, or `window_titles` or `browser_url.<browser>` is not `ok`, the result is `UNVERIFIABLE` (Tivra was off, paused or lacked a permission). Also check Deep Capture pause: `system_state` events and `tivra_health.deepCapture`; spans with `kind='paused'` or `'excluded'` overlapping the window make it `UNVERIFIABLE`.

**Step 2 - Foreground evidence in the window**

```sql
-- resolved intervals overlapping the exam
SELECT start_ts, end_ts, kind, bundle_id, app_name, domain, url, title, device_id, source
  FROM activity_spans
 WHERE end_ts > :T0 AND start_ts < :T1
   AND kind IN ('active','passive');
-- raw focus stream as cross-check (also catches a very short tab flash)
SELECT ts, type, source, payload FROM tivra_events
 WHERE ts BETWEEN :T0 AND :T1 AND type IN ('app_active','window_focus','tab_active');
```

Match in Tenaz (not in SQL; the payloads are JSON blobs): `bundle_id` (case-insensitive) in the deny bundles, or `domain`/`url` host equal to or a subdomain of a deny domain, or title regex for obvious cases (`/ChatGPT|Claude|DeepL|Translate/i` on browser titles; low confidence, only as a warning). Count `violation_seconds` as the overlap of matching spans with `[T0, T1]` and keep only `{start, end, kind: bundle|domain, label}` for the exam record.

**Step 3 - Other devices** (the learner may cheat with AI, and a paired phone is a second device):

```sql
SELECT ts, type, device_id, payload FROM tivra_events
 WHERE device_id <> 'mac-local' AND ts BETWEEN :T0 AND :T1 AND type IN ('device_usage','device_screen');
```

Android foreground usage during the exam (any app) is a warning; a deny-listed Android package (`com.anthropic.claude`, `com.openai.chatgpt`, `com.google.android.apps.bard`, `com.deepl.mobiletranslator`, `com.google.android.apps.translate`) is a violation. Payload schema for `device_usage` is in `Sources/TivraCore/Companion/PhoneUsage.swift` (not read in detail; **[unverified]**: field names, and the phone batches uploads, so usage can arrive minutes late - re-run verification up to 15 minutes later, matching the Android companion's `StateRefreshWorker` cadence).

**Step 4 - Verdict** (stored in Tenaz's own DB, never in Tivra's):

```json
{
  "examId": "uuid",
  "window": {"startTs": 1792727400000, "endTs": 1792729200000},
  "verifiedTs": 1792729320000,
  "tivraAvailable": true,
  "captureGapMaxSec": 61,
  "verdict": "CLEAN | VIOLATION | WARNING | UNVERIFIABLE",
  "violations": [{"startTs": 0, "endTs": 0, "kind": "domain", "label": "claude.ai", "seconds": 42}],
  "warnings": [{"kind": "phone_active", "seconds": 300}]
}
```

Verdict logic: `UNVERIFIABLE` (health failed) takes precedence over `CLEAN`; any violation >= 5 s -> `VIOLATION`; shorter flashes or phone usage with no deny match -> `WARNING`; else `CLEAN`.

### 4.3 What to do when Tivra is not running or unreadable

Decide at *exam start*, not afterwards, so the learner cannot discover it only when it is inconvenient:
1. Preflight (10 s before the exam): file exists and is readable, newest `capture_tick` < 90 s old, `source_health` OK. Optional stronger check: `NSRunningApplication.runningApplications(withBundleIdentifier: "com.chere3.focusflow")`.
2. If the preflight fails: show a calm, non-blocking banner "Tivra is not watching; this exam will be unranked". Offer "Open Tivra" (`NSWorkspace.open`) and let the learner start anyway. Never block the exam (DECISIONS.md rule 2). Mark the result `UNVERIFIABLE`: it counts for practice stats but earns no "certified" badge, no level promotion and no streak credit. This is a commitment device, not a prison.
3. If Tivra dies mid-exam (no ticks for > 150 s), the section is flagged `UNVERIFIABLE` from that point; Tenaz's own deny-list observer (4.1) keeps working and its log is the fallback evidence.
4. Tailscale being down does **not** affect this path (the file is local); it affects only the companion/MCP optional features.

### 4.4 Optional: ask Tivra to block during the exam

Only after patch P1 (section 6), or by the learner's manual one-time setup:
1. Pairing once per Mac (Tenaz asks the learner to press "Pair phone" and type the 8 digits; secret into Tenaz's Keychain).
2. At exam start: `POST /v1/commands` kind `start`, `templateId: "study"` (or a new `tenaz_exam` template after P1), `blocking: "list"`, `durationMin = ceil(examMinutes) + 2`. Remember `sessionId`.
3. At exam end: `kind: end` with that `sessionId`. Tenaz must tolerate `409 session_running` (the learner already has a manual session: do not replace it; fall back to detect-only) and a calendar session being released (that costs the learner their calendar block: prefer asking first).
4. On any failure (Tailscale down, 401/403/412/5xx, timeout 3 s), continue detect-only. The command is best effort and must never gate the exam.

---

## 5. Integration contract B - Punishment mode ("Tivra blocks fun apps until daily reviews are done")

Today's answer: **not cleanly possible without a Tivra patch.** The requirement "block fun apps *until a condition is met*" needs a session with no fixed end that Tenaz ends when reviews finish. The companion `start` has a fixed `durationMin` (max 240), and Tivra's block list is "everything but exemptions", which is the opposite of "only fun apps".

Facts that constrain the design:
- The learner's classification already knows what is "fun": rules map games to `social`; YouTube is `utilidad` or per-video; WhatsApp/Telegram are `social`. A category session `blocking: "block:social"` blocks classified `social` apps and sites by confidence rules (`ProtectionPolicy.categoryAllow`; only band high or Jev >= 0.9 is enforced; `utilidad` and `sin_clasificar` always pass; browsers and terminals are never quit, pages are blocked via the extension) [code]. **But "the list always applies"**: `block:social` still runs the learner's 22-category block list first (SessionBlocking doc comment), so it would quit nearly everything, including Tenaz. Also work apps are `trabajo`; they would be quit by the list but not by the category rule.
- "Never block a work meeting": Meeting apps (for example `com.microsoft.teams2` and `us.zoom.xos`) are in the default list's categories (business/productivity). A list session would quit them mid-meeting. This is a hard conflict with DECISIONS.md.

Recommended design:
1. **v1 (no Tivra changes): Tenaz-owned punishment.** Penalties are inside Tenaz: mascot health/XP loss, a written penalty task, a full-screen "review gate" shown at wake/unlock and at 3 fixed times a day with escape hatches. This satisfies the intent without touching the learner's productivity tooling.
2. **v2 (after patch P1): Tivra-assisted.** At the deadline hour (e.g., 21:00) if reviews are not done, Tenaz sends `start` with `blocking: "block:social"` plus P1's `blockMode: "categories_only"` so the Block list is skipped, `exemptBundleIds` includes Tenaz and the meeting apps, and `durationMin` 30; Tenaz re-issues `extend` while reviews remain, and `end` immediately when the last review is graded. Meeting guard: before any `start`, Tenaz checks `plan_blocks`/Calendar and `NSWorkspace` for Teams/Zoom/Meet in foreground or camera/mic active (`capture_tick.micRunning == true`, `audioOutRunning`) and refuses to start Tivra blocking while true. This also requires the 5-minute minimum and a short delay for the extension to receive the snapshot (<= 30 s plan feed [code: `webPlanInterval`]).
3. Interaction with the learner's own Tivra sessions: if `GET /v1/state` shows an active session, never override it (409 handling), just show the punishment inside Tenaz.

---

## 6. Proposed Tivra-side patches (PROPOSALS ONLY - do not apply from this project)

Do these in a separate git worktree, after Tivra's current branch merges, each behind a tested flag. Keep the "no motivational copy" rule of Tivra's lexicon in any UI string (terms: Attention, Drift, Focus block, Protected work).

### P1 - Per-request extra block list and exemptions on `start` (companion)

Goal: Tenaz can say "for N minutes, block these bundle ids and these sites, skip the learner's default list, and never quit these bundle ids".

Wire change (contract v1, backward compatible; new optional keys, old clients ignore them):
```json
{
  "v": 1, "commandId": "tenaz-exam-20261022-1", "kind": "start", "issuedTs": 1792727400000,
  "templateId": null, "durationMin": 40,
  "blocking": "list",
  "guard": {
    "listMode": "only_listed",
    "apps": ["com.anthropic.claudefordesktop", "com.openai.chat", "com.apple.Translate"],
    "sites": ["chatgpt.com", "claude.ai", "deepl.com", "translate.google.com"],
    "exemptApps": ["com.chere3.tenaz", "com.microsoft.teams2", "us.zoom.xos"],
    "label": "tenaz_exam"
  }
}
```
Rules: `listMode` `only_listed` means "ignore profile-default"; `merge` means union. Caps: <= 50 apps, <= 200 sites (reuse `WebProtectionSettings` site normalization), bundle id shape via `PhoneCommandRequest.isBundleId`. Idempotency hash already covers all fields (`canonicalHash`).

Files and functions:
1. `Sources/TivraCore/Companion/PhoneCommands.swift`: add `public struct PhoneGuard: Codable, Equatable, Sendable { listMode, apps, sites, exemptApps, label }`, field `guard` on `PhoneCommandRequest`, validation in `validationError()` (only valid for `.start`; reuse `.invalidValue`); extend `PhoneCommandPlanner` start plan struct to carry it.
2. `FocusFlow/Services/Companion/PhoneCommandHandler.swift`, `execute(...)` case `.start`: pass `guard` to `timer.launchFromPhone(...)`.
3. `FocusFlow/Features/Timer/PomodoroViewModel.swift`, `launchFromPhone(...)`: new optional param; build the `ProtectionRequest` with it and force `.blockList`/`.categories` (never `.planScope`).
4. `FocusFlow/Services/Protection/ProtectionController.swift`: `ProtectionRequest` gains `extraGuard`; `engage(_:)` stores it in `Engagement`; `loadBlockList(repo:profileId:logger:)` / `didLoad(...)` replace or merge `rules` and `blockDomains` per `listMode`; `decide(_:)` consults `guard.exemptApps` before the policy.
5. `Sources/TivraCore/Protection/ProtectionPolicy.swift`: `commonAllow` accepts an `extraExemptions: Set<String>` parameter (default empty) so `isFixedExclusion` stays a pure function; unit tests in `Tests/TivraCoreTests/`.
6. `docs/mobile/M3-M4-contract.md`: document `guard`; audit rows: reuse `access_audit` with `client='android'`, tool `commands`.
Security: the guard narrows rather than widens what Tivra can do (it only blocks what the caller names, plus exemptions that cannot exempt more than the caller's own list); it is still gated by a paired device and the user's approval of pairing. Add exemption of a hard-coded never-quit set (`com.apple.*` core UI) to avoid foot-guns.

### P2 - Seed rule so Tenaz time counts as Learning

Files: `Sources/TivraCore/DeepCapture/Seeds/seed_rules_v1.json` add `{ "kind": "bundle", "pattern": "com.chere3.tenaz", "category": "aprendizaje" }`; reseed path in `DeepCaptureStore`/`SeedRules.swift` (seed rules are versioned: bump `version` to 2 and make the seeder idempotent by pattern); tests in `Tests/TivraCoreTests/` for classification and for "seed does not override a `user` rule". Tenaz's own exam window should always be foreground when learning, so no extra signal is needed.
Zero-patch alternative: The learner corrects one Tenaz span in Tivra's Review ("this is Learning"), which creates a `user`/`review` rule; or ask once via the Review flow (`/v1/review/*`).

### P3 - Read endpoint for third parties on loopback (optional, larger)

Only if the DB path proves fragile (e.g., SQLCipher lands): a loopback `GET /v1/spans?from&to` signed with the existing 4242 secret. Not recommended now; YAGNI.

---

## 7. Integration contract C - Learning-time reporting

Facts: there is no "report learning minutes" API, and `POST /events` accepts only extension event types [code]. Tivra derives learning time from observed foreground activity classified `aprendizaje`, and from calendar plan blocks of that category (`plan_blocks`, adherence engine with "Away counts as on plan").

Recommended approach:
1. **Passive and correct**: make Tenaz's windows count as Learning by classification (P2, or one manual classification). Then `activity_spans` rows with `bundle_id = 'com.chere3.tenaz'` and `category = 'aprendizaje'` are the report; `minute_ledger` and `day_reports` automatically include them in adherence if a Learning calendar block exists.
2. **Tenaz keeps its own truth**: Tenaz records its own session minutes (it knows which minutes were actual practice vs idle on a window) in its DB. Never write into Tivra's DB.
3. **Reading it back** (Tenaz dashboard, "Tivra says you did N Learning minutes today"):
```sql
SELECT SUM(MIN(end_ts, :dayEnd) - MAX(start_ts, :dayStart))/60000.0 AS minutes
  FROM activity_spans
 WHERE category='aprendizaje' AND kind='active' AND bundle_id='com.chere3.tenaz'
   AND end_ts > :dayStart AND start_ts < :dayEnd;
```
and, for non-Tenaz learning (Duolingo, YouTube lessons, books in the browser): the same query without the bundle filter. Cross-check with Tenaz's own number; show the Tivra number as a second line, not as the source of XP (XP stays Tenaz-owned so Tivra data can never be a gate).
4. **Plan alignment (nice to have)**: Tenaz may suggest creating a recurring Google Calendar event with the `aprendizaje` color so the adherence engine scores English practice as planned Learning. Out of scope for code.

---

## 8. Tenaz-side implementation checklist

1. `TivraReader` (actor, in `TenazCore` or a `TenazIntegrations` module): opens the DB read-only, exposes `health()`, `foregroundEvidence(window:)`, `learningMinutes(day:)`, `captureGaps(window:)`. All pure SQL; no GRDB dependency required (SQLite3 C API or GRDB read-only; Tivra uses GRDB, matching `Package.swift` makes sharing fixtures easy).
2. `DenyList` (JSON in Application Support, shipped defaults from 3.3, editable); `ExamIntegrityVerifier` implementing 4.2 with golden tests: fixture DB with spans touching `claude.ai`, a capture gap, a paused span, a phone span.
3. `TivraCompanionClient` (optional, behind a feature flag, off by default): pairing, HMAC signing (vector in `Tests/TivraCoreTests/Fixtures/companion/hmac-vector.json` in the Tivra source), `start/end/extend`, 3 s timeouts, no retries that can double-start (reuse `commandId`).
4. Preflight UI: "Tivra is watching" indicator; settings toggle "Request Tivra protection during exams" disabled until P1 ships.
5. No writes to `~/Library/Application Support/Tivra/`, no edits to Tivra defaults, no use of the `4242` secret.

---

## 9. Open questions for the learner

1. Is it acceptable that exam results without a healthy Tivra are "unranked" rather than blocked? (Recommended yes.)
2. Dictionary/translator policy for non-exam practice: allow dictionaries, forbid LLMs, or forbid both?
3. Should P1 be built (best exam control, ~2 days in a Tivra worktree) or should Tenaz stay detect-only for v1? Recommended: detect-only now, P1 later.
4. Is a Tivra "Learning" calendar block (color for `aprendizaje`) part of the learner's plan? It makes adherence scoring meaningful for English practice.
5. Tailscale: the tailnet address varies between machines and over time; Tenaz must discover it at runtime, not hard-code it.

---

## 10. Source index

Paths are inside the Tivra source tree (a sibling project, not part of this repository).

- `CLAUDE.md`, `LEXICON.md`
- `docs/deep-capture/SPEC.md` (sections 5.5, 6.3, 8.1-8.6), Tivra's deep-capture remote-reader design doc
- `docs/mobile/M0-M1-contract.md`, `M3-M4-contract.md`
- `docs/blocking/F2b-web-design.md`, `F8-sessions-by-category-design.md`
- `FocusFlow/Services/DeepCapture/TivraMCPServer.swift`, `RemoteReaderController.swift`
- `FocusFlow/Services/Companion/{TivraCompanionServer,PhoneCommandHandler,CompanionController}.swift`
- `FocusFlow/Services/Protection/{ProtectionController,ProtectionSettings}.swift`, `FocusFlow/Features/Timer/PomodoroViewModel.swift`
- `Sources/TivraCore/{DatabaseManager,TivraEvent,TivraEventReceiver,LocalhostRequestAuthenticator,AppBlockCategory,AnalyticsAggregator}.swift`
- `Sources/TivraCore/Companion/{PhoneCommands,CompanionRoutes,CompanionProtocol,DeviceRegistry,CompanionSettingsSchema}.swift`
- `Sources/TivraCore/Protection/{ProtectionPolicy,SessionBlocking,WebProtection}.swift`
- `Sources/TivraCore/DeepCapture/Remote/{MCPTools,MCPAccessControl}.swift`, `DeepCapture/Seeds/seed_rules_v1.json`
- `Sources/TivraTaxonomy/TivraCategory.swift`

## Verification

Checked against the Tivra source and schema (read-only).

| # | Claim | Verdict | Source |
|---|---|---|---|
| 1 | 4242 on loopback; 4243 and 4244 only on the Tailscale IP `100.x.y.z` | Confirmed | `CompanionProtocol.swift:10` `port = 4244`; bind logic in `RemoteReaderController` and `CompanionController` |
| 2 | DB at `~/Library/Application Support/Tivra/tivra.db`, WAL, mode 0644, not encrypted | Confirmed | `DatabaseManager.swift`; Tivra `CLAUDE.md` "SQLCipher is not actually linked yet" |
| 3 | Table names (`tivra_events`, `activity_spans`, `minute_ledger`, `category_rules`, `exclusions`, `source_health`, `devices`, `plan_blocks`, `day_reports`, `access_audit`, protection tables) | Confirmed | schema in `DatabaseManager.swift` migrations |
| 5 | Block list = 22 App Store categories, zero sites | Confirmed | default profile seed: 22 category entries, no domains (column is `bundle_id_or_name`) |
| 6 | Only exempt app prefix is `com.chere3.focusflow`; fixed list of 7 Apple ids | Confirmed | `ProtectionPolicy.swift:106-122` |
| 7 | `start` durationMin 5-240, `extend` 5-120 | Confirmed | `PhoneCommands.swift:121,133` |
| 8 | Companion route list | Confirmed | `CompanionRoutes.swift:31-67` (all listed routes present) |
| 9 | No AI/translator seed rules; only `docs.anthropic.com`, `platform.openai.com` productive domains | Confirmed | grep of `DeepCapture/Seeds/` returns nothing; `AnalyticsAggregator.swift:468` |
| 10 | HMAC signing format (METHOD, path, timestamp, nonce, body joined by newline), device kind `android`, MCP default peer `100.x.y.z`, 7 MCP tool names | Confirmed | `LocalhostRequestAuthenticator.swift:145-159`, `DeviceRegistry.swift:7`, `MCPAccessControl.swift:139`, `MCPTools.swift:39-45` |
| 11 | Deny-list bundle ids (`com.openai.chat`, `com.google.Gemini`) | Corrected | app Info.plist: ChatGPT desktop = `com.openai.codex`, Gemini desktop = `com.google.GeminiMacOS`. Fixed in 3.3 |
| 12 | Claude/ChatGPT desktop category "probably productivity" | Corrected | app Info.plist: both `public.app-category.developer-tools` (in the block list) |
| 13 | 8-digit pairing code, 5 min, 5 attempts; Allow options 0/60/180/300/600 s; web snapshot TTL 90 s | Partly confirmed | Allow options (`AllowPolicy.swift:8`) and TTL (`WebProtection.swift:57`) confirmed; pairing code length/window/attempts [unverified] (not located in `CompanionProtocol.swift`; contract doc not re-read) |
| 14 | Same-host connection to own tailnet IP shows that IP as peer | [unverified] (already marked) | Not exercised |

## Gaps found in verification

- **The ChatGPT desktop app's bundle id is `com.openai.codex`**, so a "Codex" entry in activity data can be ChatGPT usage; the deny list must include it (now fixed), and any code treating it as a CLI is wrong. Re-derive bundle ids at runtime (`NSWorkspace`/Info.plist) rather than hardcoding.
- **Template `study` has no protection profile** (`protection_profile_id` NULL, only `deep_work` is bound to `profile-default`). Whether `blocking:"list"` + `study` blocks anything is unproven; section 2.1/4.4 should be tested live before any promise to the learner.
- **Claude and ChatGPT desktop are categorised `developer-tools`**; a list session would quit them (good for exams) but also the learner's dev tools (Xcode, terminals are exempt only as terminals), reinforcing that Tenaz-side prevention should be primary.
- **Schema details can drift**: Tivra is under active development; schema columns differ from the prose in places (`default_duration_minutes`, `bundle_id_or_name`). Tenaz's `TivraReader` must tolerate schema migrations (check `grdb_migrations`) and fail to `UNVERIFIABLE`.
- **The Gemini desktop app** (`com.google.GeminiMacOS`, no category) was missing from the deny list.
