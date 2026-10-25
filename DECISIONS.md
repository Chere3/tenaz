# Decisions and assumptions

These were written at the start of the project as stated assumptions rather than confirmed choices. Each can be reversed.

## Product
- **Working name: Tenaz** (Spanish for "tenacious"). Rename freely.
- **Lineage.** Tenaz grew out of an earlier Android-first prototype with a "no guilt, no urgency" philosophy. Tenaz is a native, intrusive Mac app; it reuses the prototype's ideas (FSRS plan, graded vocab approach, research) but not its philosophy.
- **Default starting assumption: B1+**; target B2 then C1.
- **Exams** follow the TOEFL iBT section structure (Reading, Listening, Speaking, Writing) plus CEFR-aligned practice.
- **Intrusive, but self-chosen.** Punishments are commitment devices the learner configures (loss of mascot health/XP, Tivra blocking fun apps until reviews are done, a written penalty task), never arbitrary.

## Hard safety rules (never break these)
1. **Third-party apps cannot replace the macOS login screen.** The "unlock gate" is a full-screen panel shown after unlock/wake, above other windows. It is not a security boundary and never touches the real login.
2. **Every gate and overlay ships disabled by default**, and each one has a tested escape hatch: an emergency skip (with a penalty, not a lockout), a global kill-switch hotkey, a `defaults write` kill switch, and a maximum on-screen time. Nothing may ever lock the learner out of their own Mac, block a work meeting, or survive a force-quit.
3. **Tivra (the sibling focus app) is read-only from this project.** Integration code lives in Tenaz; any Tivra-side change is written as a proposal/patch in `docs/proposals/` and is never installed automatically.
4. **Claude goes through the `claude` CLI** (claude.ai session), never an API key. The app resolves the `claude` binary at `~/.local/bin/claude` explicitly and removes `ANTHROPIC_API_KEY` from the child environment. Everything core (deck, FSRS, mascot, overlays) works without Claude.
5. **Data stays local** (Application Support), like Tivra.

## Engineering
- Native macOS, Swift 6 + SwiftUI (+ AppKit for panels, status item, window levels), macOS 26.
- Layout mirrors Tivra: `project.yml` (XcodeGen) + `Package.swift` with a pure-logic `TenazCore` library and tests; the Xcode project is generated, never edited by hand.
- Non-sandboxed (needed for launching `claude`, reading Tivra's MCP, observing the frontmost app).
