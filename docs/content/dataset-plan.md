# Tenaz content ingestion plan: from 436 items to a large bank

Scope: grow `Content/` from 436 exam items, 80 writing prompts (plus 30 email/discussion) and 807 vocab notes to **≥ 5,000 exam items, ≥ 1,500 writing prompts across many kinds, and ≥ 3,000 vocab notes**. Each source gets one converter script. Permissive sources come first. A non-commercial (NC), research-only or unclear source is used only where nothing permissive fits, and the plan says so each time.

This plan is grounded in the current code:
- `Content/FORMAT.md` holds the item shapes.
- `ContentValidator` holds the rules. They are enforced at load, and tests fail on violations.
- `ContentLibrary` loads **every** file in `Content/items/` and `Content/vocab/`, so new files are picked up with no code change.
- `ExamItem` has a keyed custom decoder, so extra JSON keys are ignored until the model gains fields.
- Three item-selection paths cause repeats; see §6.

---

## 0. What causes the repeats the learner sees (read first)

| Surface | Code | Why it repeats |
|---|---|---|
| Unlock gate | `Sources/TenazCore/Safety/Gate/GatePrompt.swift` → `pick(items:day:)` | `pool[abs(day) % pool.count]`: **every unlock on the same day shows the same question**. Across days it walks a fixed cycle of only 80 `lifeParagraph` items, and a forgotten word, when there is one, also stays fixed for the day. This per-day pick is the verified root cause. The `"follow up on"` fallback (used when `mustUse` has no lexical chunk ≤4 words) can add to it, but in the sampled items it is rare. |
| Today / Write screen | `Tenaz/Features/Home/TodayLoader.swift` → `writePrompt` | Rotates by day and skips prompts already answered, but uses the same single pool of 80. It does not know what the gate showed. |
| Exams | `Tenaz/Features/Exam/Runner/ExamRunner.swift:73` + `ExamStore.recentItemIds` | Excludes only items **answered** in the last **14 days**, and then only in exams. With 10 `readAcademic` and 6 `listenTalk` items, the fallback (`ExamSession.swift:246`) reuses items right away. |

A bigger bank alone does not fix the gate. §6 fixes it, and should ship in phase 0, before most of the ingestion.

**Placeholder overlap (UI bug):** this is outside this plan. The placeholder is drawn in `Tenaz/Features/Gate/ParagraphTextView.swift:70-84`, and the text overlays it after typing starts. It must stop drawing once `string` is non-empty, with a full redraw on the first keystroke. The placeholder text should also come from the item's `kind` (§7), not from a fixed example.

---

## 1. Targets per type

The aggregate targets are easy to reach (Cosmos QA alone has more than 5,000 rows). The repeats are per surface, though, so every type gets its own **minimum**. "Permissive tier" counts are what ships first. The "NC/unclear tier" is optional, kept in separate files and deletable (§3.3).

| Type | Today | Min target (permissive tier) | Optional NC/unclear tier | Main permissive sources |
|---|---:|---:|---:|---|
| `readDaily` | 20 | **1,500** | – (not needed) | Cosmos QA, OneStopQA, Belebele |
| `readAcademic` | 10 | **500** | RACE-high +600 | OpenStax, OneStopEnglish/OneStopQA, Belebele (+ LLM questions) |
| `completeWords` | 24 | **1,500** | – | OneStopEnglish, OpenStax, Belebele (programmatic) |
| `listenResponse` | 40 | **1,000** | MuTual +600 | Taskmaster, MultiWOZ (+ LLM distractors) |
| `listenConversation` | 8 | **400** | DREAM +500 | Taskmaster, MultiWOZ, generated workplace dialogues |
| `listenAnnouncement` | 6 | **200** | – | none exists → generated from a scenario matrix |
| `listenTalk` | 6 | **300** | TOEFL-QA +~100 | OpenStax seeds rewritten as lectures (generated) |
| `buildSentence` | 40 | **1,000** | – | Taskmaster/MultiWOZ replies, Tatoeba |
| `grammarMC` | 120 | **2,500** | dry-melon +1,500 | CoEdIT (gec), rule-based blanking of permissive sentences |
| `listenRepeat` | 40 | **1,000** | – | Tatoeba, Common Voice text (CC0) |
| `interview` | 12 | **150** | – | args.me topics + generated |
| `writeEmail` | 15 | **400** | – | generated scenario matrix (no open set exists) |
| `writeDiscussion` | 15 | **400** | – | args.me (CC BY 4.0) |
| `lifeParagraph` | 80 | **1,160** (many kinds, §7) | – | Tatoeba, CoEdIT, Dolly, OpenStax, WritingPrompts, generated |
| **Exam items (non-writing)** | 314 | **≈ 9,900** | +3,300 | |
| **Writing prompts** (writeEmail + writeDiscussion + lifeParagraph + interview) | 122 | **≈ 2,100** | | |
| **Vocab notes** | 807 | **3,300+** (+2,500) | – | CEFR-J/Octanove, NGSL/BSL/NAWL, kaikki (Wiktionary), Tatoeba |

Level mix to aim for, for a B2-targeting learner:

| Skill group | B1/B1+ | B2/B2+ | C1 |
|---|---:|---:|---:|
| Receptive (reading, listening, grammar) | 25% | 50% | 25% |
| Productive (writing, speaking) | 35% | 50% | 15% |

Drop A2 and C2 everywhere. Productive skills (speaking, writing) usually lag receptive ones, so the productive types lean lower.

---

## 2. Sources: chosen, flagged, rejected

| Source | License (verified by researchers) | Class | Used for |
|---|---|---|---|
| Cosmos QA `allenai/cosmos_qa` | CC BY 4.0 | permissive | readDaily |
| OneStopQA `malmaud/onestop_qa` | CC BY-SA 4.0 | share-alike | readDaily, readAcademic |
| Belebele `facebook/belebele` eng_Latn | CC BY-SA 4.0 (HF tag) | share-alike | readDaily, readAcademic, completeWords |
| OneStopEnglish corpus (GitHub) | CC BY-SA 4.0 | share-alike | completeWords, readAcademic text |
| OpenStax paragraphs `HuggingFaceTB/openstax_paragraphs` | CC BY 4.0 | permissive | completeWords, readAcademic, listenTalk seeds, summary kind |
| Taskmaster-1/2 (Google) | CC BY 4.0 | permissive | listenConversation, listenResponse, buildSentence |
| MultiWOZ 2.2 `pfb30/multi_woz_v22` | Apache-2.0 | permissive | listenConversation, listenResponse, buildSentence |
| Tatoeba (direct exports) | CC BY 2.0 FR (some CC0) | permissive | listenRepeat, buildSentence, vocab examples, translate kind |
| Common Voice sentence text | CC0 (**verify at source**) | permissive | listenRepeat |
| CoEdIT `grammarly/coedit` | Apache-2.0 tag (upstream mixes corpora) | permissive* | grammarMC, rewrite/correct kinds |
| args.me `webis/args_me` | CC BY 4.0 | permissive | writeDiscussion, interview |
| WritingPrompts `euclaise/writingprompts` | MIT tag (Reddit text) | permissive* | story kind |
| databricks-dolly-15k | CC BY-SA 3.0 | share-alike | summary kind |
| CEFR-J VP 1.5 + Octanove C1/C2 | free with citation / CC BY-SA 4.0 | permissive / SA | vocab spine, CEFR lookup |
| NGSL / BSL / NAWL | CC BY-SA 4.0 | share-alike | vocab spine, definitions, workplace/academic tags |
| kaikki.org (Wiktionary) | CC BY-SA + GFDL | share-alike | vocab es/definition/pos/phrasal tags |
| **RACE-high** `ehovy/race` | non-commercial research only | **NC – optional** | readAcademic. It is the only real exam source with 5 questions at about 200 words. |
| **DREAM** (GitHub) | non-commercial research only | **NC – optional** | listenConversation (real EFL listening exams) |
| **MuTual** (GitHub) | no license | **unclear – optional** | listenResponse. It has the best 4-option fit, but a permissive fallback exists. |
| **TOEFL-QA** (GitHub) | no license | **unclear – optional** | listenTalk. These are real TOEFL lectures, about 100 stories. |
| **dry-melon** Chinese middle-school exams | CC BY 4.0 uploader tag, upstream not cleared | **unclear – optional** | grammarMC. Real exam MCQs, but only A2–B1 and 38% of answers LLM-filled. |

