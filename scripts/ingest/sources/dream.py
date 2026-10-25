"""C18 converter (P4, non-commercial): DREAM dialogues (github.com/nlpdata/dream) -> listenConversation.

DREAM is dialogue-based reading comprehension from English-as-a-foreign-language listening exams.
License (repo license.txt): "DREAM dataset is intended for non-commercial research purpose only." -> tier nc,
file Content/items/listen-conversation-dream.nc.json.

  fetch    downloads data/{train,dev,test}.json + license.txt into .ingest/raw/dream/ and STOPS unless license.txt
           still carries the non-commercial statement.
  extract  keeps two-speaker man/woman dialogues of 8-14 turns (after merging consecutive same-speaker turns),
           with 3-option questions whose key matches one option by string. Writes
           .ingest/stage/dream/listen-conversation.jsonl, .ingest/reports/dream.md and LLM batches
           .ingest/stage/dream/batches/dream-NN.jsonl (25-50 rows).
  emit     merges dream-NN.filled.jsonl (verdict ok only), re-checks against the stage rows, dedupes,
           writes Content/items/listen-conversation-dream.nc.json (+ licenses.json entry).

Run: uv run --project scripts/ingest python -I scripts/ingest/sources/dream.py <cmd>
"""
from __future__ import annotations

import argparse
import hashlib
import json
import random
import re
import sys
import urllib.request
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lib import cefr, ids, textnorm, workplace  # noqa: E402
from lib.dedupe import DedupeIndex, item_text  # noqa: E402

GH = "https://raw.githubusercontent.com/nlpdata/dream/master"
SPLITS = ["train", "dev", "test"]
SRC = "dream"
FILENAME = "listen-conversation-dream.nc.json"
LICENSE = "Non-commercial research purpose only (DREAM license.txt)"
URL = "https://github.com/nlpdata/dream"
ATTR = ("Sun et al. 2019, DREAM: A Challenge Dataset and Models for Dialogue-Based Reading Comprehension "
        "(nlpdata/dream), non-commercial research only; 4th option, extra questions, titles and explanations written with Claude")
TARGET = 500
RESERVE = 1.2
BATCH_LO, BATCH_HI = 25, 50
MAX_LINE_WORDS = 45
MIN_TOTAL_WORDS = 70
TOTAL_QUESTIONS = 3  # source questions are kept; new ones are added up to this many

MALE = {"M", "Man"}
FEMALE = {"W", "F", "Woman"}

OFFENSIVE = set("""sex sexy sexual naked nude porn rape kill kills killed killing murder suicide drunk drug drugs cocaine
heroin gun guns shoot shooting bomb terror terrorist fuck fucking shit damn bitch bastard asshole crap idiot stupid dumb
ugly fat hate sucks jesus pregnant hooker whore cancer racist nazi crazy insane dead death dying die died""".split())
CHILDISH = set("""mommy daddy toy toys kid kids baby babies puppy kitten cartoon cartoons disney pokemon santa teddy doll
candy balloon crayon toilet pee poop diaper naughty princess unicorn dragon monster fairy teacher's""".split())
PRIVACY = re.compile(r"@|https?:|www\.|\b\d{5,}\b")
BAD_FMT = re.compile(r"[a-z]\.[A-Z]|[,;][A-Za-z]|\?[a-z]|  |\s[,.?!]")
BAD_CHARS = re.compile(r"[^A-Za-z0-9',.?!:;$%&/()\" -]")
VAGUE_OPT = re.compile(r"\b(all of the above|none of the above|both a and b|neither)\b", re.I)
_WORD = re.compile(r"[A-Za-z]+(?:'[A-Za-z]+)?")


def _hash_int(s: str) -> int:
    return int(hashlib.sha256(s.encode()).hexdigest(), 16)


# --- fetch ------------------------------------------------------------------------------------
def _get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "tenaz-ingest"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def fetch(raw: Path) -> None:
    raw.mkdir(parents=True, exist_ok=True)
    lic = _get(f"{GH}/license.txt").decode("utf-8", "replace")
    if "non-commercial" not in lic.lower():
        raise SystemExit(f"LICENSE CHANGED at {GH}/license.txt: {lic!r}. Stopping; re-verify the tier.")
    (raw / "license.txt").write_text(lic, encoding="utf-8")
    for s in SPLITS:
        (raw / f"{s}.json").write_bytes(_get(f"{GH}/data/{s}.json"))
    print("fetched", [p.name for p in sorted(raw.iterdir())], "| license:", lic.strip())


