# 09 - Prior art: reusable pieces from an earlier Android prototype

Tenaz grew out of an earlier, Android-first English-learning prototype (Kotlin Multiplatform, mobile-first, "no guilt, no urgency" philosophy). That prototype is not part of this repository. This note records only which ideas Tenaz carries over and which it deliberately does not.

## Carried over

- **FSRS-6 scheduling.** The scheduler is re-implemented from scratch in Swift (`TenazCore`) and validated against the reference py-fsrs implementation with golden vectors.
- **Streak logic.** A small pure engine with tests, adapted to Tenaz's rules (a qualified day needs correct reviews plus one production task).
- **Vocabulary pipeline idea.** Graded word lists (CEFR-J, Ngram frequency ranks) joined with Tatoeba example sentences. Tenaz regenerates the data with its own script and keeps per-sentence attribution; nothing is copied verbatim.
- **Transparent exercise selection.** Show the learner why an item was chosen; parameters are re-derived rather than reused.

## Not carried over

- The engagement philosophy. Tenaz is intentionally intrusive, with self-chosen penalties (see `DECISIONS.md`).
- Material design tokens, the Supabase cloud layer and any server-side state. Tenaz is local-only.
- Unvalidated adaptive-model parameters.

## Licensing reminders

- Tatoeba sentences (CC BY 2.0 FR) require per-sentence author credit.
- CEFR-J and Ngram-derived lists carry their own attribution requirements; see `Content/licenses.json`.