\* Permissive tag, with an upstream caveat. This is fine for private use.

**Rejected:**

| Source | Reason |
|---|---|
| MCTest | grade-school level |
| QuAIL | NC, and truncating its texts breaks the questions |
| RACE-C | license not verified; add only after reading the CMU page |
| DailyDialog, EmpatheticDialogues, JFLEG, CEFR-SP | NC, and a permissive alternative covers the same need |
| W&I+LOCNESS | research-only |
| IELTS Task 2 scrape | no license; args.me covers opinion prompts |
| EFLLex, Kelly | cross-check only, nothing copied |
| ReClor | LSAT, wrong level |
| CLOTH | unverified license |

---

## 3. Pipeline: shared infrastructure for all converters

### 3.1 Layout

```
scripts/ingest/                 # uv project (pyproject.toml, uv.lock); scripts only, never data
  lib/
    schema.py     # Python port of ContentValidator + FORMAT.md bounds (stricter than Swift, see 3.4)
    textnorm.py   # detokenize ("you 've" -> "you've"), recapitalize, normalize-for-hash
    dedupe.py     # exact hash + MinHash LSH (datasketch), global index incl. existing Content/
    cefr.py       # lexical CEFR estimate (CEFR-J + Octanove lookup, NGSL rank, sentence length) + LLM tiebreak
    workplace.py  # relevance score: BSL list + supply-chain lexicon (supplier, shipment, lead time, forecast,
                  # inventory, batch, deviation, purchase order, stakeholder, deadline, escalate, OTIF, ...)
    gaps.py       # completeWords generator (3.5)
    chunks.py     # buildSentence chunker (spaCy en_core_web_sm)
    llm.py        # claude CLI wrapper: batched, JSON-schema output, content-hash cache, reject loop
    verify.py     # blind-solve verification of generated/converted MCQs (3.6)
    ids.py, emit.py, licenses.py
  sources/<source>.py           # one converter per source, with commands: fetch | extract | complete | verify | emit
  matrices/*.yaml               # scenario matrices for generated types (§5)
.ingest/                        # data, outside scripts/; not bundled
  raw/<source>/                 # each source downloads into its own new, empty dir
  stage/<source>/*.jsonl        # normalized intermediate rows
  cache/llm/<sha256>.json       # LLM results keyed by prompt hash, so reruns cost nothing
  reports/<source>.md           # counts per filter, reject reasons, 30-item random sample for human review
```

Rules:
- Run every script as `uv run python -I scripts/ingest/sources/x.py --raw .ingest/raw/x ...`. Paths are passed as arguments, and nothing executes inside `raw/`.
- Downloads above 5 MB are allowed at build time: Tatoeba English at 25 MB, the RACE shards, and OpenStax at 6.5 MB.
- kaikki (3.4 GB) is **streamed and filtered, never stored**: `curl -s URL | python -I lib/kaikki_filter.py --keep spine.txt > stage/kaikki/subset.jsonl`.

### 3.2 Intermediate row → Tenaz item, plus new optional fields

Every emitted item carries these new optional keys. They are already safe in JSON, because the decoder ignores unknown keys. The model changes are in §8.

```json
{ "source": "cosmosqa", "sourceId": "train-12345", "license": "CC BY 4.0", "tier": "permissive",
  "group": "cosmos:ctx:9f2c...", "origin": "verbatim|adapted|generated", "topics": ["workplace"], "kind": "..." }
```

- `group` is a key that items sharing one underlying text have in common: a OneStopQA paragraph at both levels, a Belebele passage reused for completeWords, or a Tatoeba sentence. Exposure control treats the whole group as one item.
- `origin` records which parts were LLM-made.
  - `verbatim`: stem, text and key come from the source.
  - `adapted`: the source text is kept, and the questions, distractors or explanations are LLM-made.
  - `generated`: everything is LLM-made from a matrix or seed.

### 3.3 IDs, files, licenses

- **ID** = `<typeprefix>-<source>-<stable source key>`, e.g. `rd-cosmos-train-12345`, `cw-ose-adv-042-p3`, `gm-coedit-<sha8>`. Never derive it from a row index, so that reruns stay stable. Prefixes: `rd ra cw lr lc la lt bs gm rp iv we wd lp`; vocab uses `v-<headword>-<pos>`.
  - The prefixes cannot collide with existing ids (`read-daily-…`, `b2-leverage-v`). `emit.py` still asserts global uniqueness against everything in `Content/`, because `ContentValidator.cleaned` **silently drops duplicate ids**.
- **One output file per source per type:** `Content/items/read-daily-cosmos.json`, `Content/items/read-academic-race.nc.json`, `Content/vocab/bsl-workplace.json`. NC and unclear files get the `.nc.json` suffix.
- **`Content/licenses.json`** (new) is a manifest with one entry per emitted file:
  ```json
  { "file": "items/read-daily-cosmos.json", "source": "Cosmos QA", "url": "...", "license": "CC BY 4.0",
    "tier": "permissive", "attribution": "Huang et al. 2019, allenai/cosmos_qa", "retrieved": "2026-10-xx",
    "items": 1000, "origin": {"verbatim": 0, "adapted": 1000, "generated": 0} }
  ```
- To drop NC content: `scripts/ingest/tier.py --drop nc,unclear` deletes the `*.nc.json` files and their manifest entries.
- Update the first line of `FORMAT.md`. It currently says "All content is original… no third-party licenses to track", which will be false. It should point to `licenses.json` and document the new optional fields.

### 3.4 Validation (`lib/schema.py`): stricter than Swift, run before anything touches `Content/`

