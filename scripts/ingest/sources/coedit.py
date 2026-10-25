"""C10 converter: grammarly/coedit -> lifeParagraph kinds `correct` (gec) and `rewrite` (simplification, coherence).

Run with -I (see scripts/ingest/README.md):
  uv run --project scripts/ingest python -I scripts/ingest/sources/coedit.py fetch
  uv run --project scripts/ingest python -I scripts/ingest/sources/coedit.py extract
  uv run --project scripts/ingest python -I scripts/ingest/sources/coedit.py emit

Notes
- Public release of CoEdIT has task values gec, paraphrase, simplification, coherence, neutralize, clarity.
  There is NO formality task in it (the card says formality/simplification rows with restrictive licenses were removed).
- `reference` is a list of strings ([String] in the Swift model).
- lifeParagraph needs minWords 40-80 and a checkable mustUse chunk (WriteCheck.uses matches it in the learner's text),
  so texts are 32+ words and mustUse is a chunk the right answer contains.
- No LLM. No code from raw/ is run; it is parsed as data.
"""
from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import random
import re
import sys
import urllib.request
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib import cefr, dedupe, emit as emit_lib, ids, schema, textnorm, workplace  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
SRC = "coedit"
HF = "https://huggingface.co/datasets/grammarly/coedit"
API = "https://huggingface.co/api/datasets/grammarly/coedit"
FILES = ["train.jsonl", "validation.jsonl"]
TARGET = {"correct": 100, "rewrite-simplification": 0, "rewrite-coherence": 60}
MIN_WORDS_TEXT, MAX_WORDS_TEXT = 32, 75

BLOCK = re.compile(r"""\b(mickey|minnie|cavegirl|tomboy|surg\w*|blood|infect\w*|bacteri\w*|medical|patient\w*|goebbels|caucasian|propaganda|fascis\w*|communis\w*|dictator\w*|sex\w*|porn\w*|rape\w*|rapist|nude|naked|erotic|fuck\w*|shit\w*|bitch\w*|slut\w*|whore\w*|
 cock|dick|penis|vagina|breast\w*|kill\w*|murder\w*|suicid\w*|massacre\w*|genocide|holocaust|nazi\w*|terroris\w*|
 bomb\w*|weapon\w*|gun|guns|shoot\w*|slave\w*|racis\w*|racial|negro|jew\w*|muslim\w*|islam\w*|christ\w*|jesus|god|
 allah|church\w*|pope|religio\w*|abortion|drug\w*|cocaine|heroin|alcohol\w*|drunk|cancer|disease\w*|death|dead|die|
 died|dying|corpse|war|wars|battle\w*|soldier\w*|army|troops|invasion|prison\w*|crime\w*|criminal\w*|arrest\w*|
 police|trump|obama|hitler|stalin|israel\w*|palestin\w*|gay|lesbian|transgender|homosexual\w*|kid|kids|child|
 children|toddler\w*|baby|babies|teen\w*|school\w*|pupil\w*|student\w*|teacher\w*|homework|fairy|princess|
 cartoon\w*|disney|pokemon|dinosaur\w*|stupid|idiot\w*|fat|ugly|hell|damn\w*|crap|sucks)\b""",
                   re.I | re.X)
TOKEN = re.compile(r"\w+(?:'\w+)?|[^\w\s]")
STOP = set("""a an the and or but if of to in on at by for with from as is are was were be been being it its this that these
those there their they them he she his her we our you your i me my not no so than then too very can could will would
should may might must do does did done have has had having which who whom whose what when where why how also into over
about after before between because while during through more most such other some any each many much both only just""".split())


# ---------- helpers ----------

def read_jsonl(path: Path):
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.strip():
            yield json.loads(line)


def split_instruction(src: str) -> str | None:
    """'Fix grammar: text' -> 'text' (instructions never contain a colon in this dataset)."""
    head, sep, body = src.partition(": ")
    if not sep or len(head) > 90:
        return None
    return body.strip()


def clean(s: str) -> str:
    s = textnorm.fix_unicode(s.replace("<SEP>", " "))
    return re.sub(r"\s+", " ", s).strip()


