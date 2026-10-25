# Tenaz content formats

The first bank was original text written for Tenaz (by Claude). New files may be converted from open datasets (plan: `docs/content/dataset-plan.md`), so every file that holds third-party or derived text has an entry in `Content/licenses.json` (see "Provenance and licenses" below), and its items carry `source` / `license`. Files are JSON arrays, UTF-8. The app bundles `Content/` and decodes it with `TenazCore` models (`ContentModels.swift`). IDs are unique across all files.

## Vocabulary: `Content/vocab/*.json`

```json
{
  "id": "b2-leverage-v",
  "headword": "leverage",
  "pos": "verb",
  "cefr": "B2",
  "es": "aprovechar, sacar partido de",
  "definition": "to use something you already have to get a better result",
  "example": "We can leverage our existing data to train the new model.",
  "exampleEs": "Podemos aprovechar nuestros datos actuales para entrenar el nuevo modelo.",
  "cloze": "We can ____ our existing data to train the new model.",
  "answer": "leverage",
  "distractors": ["leave", "level", "lecture"],
  "collocations": ["leverage data", "leverage experience", "leverage a relationship"],
  "note": "",
  "tags": ["workplace"]
}
```
- `cefr`: one of A2, B1, B1+, B2, B2+, C1, C2.
- `cloze`: the example with the answer replaced by exactly `____` (four underscores), once. `answer` is the exact form that fills it (may be inflected, e.g. "leveraged").
- `distractors`: exactly 3 words of the same part of speech and the same inflection as `answer`, each clearly WRONG in that sentence, and different from each other and from `answer`.
- `note`: a short tip in English for Spanish speakers (false friend, preposition, pronunciation), or "".
- `tags`: from: core, verb-pattern, academic, workplace, meetings, tech, phrasal, collocation, intensifier, false-friend, linker, preposition, idiom, error-pattern.
- Optional `source`, `license`: where a converted entry came from (see "Provenance and licenses").

## Exam items: `Content/items/*.json`

Every item has `id`, `type`, `cefr`, and optionally `skill` (reading | listening | writing | speaking | grammar). Option lists have exactly 4 options; `answer` is the 0-based index of the only correct option. `explanation` is one short English sentence.

