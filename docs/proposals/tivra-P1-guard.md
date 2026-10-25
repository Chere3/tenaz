# Tivra patch P1: per-request block list and exemptions on `start`

Status: PROPOSAL, text only. Nothing in the Tivra repo was changed (DECISIONS rule 3). Apply in a separate Tivra worktree after the current Tivra branch merges, behind a tested flag. Source: `docs/research/06-tivra-integration.md` section 6.

## Why

Tenaz can start a Tivra protection session through the companion server (`POST /v1/commands`, kind `start`), but it cannot say what to block. Tivra blocks the learner's single `profile-default` list (22 App Store categories, no sites), which would also quit Tenaz (only `com.chere3.focusflow*` is exempt) and Teams/Zoom mid-meeting. P1 lets the caller name the list and the exemptions for one session. Until it ships, Tenaz is detect-only and the "Tivra fun-app block" penalty stays disabled.

## Wire change (contract v1, backward compatible: new optional key)

```json
{
  "v": 1, "commandId": "tenaz-exam-20261022-1", "kind": "start", "issuedTs": 1792727400000,
  "templateId": null, "durationMin": 40, "blocking": "list",
  "guard": {
    "listMode": "only_listed",
    "apps": ["com.anthropic.claudefordesktop", "com.openai.codex", "com.apple.Translate"],
    "sites": ["chatgpt.com", "claude.ai", "deepl.com", "translate.google.com"],
    "exemptApps": ["com.chere3.tenaz", "com.microsoft.teams2", "us.zoom.xos"],
    "label": "tenaz_exam"
  }
}
```

`listMode`: `only_listed` ignores `profile-default`; `merge` unions with it. Caps: at most 50 apps and 200 sites (reuse `WebProtectionSettings` site normalization); bundle ids validated with `PhoneCommandRequest.isBundleId`. Only valid for `kind: start`. The idempotency hash (`canonicalHash`) already covers every field.

## Changes

1. `Sources/TivraCore/Companion/PhoneCommands.swift`: add `public struct PhoneGuard: Codable, Equatable, Sendable { listMode, apps, sites, exemptApps, label }`, a `guard` field on `PhoneCommandRequest`, validation in `validationError()` (`.start` only, reuse `.invalidValue`), and carry it in the `PhoneCommandPlanner` start plan.
2. `FocusFlow/Services/Companion/PhoneCommandHandler.swift`, `execute(...)`, case `.start`: pass `guard` to `timer.launchFromPhone(...)`.
3. `FocusFlow/Features/Timer/PomodoroViewModel.swift`, `launchFromPhone(...)`: new optional parameter; build the `ProtectionRequest` with it and force `.blockList` / `.categories`, never `.planScope`.
4. `FocusFlow/Services/Protection/ProtectionController.swift`: `ProtectionRequest` gains `extraGuard`; `engage(_:)` stores it in `Engagement`; `loadBlockList(repo:profileId:logger:)` / `didLoad(...)` replace or merge `rules` and `blockDomains` per `listMode`; `decide(_:)` consults `guard.exemptApps` before the policy.
5. `Sources/TivraCore/Protection/ProtectionPolicy.swift`: `commonAllow` takes `extraExemptions: Set<String>` (default empty) so `isFixedExclusion` stays pure. Unit tests in `Tests/TivraCoreTests/`.
6. `docs/mobile/M3-M4-contract.md`: document `guard`; audit rows reuse `access_audit` with `client='android'`, tool `commands`.

## Safety

- The guard narrows what Tivra does: it blocks only what the caller names, and exemptions cannot exempt more than the caller's own list.
- Still gated by a paired device (the learner approves pairing) and Tivra's own release/allow escape hatches.
- Hard-code a never-quit set (`com.apple.*` core UI, Finder, Dock, loginwindow) that no `guard` can override.
- Tenaz must treat the request as best effort: on any failure (Tailscale down, 409 `session_running`, 5xx, 3 s timeout) it continues detect-only. It never replaces a session the learner started themself.
- Meeting guard stays on Tenaz's side: no `start` while the mic or camera is in use or a meeting app is frontmost.

## Tests to add in Tivra

Command validation (bad bundle id, too many sites, `guard` on non-start), `only_listed` vs `merge` rule building, exemption wins over block, replay with the same `commandId` returns the stored result, different body is 409 `command_mismatch`.