def surface_ok(s: str) -> str | None:
    """Return a reject reason or None. Adult, natural, plain text."""
    if not s.isascii():
        return "non-ascii"
    if re.search(r"[\[\]{}<>|*_=#@\\/~^]|\d{4,}|https?:|\bet al\b|\be\.g\.|\bi\.e\.|\bFig\b|\bTable\b", s):
        return "markup/citation/numbers"
    if re.search(r"[a-z,] \d+ [a-z]|\b(and|the|of|to|a|is|was)\.( |$)", s):
        return "garbled fragment"
    if s.count('"') % 2 or s.count("(") != s.count(")"):
        return "unbalanced quotes/brackets"
    if re.search(r"\s[,.;:!?]|\(\s|\s\)|\.\.|,,|\?\?", s):
        return "spacing/punctuation artifact"
    if not re.match(r"[A-Z]", s) or not re.search(r"[.!?]\"?$", s):
        return "does not start capital / end with punctuation"
    if BLOCK.search(s):
        return "blocklist (childish/offensive/sensitive)"
    return None


def tokens(s: str) -> list[str]:
    return TOKEN.findall(s)


def edits(a: str, b: str):
    ta, tb = tokens(a), tokens(b)
    sm = difflib.SequenceMatcher(None, ta, tb, autojunk=False)
    return ta, tb, [(op, ta[i1:i2], tb[j1:j2]) for op, i1, i2, j1, j2 in sm.get_opcodes() if op != "equal"]


def is_word(t: str) -> bool:
    return bool(re.match(r"\w", t))


LINK = set("""since because so however although though while therefore thus hence then also furthermore moreover
besides instead meanwhile consequently as which who whose where whereas but and yet still even""".split())
VARIANTS = [("our", "or"), ("ise", "ize"), ("isation", "ization"), ("ageing", "aging"), ("elled", "eled"),
            ("elling", "eling"), ("tre", "ter"), ("ence", "ense"), ("wards", "ward"), ("ogue", "og")]


def regional_variant(a: str, b: str) -> bool:
    a, b = a.lower(), b.lower()
    if {a, b} in ({"which", "that"}, {"whilst", "while"}, {"amongst", "among"}):
        return True
    return any(x in a and a.replace(x, y) == b or x in b and b.replace(x, y) == a for x, y in VARIANTS)


def recall(src: str, tgt: str) -> float:
    cw = {w.lower() for w in re.findall(r"[A-Za-z]{5,}", src)} - STOP
    tw = {w.lower() for w in re.findall(r"[A-Za-z]{5,}", tgt)}
    return len(cw & tw) / max(1, len(cw))


def novel_words(src: str, tgt: str) -> list[str]:
    have = {w.lower() for w in re.findall(r"[A-Za-z0-9']+", src)}
    return [w for w in re.findall(r"[A-Za-z0-9']+", tgt) if w.lower() not in have]


def edit_ok(op: str, old: list[str], new: list[str]) -> bool:
    """A grammar-type edit: small, and not a content-word swap that changes meaning."""
    if len(old) > 3 or len(new) > 3:
        return False
    ow, nw = [t for t in old if is_word(t)], [t for t in new if is_word(t)]
    if not ow and not nw:
        return True  # punctuation only
    if op == "replace" and ow and nw:
        a, b = " ".join(ow).lower(), " ".join(nw).lower()
        if a == b:
            return True  # case/punctuation change
        if all(w.lower() in STOP for w in ow + nw):
            return True  # function word swap
        if regional_variant(a, b):
            return False  # UK/US or style variation, not a mistake
        return difflib.SequenceMatcher(None, a, b).ratio() >= 0.6  # inflection / spelling
    # pure insert/delete: function words only (articles, prepositions, auxiliaries)
    return all(w.lower() in STOP for w in ow + nw)


def mustuse_correct(new_blocks: list[list[str]]) -> str | None:
    """A 1-3 word chunk from the corrected text that the learner has to produce."""
    for blk in new_blocks:
        w = [t for t in blk if is_word(t)]
        if 1 <= len(w) <= 3 and any(len(t) >= 4 and t.lower() not in STOP for t in w):
            return " ".join(w).lower()
    return None


def mustuse_rewrite(src: str, tgt: str) -> str | None:
    """A content word that appears in both texts (so any good rewrite keeps it)."""
    sw = {w.lower() for w in re.findall(r"[A-Za-z]{5,}", src)} - STOP
    cands = [w for w in re.findall(r"[A-Za-z]{5,}", tgt) if w.lower() in sw]
    return max(cands, key=len).lower() if cands else None