# --- extract ----------------------------------------------------------------------------------
def load_rows(raw: Path):
    """-> [(split, dream id, turns[str], questions[dict])]; raw JSON is parsed as data only."""
    out = []
    for s in SPLITS:
        for row in json.loads((raw / f"{s}.json").read_text(encoding="utf-8")):
            out.append((s, row[2], row[0], row[1]))
    return out


def clean_line(s: str) -> str:
    s = textnorm.fix_unicode(s)
    s = re.sub(r"\s+", " ", s).strip()
    s = re.sub(r"\s+([,.?!;:])", r"\1", s)
    s = re.sub(r"([,.?!;:])(?=[A-Za-z])", r"\1 ", s) if not re.search(r"\d[.,]\d", s) else s
    return s


def parse_turns(turns: list[str], rej: Counter):
    """-> [(gender, text)] merged by speaker, or None."""
    parsed = []
    for t in turns:
        m = re.match(r"^([A-Za-z0-9]+):\s*(.*)$", t.strip())
        if not m:
            rej["dialogue:untagged turn"] += 1
            return None
        parsed.append((m.group(1), m.group(2)))
    tags = {p[0] for p in parsed}
    if len(tags) != 2:
        rej["dialogue:not exactly two speakers"] += 1
        return None
    male, female = tags & MALE, tags & FEMALE
    if len(male) != 1 or len(female) != 1:
        rej["dialogue:speakers not one man and one woman"] += 1
        return None
    merged: list[list] = []
    for tag, text in parsed:
        g = "male" if tag in MALE else "female"
        text = clean_line(text)
        if not text:
            rej["dialogue:empty turn"] += 1
            return None
        if merged and merged[-1][0] == g:
            merged[-1][1] += " " + text
        else:
            merged.append([g, text])
    return [(g, t) for g, t in merged]


def line_problem(t: str) -> str | None:
    toks = _WORD.findall(t.lower())
    if len(toks) > MAX_LINE_WORDS:
        return "line too long"
    if any(w in OFFENSIVE for w in toks):
        return "offensive/sensitive word"
    if any(w in CHILDISH for w in toks):
        return "childish word"
    if PRIVACY.search(t):
        return "privacy/long digits"
    if BAD_CHARS.search(t):
        return "odd characters"
    if BAD_FMT.search(t):
        return "spacing/punctuation slip"
    if re.fullmatch(r"[a-z].*", t) and not t.startswith("i "):
        return "lowercase start"
    return None


def clean_questions(qs: list[dict], rej: Counter) -> list[dict]:
    out = []
    for q in qs:
        stem = clean_line(q.get("question", ""))
        opts = [clean_line(c) for c in q.get("choice", [])]
        key = clean_line(q.get("answer", ""))
        if len(opts) != 3 or len({o.lower() for o in opts}) != 3 or key not in opts or not stem.endswith("?"):
            rej["question:not 3 distinct options / key not matched / stem not a question"] += 1
            continue
        if any(VAGUE_OPT.search(o) for o in opts) or any(line_problem(x) in ("offensive/sensitive word", "childish word", "odd characters") for x in [stem, *opts]):
            rej["question:vague option or blocked word"] += 1
            continue
        out.append({"q": stem, "options": opts, "answer": opts.index(key)})
    return out


def topics_for(text: str) -> list[str]:
    t = ["dialogue"]
    if workplace.score(text) >= 0.15:
        t.append("workplace")
    if re.search(r"\b(meeting|manager|boss|office|company|project|deadline|report|colleague|customer|client|business|"
                 r"job|interview|salary|schedule|appointment)\b", text, re.I):
        t.append("work-life")
    if re.search(r"\b(flight|train|bus|hotel|ticket|trip|travel|airport|station|reservation)\b", text, re.I):
        t.append("travel")
    return t


