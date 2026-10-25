## What and why

<!-- Short description of the change and the motivation. Link issues with "Fixes #123". -->

## Checklist

- [ ] `swift test` passes
- [ ] The app builds (`xcodebuild ... CODE_SIGNING_ALLOWED=NO`)
- [ ] A new screen has a line in `Tenaz/App/SnapshotRegistry.swift` and a snapshot attached below
- [ ] A new migration is registered in `Persistence/Migrations.swift`
- [ ] The generated `.xcodeproj` is not edited and `DEVELOPMENT_TEAM` is unchanged
- [ ] New content has an entry in `Content/licenses.json` (redistributable sources only; no `.nc.json` files committed) and `Content/LICENSES.md` is regenerated

### Safety rules (see DECISIONS.md)

- [ ] Any new overlay, gate or intrusion is disabled by default
- [ ] It has an escape hatch (emergency skip, kill-switch hotkey, `defaults write` kill switch, max on-screen time) and never blocks a meeting
- [ ] Data stays local; Claude is used only through the `claude` CLI (no API key)

## Screenshots / snapshots

<!-- Before/after for UI changes. -->