def content_hash(s: str) -> str:
    return hashlib.sha1(s.encode()).hexdigest()[:10]


# ---------- fetch ----------

def cmd_fetch(a):
    raw = Path(a.raw)
    raw.mkdir(parents=True, exist_ok=True)
    meta = json.loads(urllib.request.urlopen(API, timeout=60).read())
    lic = (meta.get("cardData") or {}).get("license")
    tags = [t for t in meta.get("tags", []) if t.startswith("license:")]
    print("HF license:", lic, tags, "sha:", meta.get("sha"))
    if lic != "apache-2.0":
        sys.exit("License is not apache-2.0 at the source; stop and re-check.")
    (raw / "hf-meta.json").write_text(json.dumps({"license": lic, "tags": tags, "sha": meta.get("sha")}, indent=1))
    for f in FILES + ["README.md"]:
        dest = raw / f
        if dest.exists():
            continue
        path = f if f == "README.md" else f
        urllib.request.urlretrieve(f"{HF}/resolve/main/{path}", dest)
        print("downloaded", dest, dest.stat().st_size)


# ---------- extract ----------

def cmd_extract(a):
    raw, stage = Path(a.raw), Path(a.stage)
    stage.mkdir(parents=True, exist_ok=True)
    rej = Counter()
    gec_pairs, rewrite, correct = [], [], []
    seen_src: set[str] = set()
    for fname, split in (("train.jsonl", "train"), ("validation.jsonl", "validation")):
        for r in read_jsonl(raw / fname):
            task = r["task"]
            if task not in ("gec", "coherence"):  # simplification rows are too noisy (dropped information, garbled names)
                continue
            body = split_instruction(r["src"])
            if body is None:
                rej[f"{task}: no instruction split"] += 1
                continue
            src, tgt = clean(body), clean(r["tgt"])
            if src == tgt:
                rej[f"{task}: src == tgt"] += 1
                continue
            key = textnorm.normalize_for_hash(src)
            if key in seen_src:
                rej[f"{task}: duplicate src"] += 1
                continue
            seen_src.add(key)
            for label, s in (("src", src), ("tgt", tgt)):
                why = surface_ok(s)
                if why:
                    rej[f"{task}: {label} {why}"] += 1
                    break
            else:
                wc_s, wc_t = textnorm.word_count(src), textnorm.word_count(tgt)
                sid = f"{split}-{r['_id']}"
                if task == "gec":
                    ta, tb, eds = edits(src, tgt)
                    n = len(eds)
                    ok = n >= 1 and all(edit_ok(*e) for e in eds)
                    if not ok:
                        rej["gec: edits not grammar-like or too big"] += 1
                        continue
                    row = {"sourceId": sid, "task": "gec", "src": src, "tgt": tgt, "nEdits": n,
                           "edits": [{"op": op, "old": " ".join(o), "new": " ".join(nw)} for op, o, nw in eds]}
                    gec_pairs.append(row)  # staged for the later grammarMC phase (any edit count)
                    if not 2 <= n <= 4:
                        rej["correct: edit count not 2-4"] += 1
                        continue
                    n_word = sum(1 for _, o, nw in eds if any(map(is_word, o + nw)))
                    if n_word < 2 or n - n_word > 1:
                        rej["correct: <2 word edits or >1 punctuation-only edit"] += 1
                        continue
                    if not MIN_WORDS_TEXT <= wc_s <= MAX_WORDS_TEXT:
                        rej["correct: length"] += 1
                        continue
                    mu = mustuse_correct([nw for _, _, nw in eds]) or mustuse_rewrite(src, tgt)
                    if not mu:
                        rej["correct: no checkable chunk"] += 1
                        continue
                    row.update(mustUse=mu, words=wc_s)
                    correct.append(row)
                else:
                    if not MIN_WORDS_TEXT <= wc_s <= MAX_WORDS_TEXT or not 0.6 <= wc_t / wc_s <= 1.3:
                        rej[f"{task}: length/ratio"] += 1
                        continue
                    if task == "simplification":
                        avg = lambda s: sum(map(len, re.findall(r"[A-Za-z]+", s))) / max(1, textnorm.word_count(s))
                        if avg(tgt) >= avg(src) - 0.1:
                            rej["simplification: not simpler (avg word length)"] += 1
                            continue
                    if len(re.findall(r"(?<=[a-z,] )[A-Z][a-z]+", src)) > 2:
                        rej[f"{task}: proper-noun heavy (trivia)"] += 1
                        continue
                    nov = novel_words(src, tgt)
                    if re.search(r"\d", " ".join(nov)) or any(w[0].isupper() for w in nov[1:]):
                        rej[f"{task}: tgt adds names/numbers"] += 1
                        continue
                    if task == "coherence":
                        if not 0.85 <= wc_t / wc_s <= 1.1 or len(nov) > 4 or any(w.lower() not in STOP | LINK for w in nov):
                            rej["coherence: not a pure linking edit"] += 1
                            continue
                    elif not 0.7 <= wc_t / wc_s <= 1.0 or len(nov) / max(1, wc_t) > 0.5 or recall(src, tgt) < 0.4:
                        rej["simplification: length/novelty"] += 1
                        continue
                    ratio = difflib.SequenceMatcher(None, src.split(), tgt.split()).ratio()
                    if ratio > 0.92 or ratio < 0.25:
                        rej[f"{task}: too similar / too different"] += 1
                        continue
                    mu = mustuse_rewrite(src, tgt)
                    if not mu:
                        rej[f"{task}: no shared content word"] += 1
                        continue
                    rewrite.append({"sourceId": sid, "task": task, "src": src, "tgt": tgt, "mustUse": mu,
                                    "words": wc_s})
    for row in correct + rewrite:
        row["workplace"] = round(workplace.score(row["src"] + " " + row["tgt"]), 3)
    write_jsonl(stage / "gec-pairs.jsonl", gec_pairs)
    write_jsonl(stage / "correct.jsonl", correct)
    write_jsonl(stage / "rewrite.jsonl", rewrite)
    (stage / "rejects.json").write_text(json.dumps(rej.most_common(), indent=1))
    print(f"gec pairs staged {len(gec_pairs)}; correct candidates {len(correct)}; "
          f"rewrite candidates {len(rewrite)} ({Counter(r['task'] for r in rewrite)})")