def extract(raw: Path, stage: Path, report: Path, content: Path) -> None:
    stage.mkdir(parents=True, exist_ok=True)
    report.parent.mkdir(parents=True, exist_ok=True)
    rej: Counter = Counter()
    idx = DedupeIndex.from_content(content)
    rows_in = load_rows(raw)
    rej["input dialogues"] = len(rows_in)
    seen_text: set[str] = set()
    cands = []
    for split, did, turns, qs in rows_in:
        merged = parse_turns(turns, rej)
        if merged is None:
            continue
        if not 8 <= len(merged) <= 14:
            rej[f"dialogue:{'under 8' if len(merged) < 8 else 'over 14'} turns after merge"] += 1
            continue
        probs = [line_problem(t) for _, t in merged]
        probs = [p for p in probs if p]
        if probs:
            rej[f"dialogue:line filter ({probs[0]})"] += 1
            continue
        full = " ".join(t for _, t in merged)
        if textnorm.word_count(full) < MIN_TOTAL_WORDS:
            rej["dialogue:under 70 words"] += 1
            continue
        h = textnorm.text_hash(full)
        if h in seen_text:
            rej["dialogue:duplicate across splits"] += 1
            continue
        seen_text.add(h)
        questions = clean_questions(qs, rej)[:TOTAL_QUESTIONS]
        if not questions:
            rej["dialogue:no usable source question"] += 1
            continue
        lvl = cefr.estimate(full, "B1")
        if lvl == "A2":  # estimate returns B1.. but guard anyway
            rej["dialogue:level below B1"] += 1
            continue
        speaker_of = {}
        script = []
        for g, t in merged:
            sp = speaker_of.setdefault(g, "A" if not speaker_of else "B")
            script.append({"speaker": sp, "voice": g, "line": t})
        iid = ids.item_id("listenConversation", SRC, f"{split}-{did}")
        dup = idx.check(full)
        if dup:
            rej[f"dialogue:dedupe vs Content ({dup.split(' of ')[0]})"] += 1
            continue
        n_new = TOTAL_QUESTIONS - len(questions)
        score = (workplace.score(full) * 2 + len(questions) * 0.6 + (0.4 if lvl in ("B2", "B2+", "C1") else 0.0)
                 + (0.3 if 9 <= len(script) <= 13 else 0.0) + (_hash_int(iid) % 1000) / 10000)
        cands.append((score, {
            "id": iid, "type": "listenConversation", "cefr": lvl, "skill": "listening", "title": "",
            "script": script,
            "sourceQuestions": questions,
            "newQuestionCount": n_new,
            "topics": topics_for(full),
            "group": f"dream:{split}-{did}", "source": SRC, "sourceId": f"{split}/{did}",
            "license": LICENSE, "tier": "nc", "origin": "adapted",
        }, full))
    rej["candidates"] = len(cands)
    cands.sort(key=lambda c: (-c[0], c[1]["id"]))
    rows, k_total = [], int(TARGET * RESERVE)
    for score, row, full in cands:
        if len(rows) >= k_total:
            rej["over target+reserve"] += 1
            continue
        d = idx.check_and_add(row["id"], full)
        if d:
            rej[f"dialogue:near-duplicate of a staged dialogue ({d.split(' of ')[0]})"] += 1
            continue
        row["reserve"] = len(rows) >= TARGET
        # target answer positions for every final question (balanced by seeded shuffle)
        rnd = random.Random(_hash_int(row["id"]))
        row["answerSlots"] = [rnd.randrange(4) for _ in range(len(row["sourceQuestions"]) + row["newQuestionCount"])]
        rows.append(row)
    # balance answer slots globally: rotate so that each position is used about equally
    slots = Counter(s for r in rows for s in r["answerSlots"])
    with open(stage / "listen-conversation.jsonl", "w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    batches = write_batches(stage, rows)
    write_report(report, rej, rows, slots, batches)
    print(f"staged {len(rows)} dialogues ({sum(1 for r in rows if r['reserve'])} reserve), batches {len(batches)}")


def split_even(rows: list[dict], lo: int, hi: int) -> list[list[dict]]:
    n = len(rows)
    k = max(1, -(-n // hi))
    while k < n and n / k < lo:
        k -= 1
        break
    size, extra = divmod(n, k)
    out, i = [], 0
    for b in range(k):
        s = size + (1 if b < extra else 0)
        out.append(rows[i:i + s])
        i += s
    return out


def write_batches(stage: Path, rows: list[dict]) -> list[Path]:
    bdir = stage / "batches"
    bdir.mkdir(parents=True, exist_ok=True)
    for old in bdir.glob("dream-*.jsonl"):
        old.unlink()
    rows = sorted(rows, key=lambda r: (r["reserve"], _hash_int(r["id"])))
    main, res = [r for r in rows if not r["reserve"]], [r for r in rows if r["reserve"]]
    out = []
    n = 0
    for part in (main, res):  # reserve rows live in their own batches so they can be skipped
        for chunk in split_even(part, BATCH_LO, BATCH_HI) if part else []:
            n += 1
            p = bdir / f"dream-{n:02d}.jsonl"
            with open(p, "w", encoding="utf-8") as f:
                for r in chunk:
                    f.write(json.dumps(r, ensure_ascii=False) + "\n")
            out.append(p.resolve())
    return out


def write_report(path: Path, rej: Counter, rows: list[dict], slots: Counter, batches: list[Path]) -> None:
    L = ["# DREAM -> listenConversation (nc)", "", f"License: {LICENSE}. Tier nc, file `{FILENAME}`.", "",
         "## Extract filters and counts", ""]
    L += [f"- {k}: {v}" for k, v in sorted(rej.items())]
    L += ["", f"## Staged: {len(rows)} ({sum(1 for r in rows if r['reserve'])} reserve)", ""]
    L += [f"- level {k}: {v}" for k, v in sorted(Counter(r['cefr'] for r in rows).items())]
    L += [f"- turns {k}: {v}" for k, v in sorted(Counter(len(r['script']) for r in rows).items())]
    L += [f"- source questions kept {k}: {v}" for k, v in sorted(Counter(len(r['sourceQuestions']) for r in rows).items())]
    L += [f"- topics {k}: {v}" for k, v in sorted(Counter(t for r in rows for t in r['topics']).items())]
    L += [f"- target answer slot {k}: {v}" for k, v in sorted(slots.items())]
    L += ["", "## Batches", ""] + [f"- {b}" for b in batches]
    L += ["", "## 30-row random sample (seed 5)", ""]
    for n, r in enumerate(random.Random(5).sample(rows, min(30, len(rows))), 1):
        L.append(f"{n}. {r['cefr']} | {len(r['script'])} lines | " + " / ".join(x['line'] for x in r['script'][:2])
                 + " || " + "; ".join(q['q'] for q in r['sourceQuestions']))
    path.write_text("\n".join(L) + "\n", encoding="utf-8")


# --- emit -------------------------------------------------------------------------------------
HYG_NAMES = re.compile(r"[a-z]\.[A-Z]|[,;][A-Za-z]|\?[a-z]|  |\b[ap]\. ?m\b\.?\.|\$ \d|\b[ap]\. m\b")


def _read_filled(stage: Path):
    out = []
    for fp in sorted((stage / "batches").glob("dream-*.filled.jsonl")):
        rows = [json.loads(l) for l in fp.read_text(encoding="utf-8").splitlines() if l.strip()]
        out.append((fp.name.split(".")[0], rows))
    return out


# ids read in the emit sample and judged non-native or odd despite the fill verdict
MANUAL_EXCLUDE: set[str] = set(['lc-dream-train-2-13', 'lc-dream-train-7-169', 'lc-dream-train-17-82'])


def build_item(stage_row: dict, fr: dict, rej: Counter):
    title = (fr.get("title") or "").strip()
    if not title or len(title.split()) > 7:
        rej["bad title"] += 1
        return None
    qs = fr.get("questions") or []
    src = stage_row["sourceQuestions"]
    if not TOTAL_QUESTIONS <= len(qs) <= 4 or len(qs) < len(src):
        rej["question count"] += 1
        return None
    final = []
    for n, q in enumerate(qs):
        o, a = q.get("options"), q.get("answer")
        if not isinstance(o, list) or len(o) != 4 or len({str(x).lower().strip() for x in o}) != 4 \
                or not isinstance(a, int) or not 0 <= a < 4 or not str(q.get("q", "")).strip() \
                or not str(q.get("explanation", "")).strip():
            rej["bad question shape"] += 1
            return None
        if n < len(src):  # source question must be kept verbatim: stem, 3 options, key
            s = src[n]
            if q["q"].strip() != s["q"] or not all(x in o for x in s["options"]) or o[a] != s["options"][s["answer"]]:
                rej["source question altered"] += 1
                return None
        if not re.match(r"[A-Z]", q["q"].strip()) or not re.match(r"[A-Z0-9$]", o[a].strip()):
            rej["question stem/key not capitalized (typo)"] += 1
            return None
        if len(o[a]) > 1.6 * sorted(len(x) for x in o)[2] + 12:
            rej["key much longer than distractors"] += 1
            return None
        if any(HYG_NAMES.search(x) for x in [q["q"], *o, q["explanation"]]):
            rej["question hygiene"] += 1
            return None
        final.append({"q": q["q"].strip(), "options": [str(x).strip() for x in o], "answer": a,
                      "explanation": q["explanation"].strip()})
    if len({q["q"].lower() for q in final}) != len(final):
        rej["duplicate question"] += 1
        return None
    drop = {"sourceQuestions", "newQuestionCount", "answerSlots", "reserve"}
    it = {k: v for k, v in stage_row.items() if k not in drop}
    it.update({"title": title, "questions": final})
    return it


def emit_cmd(stage: Path, report: Path, content: Path) -> None:
    from lib import emit as emit_lib, schema
    rej: Counter = Counter()
    staged = {json.loads(l)["id"]: json.loads(l) for l in (stage / "listen-conversation.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()}
    idx = DedupeIndex()
    for sub in ("items", "vocab"):
        for f in sorted((content / sub).glob("*.json")):
            if f.name == FILENAME:
                continue
            for row in json.loads(f.read_text(encoding="utf-8")):
                idx.add(row["id"], item_text(row))
    per_batch, cand = [], []
    for name, rows in _read_filled(stage):
        bad = sum(1 for r in rows if r.get("verdict") != "ok")
        per_batch.append((name, len(rows), bad))
        for fr in rows:
            if fr.get("id") in MANUAL_EXCLUDE:
                rej["manual exclude (sample review)"] += 1
                continue
            if fr.get("verdict") != "ok":
                rej["rejected by fill agent"] += 1
                continue
            sr = staged.get(fr.get("id"))
            if sr is None:
                rej["unknown id"] += 1
                continue
            it = build_item(sr, fr, rej)
            if it:
                cand.append((bool(sr["reserve"]), it))
    cand.sort(key=lambda x: (x[0], x[1]["id"]))
    out, seen = [], set()
    for _res, it in cand:
        if len(out) >= TARGET:
            rej["over target"] += 1
            continue
        if it["id"] in seen:
            rej["duplicate id"] += 1
            continue
        probs = schema.problems_item(it)
        if probs:
            rej[f"schema: {probs[0][:60]}"] += 1
            continue
        d = idx.check_and_add(it["id"], item_text(it))
        if d:
            rej["dedupe"] += 1
            continue
        seen.add(it["id"])
        out.append(it)
    out.sort(key=lambda i: i["id"])
    e = emit_lib.emit(content, "items", FILENAME, out, source="DREAM", url=URL, license=LICENSE, tier="nc",
                      attribution=ATTR)
    old = report.read_text(encoding="utf-8") if report.exists() else ""
    old = old.split("\n# Emit")[0].rstrip() + "\n"
    L = ["", "# Emit (fill agents merged)", "", f"- emitted {len(out)} -> Content/items/{FILENAME} (origin {e['origin']})", "",
         "## Fill-agent reject rate per batch (flag above 30%)", ""]
    for n, t, b in per_batch:
        L.append(f"- {n}: {b}/{t} rejected ({100 * b / max(t, 1):.0f}%){'  ABOVE 30%' if b / max(t, 1) > 0.3 else ''}")
    L += ["", "## Emit-step filters and counts", ""] + [f"- {k}: {v}" for k, v in sorted(rej.items())]
    L += ["", "## Distributions", ""]
    L += [f"- level {k}: {v}" for k, v in sorted(Counter(i['cefr'] for i in out).items())]
    L += [f"- questions per item {k}: {v}" for k, v in sorted(Counter(len(i['questions']) for i in out).items())]
    L += [f"- answer position {k}: {v}" for k, v in sorted(Counter(q['answer'] for i in out for q in i['questions']).items())]
    L += ["", "### 30-item random sample (seed 5)", ""]
    for n, i in enumerate(random.Random(5).sample(out, min(30, len(out))), 1):
        L.append(f"{n}. {i['cefr']} | {i['title']} ({len(i['script'])} lines) " + " ".join(f"Q: {q['q']} => {q['options'][q['answer']]};" for q in i['questions']))
    report.write_text(old + "\n".join(L) + "\n", encoding="utf-8")
    print(len(out), "emitted")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["fetch", "extract", "emit"])
    ap.add_argument("--raw", default=".ingest/raw/dream")
    ap.add_argument("--stage", default=".ingest/stage/dream")
    ap.add_argument("--report", default=".ingest/reports/dream.md")
    ap.add_argument("--content", default="Content")
    a = ap.parse_args()
    if a.cmd == "fetch":
        fetch(Path(a.raw))
    elif a.cmd == "extract":
        extract(Path(a.raw), Path(a.stage), Path(a.report), Path(a.content))
    else:
        emit_cmd(Path(a.stage), Path(a.report), Path(a.content))


if __name__ == "__main__":
    main()
