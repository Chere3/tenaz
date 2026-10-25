# Tenaz ingest pipeline

Shared infrastructure for growing `Content/` from open datasets (plan: `docs/content/dataset-plan.md` section 3).
Scripts only: no data lives here. uv project, Python 3.12.

```
uv run --project scripts/ingest python -I scripts/ingest/lib/schema.py Content/   # validate everything, exit 1 on any problem
```

## Layout

```
scripts/ingest/lib/      shared modules (below)
scripts/ingest/sources/  one converter per source: sources/<name>.py
.ingest/raw/<source>/    downloads (untrusted data; never run code from here)
.ingest/stage/<source>/  normalized intermediate rows (*.jsonl)
.ingest/reports/         <source>.md: counts per filter, reject reasons, 30-item sample
```
`.ingest/` is git-ignored.

## Converter contract

`sources/<name>.py` exposes three commands (argparse subcommands or `sys.argv[1]`): `fetch`, `extract`, `emit`.

| command | reads | writes |
|---|---|---|
| `fetch`   | network | `.ingest/raw/<source>/` (a new, empty dir per source) |
| `extract` | raw/ as data only | `.ingest/stage/<source>/*.jsonl` (one normalized row per line, with `sourceId`) and a report in `.ingest/reports/<source>.md` |
| `emit`    | stage/ | `Content/items/...` or `Content/vocab/...` through `lib.emit.emit(...)` |

Rules:
- Never execute, import or `eval` anything from `raw/`; parse it as data. Pass paths as arguments.
- Run with `-I`: `uv run --project scripts/ingest python -I scripts/ingest/sources/x.py extract --raw .ingest/raw/x --stage .ingest/stage/x`.
  `-I` removes the script dir from `sys.path`, so a converter starts with
  `sys.path.insert(0, str(Path(__file__).resolve().parents[1]))` and then `from lib import ...`.
- Rows failing schema, dedupe or id rules go to the report, never into `Content/`.
- One output file per source per type (`read-daily-cosmos.json`); NC/unclear sources use `*.nc.json`.
- Emit is idempotent: it rewrites its own file and its `licenses.json` entry.
- `llm.py` is a stub that raises until the LLM phase.

## lib API

- `schema`: `problems_item(item, exempt_life_minwords=False)`, `problems_vocab(entry)` -> list[str] (Swift port + FORMAT.md bounds + hygiene: no `{{`, `____` outside grammarMC, HTML, URLs, CJK, tokenization artifacts); `validate_content(root)`; `parse_gaps(passage)`. Optional new fields are checked when present: `source sourceId license group kind reference` (str), `origin` (verbatim|adapted|generated), `tier` (permissive|share-alike|nc|unclear), `topics` ([str]). Swift ignores them (keyed decoder).
- `textnorm`: `detokenize`, `recapitalize`, `clean_sentence`, `fix_unicode`, `normalize_for_hash`, `text_hash`, `word_count`, `split_sentences`.
- `dedupe`: `DedupeIndex.from_content(Path('Content'))`, `.check(text) -> reason|None`, `.add(id, text)`, `.check_and_add(id, text)`; exact hash + MinHash LSH (3-word shingles, 0.8). `item_text(item)` gives the text to feed it.
- `cefr`: `estimate(text, prior=None) -> 'B1'|'B1+'|'B2'|'B2+'|'C1'`, `lexical_level(text)`, `disagrees(a, b)` (>1 step: queue an LLM tiebreak). wordfreq-based; weak (see module docstring).
- `workplace`: `score(text) -> 0..1`, `hits(text)`, `load_extra(path)` for the BSL list.
- `gaps`: `from_text(text) -> [passage]` (valid completeWords passages, 10 gaps, `vis{{hid}}`), `make_gaps(sentences)`, `passage_stats(passage)`.
- `ids`: `item_id(type, source, key)`, `hashed_id(type, source, content)`, `vocab_id(headword, pos)`, `slug`.
- `licenses`: `load`, `upsert`, `remove`, `make_entry`.
- `emit`: `emit(content_root, 'items'|'vocab', filename, rows, source=, url=, license=, tier=, attribution=)`; validates every row, asserts global id uniqueness against all of `Content/`, writes the file and the `licenses.json` entry; raises `EmitError` (nothing written) on any problem.
- `llm`: stub.