def write_jsonl(path: Path, rows):
    path.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows), encoding="utf-8")


# ---------- emit ----------

CORRECT_PROMPTS = [
    "This short text has a few grammar mistakes. Rewrite it with every mistake fixed.",
    "Someone sent you this draft and it has a few errors. Write the corrected version.",
    "Fix the mistakes in this text and write out the clean version.",
]
REWRITE_PROMPTS = {
    "simplification": [
        "Rewrite this in simpler, plainer English so a new colleague can follow it easily.",
        "Make this easier to read: rewrite it with simpler words and shorter sentences.",
    ],
    "coherence": [
        "Rewrite this so the ideas connect logically and it reads as one smooth text.",
        "Rewrite this with better links between the sentences so it flows naturally.",
    ],
}


def pick(options: list[str], key: str) -> str:
    return options[int(hashlib.sha1(key.encode()).hexdigest(), 16) % len(options)]


def build_item(row: dict, kind: str) -> dict:
    task = row["task"]
    wc = row["words"]
    prompt = pick(CORRECT_PROMPTS if kind == "correct" else REWRITE_PROMPTS[task], row["src"])
    text = row["src"]
    ref = row["tgt"]
    item = {
        "id": ids.hashed_id("lifeParagraph", SRC, f"{kind}|{text}"),
        "type": "lifeParagraph",
        "cefr": cefr.estimate(ref),
        "skill": "writing",
        "prompt": prompt,
        "text": text,
        "mustUse": [row["mustUse"]],
        "minWords": max(40, min(80, round(0.8 * wc))),
        "reference": [ref],
        "kind": kind,
        "source": SRC,
        "sourceId": row["sourceId"],
        "license": "Apache-2.0",
        "tier": "permissive",
        "origin": "verbatim",
        "group": f"coedit:{content_hash(textnorm.normalize_for_hash(text))}",
    }
    if row["workplace"] >= 0.15:
        item["topics"] = ["workplace"]
    return item


def existing_index() -> dedupe.DedupeIndex:
    """Index of Content/ without this converter's own output (so reruns are idempotent)."""
    idx = dedupe.DedupeIndex()
    for sub in ("items", "vocab"):
        for f in sorted((ROOT / "Content" / sub).glob("*.json")):
            if f.name.endswith("-coedit.json"):
                continue
            for row in json.loads(f.read_text(encoding="utf-8")):
                idx.add(row["id"], dedupe.item_text(row))
    return idx