`lib/schema.py` ports `ContentValidator.problems` exactly:
- 4 options, and `answer` in range
- `____` exactly once in vocab `cloze`, and `cloze.replace("____", answer) == example`
- 3 distinct distractors that differ from `answer`
- the cefr enum
- `grammarMC` contains `____`
- buildSentence chunk letters equal the answer letters
- at least 6 completeWords gaps, with non-empty visible and hidden parts
- required fields per type

It adds the FORMAT.md bounds that Swift does not check:

| Type | Bound |
|---|---|
| readDaily | 40–150 words, 2–3 questions |
| readAcademic | 150–220 words, 5 questions |
| listenConversation | 8–14 lines, A/B speakers, 3–4 questions |
| listenAnnouncement | 80–140 words, 3 questions |
| listenTalk | 180–250 words, 4 questions |
| buildSentence | 5–8 chunks |
| listenRepeat | 6–22 words |
| completeWords | 70–110 words, exactly 10 gaps |
| lifeParagraph | `minWords` 40–80, and `mustUse` contains ≥1 lexical chunk (≤4 words, not starting with "use ", no "tense"), as `GatePrompt.pick` requires |

It also enforces:
- the `pattern` enum
- the vocab `tags` enum
- no `{{`, `____`, HTML, URLs, Chinese characters or tokenization artifacts (` ,`, ` 's`) in display text

Failing rows go to `reports/` and never into `Content/`.

### 3.5 completeWords generator (`lib/gaps.py`)

FORMAT.md says "every second word". The 24 existing items were checked programmatically. They do **not** follow a strict alternation (only 2 of 24 match one), but all of them hold these invariants:
- exactly **10 gaps**
- the **first sentence has no gaps**
- the visible part is **ceil(n/2)** letters
- gapped words have **≥ 3 letters**
- passages are **70–83 words**

The generator uses the strict TOEFL-style rule, constrained by those invariants:
1. Take a 70–110 word window. Cut it on sentence boundaries and keep the source text unchanged.
2. From sentence 2 on, the eligible tokens are alphabetic words with ≥3 letters. Exclude numbers, hyphenated words, words with apostrophes, and all-caps acronyms. Ineligible tokens do not count in the alternation.
3. Gap every second eligible token (the 2nd, 4th, …) until there are 10 gaps. After that, leave the text plain.
4. Write each gap as `word[:ceil(n/2)] + "{{" + word[ceil(n/2):] + "}}"`, with punctuation outside the braces.
5. Reject the window if fewer than 10 gaps fit before the end of the window.

Unit test: the generator's output must parse with the same logic as `CompleteWordsParser` (Python port), and it must reproduce the existing invariant stats.

### 3.6 LLM passes (`lib/llm.py`, `lib/verify.py`)