| type | extra fields |
|---|---|
| `completeWords` | `passage`: a 70–110 word academic paragraph where the second half of every second word (from the second sentence on, 10 gaps) is hidden, written inline as `tech{{nology}}` (visible part, then the hidden part in double braces). Scored per gap, case-insensitive. |
| `readDaily` | `title`, `text` (40–150 words: email, notice, chat, ad, schedule), `questions`: [{`q`, `options`, `answer`, `explanation`}] (2–3) |
| `readAcademic` | `title`, `text` (150–220 words), `questions` (5) |
| `listenResponse` | `prompt` (one spoken line), `voice` (female \| male), `options` (4 written replies), `answer`, `explanation` |
| `listenConversation` | `title`, `script`: [{`speaker`: "A"\|"B", `voice`, `line`}] (8–14 lines), `questions` (3–4) |
| `listenAnnouncement` | `title`, `voice`, `script` (one 80–140 word monologue string), `questions` (3) |
| `listenTalk` | `title`, `voice`, `script` (180–250 word lecture string), `questions` (4) |
| `buildSentence` | `context` (what the other person said), `chunks` (the answer split into 5–8 shuffled chunks), `answer` (the full sentence), `accepted` (other fully correct orders, may be empty) |
| `grammarMC` | `sentence` (with `____`), `options`, `answer`, `explanation`, `pattern` (preposition, verb-pattern, tense, agreement, article, conditional, passive, relative, modal, word-form, linker, collocation, false-friend) |
| `writeEmail` | `situation`, `tasks` (3 bullet strings), `minWords` |
| `writeDiscussion` | `professor` (the question post), `studentA`, `studentB` (two short posts with names), `minWords` |
| `lifeParagraph` | `prompt` (a question about the learner's own life, work, plans or feelings), `mustUse` (2–3 target words or structures), `minWords` (40–80) |
| `listenRepeat` | `sentence` (6–22 words), `voice` |
| `interview` | `topic`, `questions` (4, from personal to abstract) |

### Optional fields on every item

```json
{ "kind": "summary", "text": "…", "reference": ["…"],
  "source": "cosmosqa", "sourceId": "train-12345", "license": "CC BY 4.0", "tier": "permissive",
  "group": "cosmos:ctx:9f2c", "origin": "verbatim", "topics": ["workplace"] }
```

| field | meaning |
|---|---|
| `kind` | the writing kind (table below). Only checked on `lifeParagraph`, `writeEmail`, `writeDiscussion` and `interview`; a kind the type does not allow is rejected. Missing = the type's default |
| `text` | the text the kind works on, shown above the answer sheet (already used by `readDaily`/`readAcademic`). Required (non-empty) for `summary`, `rewrite`, `correct`, `translate`, `chart`; optional for `story` (the opener) |
| `reference` | model answers for kinds graded against one (summary, rewrite, correct, translate, chart key points). Claude compares meaning, not wording |
| `source`, `sourceId`, `license`, `tier` | provenance: dataset short name, its stable row key, the license string, and `permissive` \| `nc` \| `unclear` |
| `group` | items that share one underlying text (a passage reused at two levels, a sentence used by two types). Exposure control treats the group as one item: showing one hides the others |
| `origin` | `verbatim` (stem, text and key from the source), `adapted` (source text kept, questions/distractors/explanations LLM-made) or `generated` (all LLM-made) |
| `topics` | free tags such as `workplace`, `meetings` |

### Writing kinds

The gate shows only the kinds marked "gate" (a 25-40 word answer in his own words); the Write screen shows any `lifeParagraph` kind; exams use what their blueprints pick. Each kind has an instruction line and a placeholder in the UI and a one-line criterion in the Claude rubric (`WritingKind`).

| type | kinds (first = default when `kind` is missing) |
|---|---|
| `lifeParagraph` | `personal` (gate), `advice` (gate), `story` (gate), `compare` (gate), `describe` (gate), `summary`, `rewrite`, `correct`, `translate`, `chart` |
| `writeEmail` | `request`, `complaint`, `update`, `reply`, `recap` |
| `writeDiscussion` | `opinion`, `proscons` |
| `interview` | `interview` |

For `summary`, `rewrite`, `correct`, `translate` and `chart`, `prompt` is still required (the one-line task, e.g. "Your message to the planning team sounds too blunt."), and `minWords` should follow the task (about 0.6-1.2 × the `text` word count, clamped to 40-80). `chart` puts a small plain-text table in `text` (it is shown in a monospaced face).

### Repeats

The app logs every item when it is shown (`exposure` table: gate, Write, exam). A writing prompt does not come back until 90 % of its pool has been shown, and never has the same kind as the last two writing prompts; an exam skips items (and their `group`) shown in the last 180 days. A bigger bank therefore means fewer repeats with no code change.

## Provenance and licenses

- **`Content/licenses.json`** is a manifest with one entry per file that holds third-party or derived content:
  ```json
  { "file": "items/read-daily-cosmos.json", "source": "Cosmos QA", "url": "…", "license": "CC BY 4.0",
    "tier": "permissive", "attribution": "Huang et al. 2019, allenai/cosmos_qa", "retrieved": "2026-10-xx",
    "items": 1000, "origin": {"verbatim": 0, "adapted": 1000, "generated": 0} }
  ```
  Files written for Tenaz from scratch need no entry.
- **One file per source per type**: `items/read-daily-cosmos.json`, `vocab/bsl-workplace.json`.
- **`.nc.json`**: files from non-commercial, research-only or unclear-license sources end in `.nc.json` (e.g. `items/read-academic-race.nc.json`) and have `"tier": "nc"` or `"unclear"`. They load like any other file and can be dropped as a set (delete the `*.nc.json` files and their manifest entries) without touching the permissive bank.
- **IDs** of converted items are `<typeprefix>-<source>-<stable source key>` (prefixes `rd ra cw lr lc la lt bs gm rp iv we wd lp`; vocab `v-<headword>-<pos>`), never a row index. The loader silently drops a duplicate id, so converters must check uniqueness against all of `Content/`.

## Achievements: `Content/achievements.json`

An array of the 53 achievements from `docs/research/02-gamification-mascot.md` §5 (decoded by `AchievementDefinition`).

| Field | Meaning |
|---|---|
| `id` | kebab-case, unique |
| `name`, `description` | shown in the Achievements screen; hidden ones read "???" until unlocked |
| `type` | `P` progress, `M` mastery, `D` discovery, `S` streak, `H` hidden |
| `condition` | an `AchievementEvaluator` key (`correctRetrievals`, `masteredNotes`, `bestStreak`, `stage`, `cleanExams`, ...). Keys no area produces yet (`spokenGraded`, `modesUsed`, `cohesionB2Texts`, ...) stay locked until that area exists |
| `threshold` | the value the condition must reach |
| `reward` | `{ "xp": 20-200, "scales": n }` |
| `hidden` | bool; optional `hint` |
| `band`, `kinds` | exam conditions only: the TOEFL-style band and which `ExamKind`s count (`placement`, `dailyCheck`, `weeklyMock`, `monthlyMock`) |

## Mascot stages: `Content/config/stages.json`

Tena's growth gates as tunable data (`StageConfig`, PLAN F8). `mastered` defines a mastered note (`minStabilityDays`, `lastCorrectRecalls`), `microGrowthEvery` the mastered notes per micro-growth step, `cosmeticWeeks` the novelty weeks. Each `stages[]` entry has `stage`, `name`, `requires` (all present fields must hold: `onboardingDone`, `levelParagraphDone`, `reviewsDone`, `placementDone`, `placementBandAtLeast`, `privateBandAtLeast`, `publicBandAtLeast`, `mastered`, `writingMedianAtLeast`, `rolePlayAtLeast`, `monthlyMocksAtBand`), `floor` (`qualifiedDays` and/or `days` since the previous stage was reached) and, for stage 3, `catchingUpBelowPlacementBand`. Stages advance one at a time and never regress.
`Content/items/placement.json` holds items that only the placement uses (picked by id), e.g. the 120-150 word "tell me about yourself" `lifeParagraph`, whose `minWords` is above the usual 40-80.

## Exam blueprints: `Content/config/blueprints.json`

`{"blueprints": [...]}`, one per exam kind (`placement`, `daily`, `weekly`, `monthly`), decoded by `BlueprintCatalog` / `ExamBlueprint`. Each blueprint has `id`, `kind`, `title` and ordered `sections`:

| field | meaning |
|---|---|
| `id`, `title`, `minutes` | section id, display title, time limit |
| `skill` | the skill its evidence goes to (`reading`, `listening`, `writing`, `speaking`, `grammar`); omitted = each item's own skill |
| `picks` | `[{ "ids": [...] } \| { "types": [...] } \| { "vocab": true }, "count": n, "levels": ["B1", ...]}]`; `levels` are preferred, the nearest levels fill in when the bank is short |
| `adaptive` | `{"min", "max", "stopSD"}`: every pick joins one pool, the next task is the one nearest the running estimate, stop at `max` or once `min` are done and SD < `stopSD` |
| `stage`, `group` | two-stage routing: a `router` section, then exactly one of the `lower` / `upper` sections with the same `group` (upper when ≥ `routeUpperAt`, default 0.6, of the router is right) |
| `optional` | skipped unless the attempt asks for optional sections (monthly Grammar & Vocabulary) |
| `fallback` | `transcript` (show listening text when there is no audio) or `typed` (type speaking answers when there is no mic) |