def select(rows: list[dict], n: int) -> list[dict]:
    # workplace relevance first, then a stable pseudo-random order
    return sorted(rows, key=lambda r: (-r["workplace"], hashlib.sha1(r["src"].encode()).hexdigest()))[:n]


def cmd_emit(a):
    stage = Path(a.stage)
    rep = Counter()
    idx = existing_index()
    pools = {"correct": [], "rewrite-simplification": [], "rewrite-coherence": []}
    for r in read_jsonl(stage / "correct.jsonl"):
        pools["correct"].append(r)
    for r in read_jsonl(stage / "rewrite.jsonl"):
        pools[f"rewrite-{r['task']}"].append(r)
    out = {"correct": [], "rewrite": []}
    for name, rows in pools.items():
        kind = "correct" if name == "correct" else "rewrite"
        chosen = 0
        for r in select(rows, len(rows)):
            if chosen >= TARGET[name]:
                break
            it = build_item(r, kind)
            if cefr.estimate(r["tgt"]) not in ("B1", "B1+", "B2", "B2+", "C1"):
                rep[f"{name}: cefr out of range"] += 1
                continue
            if schema.problems_item(it):
                rep[f"{name}: schema: {schema.problems_item(it)[0][:50]}"] += 1
                continue
            why = idx.check_and_add(it["id"], r["src"])
            if why:
                rep[f"{name}: dedupe"] += 1
                continue
            out[kind].append(it)
            chosen += 1
    for kind, fname in (("correct", "life-correct-coedit.json"), ("rewrite", "life-rewrite-coedit.json")):
        entry = emit_lib.emit(
            ROOT / "Content", "items", fname, out[kind], source=f"CoEdIT ({kind})", url=HF,
            license="Apache-2.0 (HF tag and card; the public release keeps only rows from publicly available "
                    "datasets, but upstream corpora behind the gec/simplification/coherence tasks may carry "
                    "their own terms)",
            tier="permissive",
            attribution="Raheja et al. 2023, CoEdIT: Text Editing by Task-Specific Instruction Tuning, grammarly/coedit")
        print(fname, entry["items"])
    (stage / "emit-rejects.json").write_text(json.dumps(rep.most_common(), indent=1))
    write_report(stage, out, rep)


def write_report(stage: Path, out: dict, emit_rej: Counter):
    rej = json.loads((stage / "rejects.json").read_text())
    lines = ["# coedit report", "", f"Source: {HF} (license apache-2.0 per HF API cardData and tags, README front matter; "
             "checked at fetch time).", "",
             "Public release has no formality task (card: licensed simplification/formality rows were removed). "
             "Rewrite kinds therefore use simplification and coherence only.", "",
             f"Emitted: correct {len(out['correct'])}, rewrite {len(out['rewrite'])} "
             f"({Counter(i['prompt'] in REWRITE_PROMPTS['simplification'] for i in out['rewrite'])}).", "",
             "## Extract rejects", ""] + [f"- {k}: {v}" for k, v in rej] + ["", "## Emit rejects", ""] + \
            [f"- {k}: {v}" for k, v in emit_rej.most_common()]
    all_items = out["correct"] + out["rewrite"]
    rnd = random.Random(7)
    lines += ["", "## Random sample of 30 emitted items", ""]
    for it in rnd.sample(all_items, min(30, len(all_items))):
        lines += [f"### {it['id']} ({it['kind']}, {it['cefr']}, mustUse {it['mustUse']}, minWords {it['minWords']})",
                  f"- prompt: {it['prompt']}", f"- text: {it['text']}", f"- reference: {' / '.join(it['reference'])}", ""]
    rep = Path(a_reports()) / "coedit.md"
    rep.parent.mkdir(parents=True, exist_ok=True)
    rep.write_text("\n".join(lines), encoding="utf-8")


def a_reports() -> str:
    return str(ROOT / ".ingest" / "reports")


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    for name, fn in (("fetch", cmd_fetch), ("extract", cmd_extract), ("emit", cmd_emit)):
        s = sub.add_parser(name)
        s.add_argument("--raw", default=str(ROOT / ".ingest/raw/coedit"))
        s.add_argument("--stage", default=str(ROOT / ".ingest/stage/coedit"))
        s.set_defaults(fn=fn)
    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
