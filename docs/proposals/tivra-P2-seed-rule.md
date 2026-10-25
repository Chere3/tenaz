# Tivra patch P2: seed rule so Tenaz time counts as Learning

Status: PROPOSAL, text only. Nothing in the Tivra repo was changed (DECISIONS rule 3). Source: `docs/research/06-tivra-integration.md` sections 6 and 7.

## Why

Tivra has no API to report learning minutes; it derives them from foreground time classified `aprendizaje`. If `com.chere3.tenaz` is classified `aprendizaje`, Tenaz's practice shows up in `activity_spans`, `minute_ledger` and `day_reports` automatically, and Tenaz can read it back (`TivraReader.learningMinutes(day:)`) for the "Tivra says N Learning minutes today" line. XP stays Tenaz-owned, so Tivra data can never be a gate.

## Change

1. `Sources/TivraCore/DeepCapture/Seeds/seed_rules_v1.json`: add

   ```json
   { "kind": "bundle", "pattern": "com.chere3.tenaz", "category": "aprendizaje" }
   ```

   `category_rules.kind = 'bundle'` matches by prefix elsewhere in Tivra, so this also covers `com.chere3.tenaz.dev`; confirm that in `SeedRules.swift` and add the dev id explicitly if the match is exact.
2. Seed versioning: bump `version` to 2 and make the seeder idempotent by `(kind, pattern)`, so existing databases receive the new row once. Check the reseed path in `DeepCaptureStore` / `SeedRules.swift`.
3. Tests in `Tests/TivraCoreTests/`: a Tenaz span classifies as `aprendizaje` with `method = 'seed'`; a `user` or `review` rule for the same bundle still wins over the seed; reseeding twice adds one row.

## Zero-patch alternative

The learner corrects one Tenaz span in Tivra's Review ("this is Learning"). That creates a `user`/`review` rule for the bundle and has the same effect today, without touching Tivra.

## Optional

A recurring calendar event in a "Learning" category makes Tivra's adherence engine score English practice as planned Learning. Out of scope for code.