- **Only through the `claude` CLI and the claude.ai session**, never an API key (DECISIONS.md #4).
  - Call it as `env -u ANTHROPIC_API_KEY claude -p --output-format json --model <tier>` with a JSON-schema instruction and batches of **20–25 rows per call**.
  - Cache every result by sha256(prompt), so a crash or rerun is free.
  - DECISIONS.md notes that an unattended launchd `claude -p` loop was blocked. If scripted calls are blocked, run the `complete` and `verify` stages as a Claude Code workflow over `stage/*.jsonl` instead. The input and output contract is the same.
- **Model tiers**, following CLAUDE.md:
  - `haiku`: explanations, CEFR tiebreak, titles, detokenize fixes, Spanish glosses.
  - `sonnet`: writing questions, distractors and scenario items, and all verification.
  - `opus`: not needed.
- **Verification is required for every MCQ whose key or distractors were touched by an LLM, or whose key is unreliable.** Rows that fail go to the report, and nothing gets a silent fix.
  1. A fresh `sonnet` call, given only text and question with shuffled options, picks an answer. It must match the key.
  2. The same call rates each other option "clearly wrong / arguably right". Reject if any is arguably right.
  3. Reading and listening questions must be answerable from the text alone: no world knowledge needed and no option leaking the answer.
- **Shuffle options** with a fixed seed derived from the item id, then recompute `answer`. Several sources put the key in a fixed position: OneStopQA uses `answers[0]`.
- **Throughput estimate.** About 11k items need some LLM field, which means about 550 generation calls plus about 550 verification calls. That spreads over several days of Max-plan usage. Order the work by LLM cost (§9).

### 3.7 CEFR estimate (`lib/cefr.py`)

1. **Source prior:**

   | Source signal | Level |
   |---|---|
   | OneStopQA / OneStopEnglish Ele / Int / Adv | B1 / B2 / C1 |
   | RACE middle / high | B1 / B2 |
   | dry-melon grade 7 / 8 / 9 | drop / B1 / B1+ |
   | CEFR-J word level | used directly |

2. **Lexical profile:** the share of content-word lemmas above B2 in the CEFR-J/Octanove lookup, plus words off-list, mean sentence length and the NGSL rank of the rarest 10% of words.
3. **Combine them with fixed thresholds.** Calibrate the thresholds on the 436 existing labelled items, and aim for ≥70% exact agreement before using them.
4. **LLM tiebreak:** `haiku` labels a row only when (1) and (2) disagree by more than one step. Output is always one of A2…C2. Drop A2 and C2.

### 3.8 Dedupe (`lib/dedupe.py`)

- **Exact:** sha1 of normalized text (lowercase, detokenized, punctuation stripped, whitespace collapsed). The key per type is the passage or text, the sentence with its answer filled in, the prompt or situation, or the Tatoeba English text.
- **Near:**
  - Passages: MinHash LSH on word 5-gram shingles, Jaccard ≥ 0.8.
  - Sentences ≤ 25 words: token-sort ratio ≥ 0.9 (rapidfuzz).
  - Prompts: the same, plus cosine ≥ 0.92 on a small local embedding (`sentence-transformers/all-MiniLM-L6-v2`). This catches IELTS-style paraphrases.
- **Scope:** within each source, across all sources, **and against the existing `Content/`**. Load all existing items into the index first, so they always win.
- **Known overlaps, which get the same `group` instead of being deleted:**
  - OneStopQA ⊂ OneStopEnglish: the same Guardian articles. Use one or the other per article, never both.
  - A OneStopQA paragraph at the Int and Adv levels.
  - A Belebele passage repeated across question rows: group by `flores_passage`.
  - Tatoeba sentence ids: **partition** them so each sentence id is used by exactly one type (vocab example, listenRepeat, buildSentence or translate), in that priority order.
  - Text sources that feed two types (Belebele and OpenStax into both readAcademic and completeWords): partition passages 70/30 by hash, so a text never appears in both types.

---

## 4. Per-type plan

"Verbatim" means taken from the source as is, apart from detokenizing. "LLM" means generated or completed through the `claude` CLI, then verified.

### 4.1 `readDaily`: 1,500, permissive only (RACE not needed)

| Source | Filters | Verbatim | LLM | Count |
|---|---|---|---|---:|
| **Cosmos QA** (train+validation; skip test if `label` is -1/hidden) | context 40–150 words; drop rows whose options include "None of the above choices"; drop contexts with >3 misspellings per 100 words (pyspellchecker); B1–C1; rank by `workplace.py` score, then sample to cap | context, question, 4 options, key | **1 extra question** per text, so each has 2 as FORMAT requires (verified); `title` (≤6 words); one-sentence explanation ×2 | 1,000 |
| **OneStopQA** | group by (title, paragraph_index, level); Int → B2, Adv → C1 (skip Ele); merge adjacent paragraphs of the same article and level to reach 40–150 words; keep 3 questions | text, questions, options; key = `answers[0]` (**check on 20 rows** that `a_span` supports it); shuffle | explanation from `a_span` (haiku) | 250 |
| **Belebele** eng_Latn | group by `flores_passage`; keep passages with ≥2 questions; 40–150 words; readDaily share of the 70/30 split | passage, questions, `mc_answer1..4`, key `correct_answer_num-1` | `title`, explanation | 250 |

- **Dedupe:** group key = context or passage hash. Cosmos near-duplicate contexts are common (same blog author), so Jaccard ≥ 0.8 → keep one.
- **Risks:**
  - Cosmos text is casual blog English with typos. Do not "fix" the text, which would change the key evidence. Drop noisy rows instead.
  - The LLM's second question must not duplicate the first. The verifier also checks this.
  - FORMAT expects "email, notice, chat, ad, schedule" text genres, and none of these sources has them. **Add 200 generated workplace-genre readDaily items** (§5 matrix: supplier email, shipment-delay notice, Teams chat, cafeteria notice, training schedule) so the real-world genre exists.

### 4.2 `readAcademic`: 500 permissive, plus an optional RACE tier

No permissive source has real exam questions at 150–220 words with 5 questions (Belebele has about 1.8 questions per passage). So the plan uses **permissive text with LLM-written questions in house style**. The 10 existing items use a fixed question set, kept exactly: main idea · detail · vocabulary-in-context ("closest in meaning to") · inference ("which X would the author most likely…") · rhetorical purpose ("why does the author write '…'").

| Source | Filters | Verbatim | LLM | Count |
|---|---|---|---|---:|
| **OpenStax** paragraphs | books: Principles of Management, Organizational Behavior, Intro to Business, Micro/Macroeconomics, Psychology 2e, Sociology 3e, Biology 2e, Environmental science; 1–3 consecutive paragraphs of one section, 150–220 words; drop paragraphs with equations, figure/table refs ("Figure 3.2", "Table"), lists, "Exercise", or boxed features; readAcademic share of the split | text; `title` = section title | 5 questions + options + explanations (sonnet), then verification | 300 |
| **OneStopEnglish** Adv | 150–220 word chunks on paragraph boundaries; articles **not** used by OneStopQA; C1 | text, title | 5 questions (sonnet), verified | 120 |
| **OneStopQA** Adv stitched | 2 adjacent paragraphs, 150–220 words → 6 real questions; drop the weakest 1 (the one the verifier finds hardest to justify) | text, 5 questions, key | explanations | 50 |
| **Belebele** same-`link` joins | join the passages of one source page to 150–220 words; ≥3 real questions, and the LLM adds the remainder | text, real questions | up to 2 more questions, explanations | 30 |
| *Optional NC:* **RACE-high** (`.nc.json`) | articles of 140–230 words with ≥4 questions; drop "_"-completion stems unless rewritten into a question, "all of the above", "NOT true" double negatives, and Chinese-school moral-story topics (keyword list); B2 | article, questions, options, key (A–D → 0–3) | a 5th question when only 4 exist, explanations | 600 |

- **Risks:**
  - LLM questions can have 2 defensible answers. The blind-solve plus "arguably right" check is the guard, and a reject rate above 15% means the generation prompt is wrong.
  - OpenStax prose can be dense. The cefr estimate will put much of it at C1, so prefer the business and psychology books for B2.
  - RACE is NC: personal study only, never redistributed.

### 4.3 `completeWords`: 1,500, fully programmatic (no LLM)

| Source | Filters | Count |
|---|---|---:|
| OneStopEnglish Int (B2) / Adv (C1) | 70–110 word windows on sentence boundaries; ≥4 sentences | 600 |
| OpenStax (same book list) | 70–110 words, ≥4 sentences, same exclusions as 4.2; the 30% share of the split | 700 |
| Belebele passages (30% share) | 70–110 words; B1+/B2. Passages average about 80 words, so many fall under the 70-word floor, and the estimate depends on the longer tail. | 200 |

- **Fields:** `passage` from `gaps.py` (§3.5); `skill: reading`; `cefr` from §3.7.
- **LLM:** none. The generator is deterministic.
- **Dedupe:** by window hash. Windows from one article are at most 1 per paragraph and share a group per article, so two chunks of one article are never served the same week.
- **Risks:**
  - Proper nouns and technical terms in gaps are hard to guess. Prefer windows where ≤2 of the 10 gapped words are capitalized mid-sentence or off the CEFR-J list.
  - A strictly alternating rule gaps more function words than the hand-made items do. That is acceptable, and it is TOEFL-authentic.

### 4.4 `listenResponse`: 1,000 permissive (MuTual optional)

| Source | Filters | Verbatim | LLM | Count |
|---|---|---|---|---:|
| **Taskmaster-1** self-dialogs and woz-dialogs; **Taskmaster-2** (all domains) | pick turn *t* where turn *t* is a question or request (ends with "?" or starts with can/could/would/do/what/when/how) and turn *t+1* is a 4–20 word human reply; drop disfluency-heavy turns | `prompt` = turn *t*; correct option = turn *t+1* | 3 wrong replies that are **on-topic but wrong** (wrong function, wrong tense or time, a misheard word, or answering a different question), explanation | 600 |
| **MultiWOZ 2.2** | same rule; prefer user→system pairs where the system reply is short | same | same | 400 |
| *Optional unclear:* **MuTual** train+dev (`.nc.json`) | detokenize and recapitalize; context ≤3 turns, so the prompt is the last line; drop items whose wrong options are only "logically" wrong in long contexts | prompt, 4 options, key | explanation | 600 |

- **Voice:** from the speaker gender tag when present (MuTual's m/f), else a deterministic hash.
- **Workplace relevance:** scheduling and rescheduling, booking and confirming are useful. Restaurant and movie turns are capped at 30% of the type.
- **Risks:**
  - Assistant-style system replies ("I have booked you a table…") are stilted. Prefer self-dialogs.
  - LLM distractors can be acceptable replies. The verifier must check "could a polite native speaker say this here?"

### 4.5 `listenConversation`: 400 permissive (DREAM optional)

| Source | Filters | Verbatim | LLM | Count |
|---|---|---|---|---:|
| **Taskmaster-1** self-dialogs | windows of 8–14 turns from one dialog; merge consecutive same-speaker turns; drop "um/uh"; 12–40 words per line | script lines → `speaker` A/B, voices female/male | 3–4 questions (gist, detail, speaker attitude or intent, what happens next), options, explanations | 150 |
| **MultiWOZ 2.2** | 8–14 turn windows that contain ≥2 slot values (time, price, place) | script | questions. **Detail distractors are built programmatically** from other dialogs' slot values of the same type, so there is no LLM guessing. Explanations come from the LLM. | 100 |
| **Generated workplace dialogues** (§5) | Supply-chain meetings: forecast change, supplier delay, QA hold, inventory variance, 1:1 status update | – | full script + questions (sonnet), verified | 150 |
| *Optional NC:* **DREAM** (`.nc.json`) | dialogues with ≥8 turns after merging; M/W → voices | script, questions, 3 options, key by string match | **4th distractor**, explanations | 500 |

- **Risk:** Taskmaster and MultiWOZ are transactional (booking). Meeting-style listening, which the learner needs most, comes only from the generated set, so keep that set ≥ 35% of what the weekly mock picks (blueprint `levels` plus the `topics` boost, §6).

### 4.6 `listenAnnouncement`: 200, generated (no open dataset)

- Matrix (§5): setting {office building, airport, train station, conference or webinar housekeeping, IT maintenance, warehouse safety, all-hands logistics, clinic or pharmacy, hotel} × purpose {delay, room or gate change, safety drill, policy change, system outage, event schedule, lost item} × 2 detail slots.
- LLM (sonnet) writes an 80–140 word monologue and 3 questions (purpose, detail, what listeners should do), then verification.
- The `voice` field alternates by hash.
- **Risk:** LLM announcements sound alike. Vary them by forcing the matrix slots, banning stock openers ("Attention, please"), and running the near-dedupe at 0.7.

### 4.7 `listenTalk`: 300 generated from permissive seeds (TOEFL-QA optional)

- **Seeds:** OpenStax sections (CC BY), one per lecture, taken from the books in 4.2 and never a passage already used in readAcademic or completeWords.
- **LLM** (sonnet) rewrites the seed into a **spoken** 180–250 word lecture ("So, today I want to…", one aside, one example) with 4 TOEFL listening questions (main idea, detail, function "why does the professor mention…", inference or attitude), then verification.
- `origin: adapted`. Attribution goes to OpenStax in `licenses.json`.
- *Optional unclear:* **TOEFL-QA** (`.nc.json`), about 100 stories. Lectures are condensed to 180–250 words by the LLM, keeping only the original questions whose evidence survives (verifier). Conversations go to listenConversation when they have 8–14 turns. The yield is about 100.

### 4.8 `buildSentence`: 1,000, permissive

| Source | Filters | Verbatim | LLM | Count |
|---|---|---|---|---:|
| **Taskmaster / MultiWOZ** replies | `context` = previous turn (≤25 words); `answer` = the reply, 8–16 words, one sentence, no names or numbers | context, answer | `accepted` orders only | 500 |
| **Tatoeba** (English sentences by self-declared native speakers; check that `user_languages` gives skill 5) | 8–16 words; B1+–C1; workplace boost | answer | `context` line (haiku: "what did the other person just say?"), `accepted` | 500 |

- **Chunks (`lib/chunks.py`):** spaCy noun chunks, verb groups (aux + verb + particle) and prepositional phrases stay together, giving 5–8 chunks. **Movable adverbials** (time and place phrases, "actually", "probably") are merged into a neighbour so they cannot float. Shuffle with a seed, and make sure the shuffled order is not the answer order.
- **`accepted`:** the LLM lists other fully grammatical orders of the same chunks (often empty), and each one is checked to use every chunk exactly once.
- **Dedupe:** answer-text hash; Tatoeba ids are partitioned (§3.8).
- **Risk:** an unlisted valid order marks a correct answer wrong. The adverbial merge and `accepted` are the guard, and a ≤3-adverbial cap keeps it manageable.

### 4.9 `grammarMC`: 2,500 permissive (dry-melon optional)

| Source | Method | Verbatim | LLM | Count |
|---|---|---|---|---:|
| **CoEdIT** `task == "gec"` | difflib token alignment of src→tgt; keep pairs with **exactly one** edit of 1–2 tokens; the sentence is `tgt` with the edit span as `____` (8–30 words) | sentence, correct answer, learner's wrong form as distractor 1 | distractors 2–3 (or rule-based, below), explanation, verification | 1,200 |
| **Rule-based blanking** of clean permissive sentences (OpenStax, OneStopEnglish, Tatoeba native, Taskmaster) | for each pattern, find a target token with a rule (table below) and blank it; distractors come from a fixed confusion set | sentence, answer | explanation, a Spanish-interference `note` where relevant, **verification (one correct option)** | 1,300 |
| *Optional unclear:* **dry-melon** grade 8–9 MCQ (`.nc.json`) | single `<blank>` → `____`; A–D → 0–3; drop items with 2 blanks, Chinese characters, or `is_answer_provided == false` that fail verification | sentence, options, key, `explanation` | verification only | 1,500 |

**`pattern` mapping.** The edit type is classified by `lib/grammar_rules.py`, and the same table maps dry-melon's `test_point` keywords.

| Edit / test_point | pattern | Distractor confusion set (rule-based) |
|---|---|---|
| both tokens are prepositions; "Prepositions" | `preposition` | the 3 most-confused with the answer: in/on/at, for/since/during, to/for/with, of/about, by/until; Spanish traps "depend **on**" (not "of"), "married **to**", "arrive **in/at**" |
| a/an/the/∅; "Articles" | `article` | a, an, the, "(no article)": the exact convention of the existing `grammar-a/b.json` items |
| same lemma, tense or aspect change; "Tense" | `tense` | other forms of the same verb: past simple / present perfect / past perfect / will |
| subject-verb number; "Agreement" | `agreement` | is/are/was/were, -s/∅ |
| to-inf ↔ -ing ↔ base; "Gerunds & Infinitives", "Verb Patterns" | `verb-pattern` | to do / doing / do / to doing |
| be + participle inserted or removed; "Passive" | `passive` | active / passive / wrong participle |
| who/which/that/whose/where; "Relative" | `relative` | the other 3 |
| modal swap; "Modal" | `modal` | must/should/might/can/have to |
| if-clause tense; "Conditional" | `conditional` | would have done / had done / will do / did |
| same stem, different suffix; "Word Formation", "Parts of Speech" | `word-form` | noun/verb/adjective/adverb of the stem (spaCy plus a derivation table) |
| however/although/despite/because/so/therefore/whereas; "Conjunctions", "Linkers" | `linker` | the same-slot linkers from `Content/vocab/linkers.json` |
| verb-noun or adjective-noun swap (make/do, strong/heavy, take/make a decision) | `collocation` | other light verbs or adjectives |
| none in the data | `false-friend` | **generated only**, from `Content/vocab/false-friends.json` (actually/currently, assist/attend, realize/carry out, …), 150 items |
| anything else (pronouns, comparatives, quantifiers…) | **drop**, counted in the report | – |

- **Explanation:** one English sentence naming the rule. Where the error is a typical Spanish-speaker one, add a short `note` style tip *inside* the explanation, since the grammarMC schema has no `note` field.
- **Dedupe:** the sentence with the answer filled in, plus the pattern. Cap each answer token at 60 items per pattern, so there are not 400 "in/on/at" items.
- **Risks:**
  - **Multiple correct answers.** This is the biggest risk, especially for prepositions and articles. The verifier's "arguably right" check must be strict, so expect a 20–30% reject rate.
  - CoEdIT edits sometimes change meaning, not grammar, so require a function-word or inflection edit.
  - Spread the patterns: target ≥120 items per pattern and ≤20% for any single pattern. The CEFR-J grammar profile CSV (`openlanguageprofiles/olp-en-cefrj`) works as a free coverage checklist.

### 4.10 `listenRepeat`: 1,000, permissive (no LLM)

| Source | Filters | Count |
|---|---|---:|
| **Tatoeba** English (native-owner sentences; listenRepeat share of the partition) | 8–18 words (FORMAT allows 6–22); no names, digits, or quotes; B1+–C1 by §3.7; workplace and meeting sentences boosted | 700 |
| **Common Voice** sentence text (CC0; **verify the repo path and the CC0 statement first**) | 8–18 words; drop parliamentary or encyclopedic lines with proper nouns; offensive-word blocklist | 300 |

- **Fields:** `voice` by hash; `cefr` §3.7.
- **LLM:** none (an optional haiku pass flags unnatural sentences).
- **Dedupe:** text hash, plus token-sort ≥ 0.9 against buildSentence answers.

### 4.11 Writing types: see §7 for kinds

| Type | Source | Verbatim | LLM | Count |
|---|---|---|---|---:|
| `writeEmail` | **generated** scenario matrix (§5). No open business-email prompt set exists. | – | `situation`, 3 `tasks`, `minWords` 80–150 | 400 |
| `writeDiscussion` | **args.me**: debates with both pro and con premises; conclusion → topic | the student posts' *ideas* (studentA = cleaned pro premise, studentB = cleaned con premise, each 30–60 words, rewritten for grammar) | `professor` post, student names, light rewrite | 400 |
| `interview` | args.me debate titles + generated personal ladders | the topic | 4 questions from personal to abstract | 150 |
| `lifeParagraph` | many kinds (§7) | see §7 | see §7 | 1,160 |

- **`mustUse` for every imported `lifeParagraph`:** pick 2–3 entries programmatically from `Content/vocab/`. Use ≥1 lexical chunk ≤4 words, chosen by the kind (linkers for opinion and compare, reporting verbs for summary, meeting phrases for reply and recap), at the item's level. Optionally add one structure instruction ("use the present perfect"). This keeps `GatePrompt.pick` off its `"follow up on"` fallback.
- **Dedupe:** prompt near-duplicates (embedding cosine ≥ 0.92) against everything, including the 110 existing prompts.

### 4.12 Vocab: +2,500 notes → ≥3,300 total

**Spine (headword + pos + cefr):** CEFR-J VP 1.5 (B1–B2) + Octanove C1, intersected with priority lists:
1. **BSL** (business) → tag `workplace`
2. **NAWL** → tag `academic`
3. NGSL ranks 800–2,809 → `core`
4. Wiktionary phrasal-verb and idiom entries for spine verbs → `phrasal` / `idiom`

Drop headwords already in `Content/vocab/` (match on headword + pos) and A1–A2 words.

| Field | Source | Verbatim / LLM |
|---|---|---|
| `headword`, `pos` | CEFR-J / Octanove | verbatim |
| `cefr` | CEFR-J level; EFLLex only as a silent cross-check | verbatim. **B1+/B2+ are never produced** (CEFR-J has no plus levels). |
| `definition` | NGSL-with-definitions xlsx for NGSL words; otherwise the kaikki gloss for the matched sense, simplified | verbatim, or haiku-simplified (B1 wording) |
| `es` | kaikki `translations[lang_code=es]` for the **sense matching the example** | the LLM picks the sense and the 1–3 Spanish words. If kaikki has none, haiku writes them (`origin: generated`). |
| `example`, `exampleEs` | Tatoeba EN–ES pair containing the exact headword form, 8–20 words, native-owned English | verbatim. If none fits, sonnet writes both, preferring workplace contexts for BSL words. |
| `cloze`, `answer` | derived: replace the first exact form occurrence with `____` | programmatic. Must satisfy `cloze + answer == example`. |
| `distractors` | 3 spine words with the same POS and **same inflection** (use `lemminflect` to inflect them), same CEFR band, edit distance ≥ 3 from the answer | rule-based candidates, then a haiku check that each is clearly wrong in the sentence |
| `collocations` | sonnet proposes 3; keep each only if it appears in the Tatoeba or Wiktionary example text or in the kaikki examples | generated + filter |
| `note` | false friend or Spanish trap only (from a curated list + haiku), else `""` | generated |
| `tags` | from the list membership above | programmatic |

- **Output:** `Content/vocab/bsl-workplace.json`, `nawl-academic.json`, `ngsl-core-b1.json`, `ngsl-core-b2.json`, `cefrj-c1.json`, `wikt-phrasal.json`.
- **License note:** the combined vocab files are a CC BY-SA derivative (NGSL, Wiktionary). Tatoeba is CC BY, and the sentence author id is recorded in `sourceId`.
- **Risks:**
  - Wrong sense pairing between the example and the Spanish gloss. The sonnet sense check sees both.
  - Inflected-distractor mismatch ("leveraged" vs "level") is caught by the Swift validator only for the count, so check inflection in Python.

---

## 5. Generated content: scenario matrices (`scripts/ingest/matrices/*.yaml`)

These cover the types where no open dataset exists: `writeEmail`, `listenAnnouncement`, workplace `listenConversation` and `readDaily` genres, `interview`, and the advice, reply, recap and chart writing kinds. Each matrix is a Cartesian product sampled without replacement. Each cell becomes one LLM request with the slots filled, which makes near-duplicates rare. `origin: generated`, `tier: generated`.

- **Workplace (a supply-chain workplace):**
  - situation {supplier delay, demand-forecast change, inventory variance found in a report, QA batch hold, shipment stuck in customs, meeting reschedule, new tool rollout, handover before vacation, data-quality issue in a dashboard, budget cut}
  - counterpart {manager, peer in another country, supplier, QA, finance, new team member}
  - function {request, update, complaint, apology, decline politely, escalate, follow-up after a meeting, ask for clarification}
  - register {formal, neutral, friendly}
- **Everyday:** {bank, landlord, gym, airline, doctor, online order, neighbour, friend's wedding, course registration} × the same functions.
- **Announcements:** see 4.6.
- **Interview ladders:** {work, learning English, technology, cities, health, travel, money, AI, teamwork, failure} × 4 rungs (personal fact → personal opinion → general trend → abstract or hypothetical).

Generated items go through the same validator, dedupe (with a stricter 0.7 near-duplicate threshold) and, for MCQs, verification.

---

## 6. Exposure control: avoiding repeats (one migration, one helper, three call sites)

**Migration** `registerExposure` (one line in `Persistence/Migrations.swift`):
```sql
CREATE TABLE exposure (itemId TEXT NOT NULL, groupId TEXT, surface TEXT NOT NULL,  -- gate|write|exam|review
                       kind TEXT, ts INTEGER NOT NULL);
CREATE INDEX exposure_item ON exposure(itemId); CREATE INDEX exposure_group ON exposure(groupId);
```
Insert a row when an item is **shown**, not only when it is answered. Backfill it once from `exam_response` and `writing_entry`.

**Helper** `ExposurePicker` (TenazCore, pure and tested):
- Input: candidate items, surface, now, seeded RNG.
- **Hard exclusion:** an item whose `id` *or* `group` was shown on any surface within the cooldown.

  | Content | Cooldown |
  |---|---|
  | Exam items | 180 days |
  | Writing prompts | never, until ≥90% of the eligible pool is used |
  | Listening and reading **texts** | by group, not by question |

- **Soft fallback** when the pool runs dry: least recently shown first. This keeps the existing "nearest level fills in" behaviour in `ItemPicker.pick`.
- **Kind rotation (writing):** never the same `kind` as the last 2 writing prompts on any surface. Weight the kinds toward the learner's weak areas: a weak writing band → more email, recap, rewrite; a weak speaking band → more interview.
- **Topic boost:** within the eligible pool, ×1.5 weight for items tagged `workplace` or `meetings`, with a cap of 50% of a session.

**Call sites:**
1. **`GatePrompt.pick`:** pick **per unlock**, not per day, through `ExposurePicker(surface: .gate)`. The prompt stays **sticky** until that gate is completed or skipped, so a reopened gate does not reshuffle. Only kinds that fit a chunk-based gate are eligible: personal, advice, opinion, story, compare, describe; not translate, correct or summary. This fixes "every time it's the same exercise".
2. **`TodayLoader.writePrompt`:** the same helper (`surface: .write`) over the same exposure table, so the gate and the Write screen never show the same prompt the same week.
3. **`ExamRunner`:** replace `recentItemIds(since: now - 14 days)` with the exposure table at 180 days, **group-aware**. The existing short-bank fallback stays. Placement and monthly mocks get first pick of never-seen items, which keeps measurement valid.

Vocabulary review is FSRS-scheduled, so repeats there are intended and untouched. Exam `vocab: true` picks should, however, skip notes due today in the deck.

---

## 7. New writing exercise kinds

New optional `kind` field. Existing items default to `personal` for `lifeParagraph` and `request` for `writeEmail`. `text` already exists on `ExamItem`. Add `reference: [String]?` for kinds graded against a model answer.

| kind | Item type | What the learner does | Source (license) | Verbatim / LLM | Gate? | Target |
|---|---|---|---|---|---|---:|
| `personal` | lifeParagraph | answers a question about the learner's life or work | existing + generated ladders | generated | yes | 250 |
| `advice` | lifeParagraph | "A colleague says: … What would you advise?" | generated matrix (EmpatheticDialogues is NC, so skipped) | generated | yes | 120 |
| `story` | lifeParagraph | continues a story opener in 40–60 words | WritingPrompts (MIT tag): strip `[ WP ]`, detokenize, 12–45 words, NSFW and violence blocklist | prompt verbatim (cleaned) | yes | 100 |
| `compare` | lifeParagraph | compares two options for a real decision (vendor A vs B, remote vs office) | args.me pro/con + generated | adapted | yes | 80 |
| `describe` | lifeParagraph | describes a process or place the learner knows (the learner's commute, a planning cycle) | generated | generated | yes | 60 |
| `summary` | lifeParagraph | summarises a short text in 2–3 sentences | Dolly `summarization` (CC BY-SA 3.0), context 80–180 words; OpenStax paragraphs (CC BY) | `text` verbatim, `reference` = Dolly response | no | 120 |
| `rewrite` | lifeParagraph | "Rewrite this for your manager", or more simply | CoEdIT formality / simplification / coherence (Apache tag) + generated blunt Slack messages | `text` = src, `reference` = tgt | no | 120 |
| `correct` | lifeParagraph | fixes the mistakes in a short learner text | CoEdIT gec (multi-edit pairs, 2–4 edits) | `text` = src, `reference` = tgt | no | 100 |
| `translate` | lifeParagraph | translates a Spanish sentence or two into natural English | Tatoeba spa→eng (CC BY 2.0 FR); `reference` = all linked English translations | verbatim | no | 150 |
| `chart` | lifeParagraph | describes a small KPI table: trend, peak, comparison | **synthetic** tables built by script (OTIF %, inventory days, forecast accuracy by month or site), rendered as text in `text` | `reference` = LLM key points | no | 60 |
| `request` / `complaint` / `update` | writeEmail | the existing email task | generated matrix (§5) | generated | no | 250 |
| `reply` | writeEmail | replies to an incoming message (the `situation` quotes it) | generated matrix | generated | no | 100 |
| `recap` | writeEmail | turns 5–7 bullet meeting notes into a follow-up email | generated (supply-chain meetings) | generated | no | 50 |
| `opinion` | writeDiscussion | academic discussion post | args.me | adapted | no | 300 |
| `proscons` | writeDiscussion | professor asks for advantages and disadvantages | args.me pro/con pairs | adapted | no | 100 |
| `interview` | interview | 4-rung spoken interview | args.me titles + ladders | generated | no | 150 |

Totals: lifeParagraph ≈ 1,160 · writeEmail 400 · writeDiscussion 400 · interview 150 = **≈ 2,100 writing prompts** (≥1,500 target).

For `summary`, `rewrite`, `correct`, `translate` and `chart`, set `minWords` from the task (e.g. 0.6–1.2 × the `text` word count, clamped to 40–80). The validator needs a rule: these kinds require `text`.

---

## 8. App and model changes needed (small, do in phase 0)

1. **`ContentModels.swift` `ExamItem`:** add optional `kind`, `reference: [String]?`, `source`, `license`, `tier`, `group`, `origin`, `topics: [String]?`. Encode and decode them in the custom coder. `VocabEntry` gets optional `source`, `license`.
2. **`ContentValidator`:** kinds `summary|rewrite|correct|translate|chart` require a non-empty `text`. Unknown `kind` values are rejected. (Optional) enforce the FORMAT.md length bounds the Python port already checks.
3. **`GradingRubric.taskPrompt(for:)`:** `lifeParagraph` and `writeEmail` cases include `kind`, `text` and `reference` ("compare meaning with the reference; do not require identical wording"). Each kind gets a one-line criterion: summary covers the main point; rewrite keeps meaning and changes register; correct fixes all errors; translate is accurate and natural; chart reports the trend and one comparison.
4. **`GatePrompt.pick`, `TodayLoader.writePrompt`, `ExamRunner`:** switch to `ExposurePicker` (§6), plus the `exposure` migration.
5. **Write screen UI:** show `text` above the input for the text-based kinds. The placeholder comes from `kind` (one-line pointer; the UI fix itself is separate).
6. **`FORMAT.md`:** document the new fields, `licenses.json`, the `.nc.json` convention and the kind list. Replace the "all content is original" sentence.
7. **Size budget:** the bundle goes from 1 MB to about 15–25 MB of JSON, all decoded at launch. Measure `ContentLibrary` load time after phase 2. If it is over 300 ms, cache a decoded binary, or index `items` by type once (several call sites filter the whole array).

---

## 9. Build order (cheapest LLM cost first, so the bank grows quickly)

| Phase | Work | LLM cost | Bank after |
|---|---|---|---|
| **P0** | `lib/` + Python validator + `licenses.json` + FORMAT.md; app changes §8 (fields, exposure migration, `ExposurePicker`, gate per-unlock fix) | none | same items, **no more same-day gate repeats** |
| **P1 (zero LLM)** | completeWords (OneStopEnglish, OpenStax, Belebele); listenRepeat (Tatoeba, Common Voice); vocab spine skeleton (headword/pos/cefr/definition from NGSL xlsx, Tatoeba examples, cloze) | none | +2,500 items |
| **P2 (one sentence per item)** | OneStopQA, Belebele readDaily (explanations); CoEdIT + rule-based grammarMC (explanation + verify); listenResponse (Taskmaster/MultiWOZ: 3 distractors + verify); buildSentence; writing kinds from data (translate, rewrite, correct, summary, story, opinion/proscons); vocab es/distractor checks | low | ≈ +6,500 |
| **P3 (generated questions)** | Cosmos 2nd question; readAcademic questions; listenConversation questions; listenTalk lectures; matrices (writeEmail, announcements, workplace dialogues, readDaily genres, interview, advice/reply/recap/chart) | high | reaches all §1 minimums |
| **P4 (optional, NC/unclear)** | RACE-high, DREAM, MuTual, TOEFL-QA, dry-melon, and RACE-C if verified, into `.nc.json` files | low–medium | +3,300 exam-realistic items |

---

## 10. Per-converter checklist (what the engineer builds next)

Each `sources/<name>.py` has the same five commands. Its spec is the corresponding row in §4.

| # | Converter | Input (fetch) | Output file(s) |
|---|---|---|---|
| C01 | `onestopqa` | HF `malmaud/onestop_qa` parquet (~220 KB) | `read-daily-onestopqa.json`, `read-academic-onestopqa.json` |
| C02 | `belebele` | HF `facebook/belebele` eng_Latn test | `read-daily-belebele.json`, `read-academic-belebele.json`, `complete-words-belebele.json` |
| C03 | `cosmosqa` | HF `allenai/cosmos_qa` via `refs/convert/parquet` | `read-daily-cosmos.json` |
| C04 | `onestopenglish` | git clone `nishkalavallabhi/OneStopEnglishCorpus` (Int-Txt, Adv-Txt) | `complete-words-ose.json`, `read-academic-ose.json` |
| C05 | `openstax` | HF `HuggingFaceTB/openstax_paragraphs` (6.5 MB) | `complete-words-openstax.json`, `read-academic-openstax.json`, `listen-talk-openstax.json`, writing `summary` seeds |
| C06 | `taskmaster` | GitHub `google-research-datasets/Taskmaster` TM-1-2019 + TM-2-2020 JSON (**verify paths**) | `listen-response-taskmaster.json`, `listen-conversation-taskmaster.json`, `build-sentence-taskmaster.json` |
| C07 | `multiwoz` | HF `pfb30/multi_woz_v22` | `listen-response-multiwoz.json`, `listen-conversation-multiwoz.json`, `build-sentence-multiwoz.json` |
| C08 | `tatoeba` | `downloads.tatoeba.org/exports/per_language/{eng,spa}/…_sentences(_detailed).tsv.bz2`, `eng-spa_links.tsv.bz2`, `user_languages` | `listen-repeat-tatoeba.json`, `build-sentence-tatoeba.json`, `life-translate-tatoeba.json`, vocab examples |
| C09 | `commonvoice` | GitHub `common-voice/common-voice` English sentence text (**verify path + CC0**) | `listen-repeat-commonvoice.json` |
| C10 | `coedit` | HF `grammarly/coedit` train/validation jsonl | `grammar-coedit.json`, `life-rewrite-coedit.json`, `life-correct-coedit.json` |
| C11 | `grammar_rules` | stage outputs of C04/C05/C06/C08 (clean sentences) + `false-friends.json` | `grammar-rules.json` |
| C12 | `argsme` | `webis/args_me` first ~4 MB by HTTP Range, more as needed | `write-discussion-argsme.json`, `interview-argsme.json`, `life-compare-argsme.json` |
| C13 | `writingprompts` | `euclaise/writingprompts` via the rows API (prompts only) | `life-story-wp.json` |
| C14 | `dolly` | `databricks/databricks-dolly-15k` (category = summarization) | `life-summary-dolly.json` |
| C15 | `matrices` | `matrices/*.yaml` | `write-email-gen.json`, `listen-announcement-gen.json`, `listen-conversation-work-gen.json`, `read-daily-genres-gen.json`, `interview-gen.json`, `life-{personal,advice,describe,chart}-gen.json` |
| C16 | `vocab` | CEFR-J + Octanove CSVs, NGSL/BSL/NAWL files, kaikki stream subset, Tatoeba (C08) | `Content/vocab/{bsl-workplace,nawl-academic,ngsl-core-b1,ngsl-core-b2,cefrj-c1,wikt-phrasal}.json` |
| C17* | `race` (NC) | HF `ehovy/race` config `high`, train shard | `read-academic-race.nc.json` |
| C18* | `dream` (NC) | GitHub raw `nlpdata/dream/data/{train,dev,test}.json` | `listen-conversation-dream.nc.json` |
| C19* | `mutual` (unclear) | GitHub raw `Nealcly/MuTual/data/mutual/{train,dev}` | `listen-response-mutual.nc.json` |
| C20* | `toeflqa` (unclear) | GitHub `iamyuanchung/TOEFL-QA/data` | `listen-talk-toeflqa.nc.json` |
| C21* | `drymelon` (unclear) | HF `dry-melon/...` grade8/9 `Multiple-Choice-Question.jsonl` | `grammar-drymelon.nc.json` |

\* = optional NC/unclear tier.

**Acceptance criteria, per converter:**
1. The Python validator reports 0 problems on the emitted file.
2. Every id is unique across all of `Content/`.
3. `reports/<source>.md` lists the count after each filter, the reject reasons, the verification reject rate (if above 30%, fix the prompt rather than ship), the level and pattern/kind distribution, and a 30-item random sample that a human has skimmed.
4. The `licenses.json` entry is written.
5. **`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` and `scripts/verify.sh m3 --selftest content` pass**, with `ContentValidator.cleaned` reporting zero dropped entries.

---

Plan file: (scratchpad, not tracked)