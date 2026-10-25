"""C05: OpenStax paragraphs (HuggingFaceTB/openstax_paragraphs, CC BY 4.0) -> completeWords.

Commands (run with -I from the tenaz root):
  fetch   --raw .ingest/raw/openstax
  extract --raw .ingest/raw/openstax --stage .ingest/stage/openstax --report .ingest/reports/openstax.md
  emit    --stage .ingest/stage/openstax --content Content --report .ingest/reports/openstax.md

Stage rows (paragraphs.jsonl) are clean 80-180 word paragraphs, kept for later summary/listenTalk/readAcademic
use. Only the hash-partitioned 30% "cw" share is turned into completeWords items (plan 3.8: a text never
appears in two types).
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

from lib import cefr, dedupe, emit as emitlib, gaps, ids, schema, textnorm, workplace  # noqa: E402

DATASET = "HuggingFaceTB/openstax_paragraphs"
BASE = f"https://huggingface.co/datasets/{DATASET}/resolve/main/"
SOURCE = "openstax"
URL = "https://huggingface.co/datasets/HuggingFaceTB/openstax_paragraphs"
FILENAME = "complete-words-openstax.json"
TARGET = 700
PER_BOOK_CAP = 110

# book -> (topic, boost). Business/economics/psychology/biology/statistics preferred (task spec).
BOOKS = {
    "Principles of Management": ("business", 0.30),
    "Organizational Behavior": ("business", 0.30),
    "Introduction to Business": ("business", 0.30),
    "Entrepreneurship": ("business", 0.25),
    "Principles of Marketing": ("business", 0.20),
    "Principles of Finance": ("business", 0.10),
    "Business Ethics": ("business", 0.15),
    "Principles of Accounting, Volume 2: Managerial Accounting": ("business", 0.15),
    "Principles of Economics 3e": ("economics", 0.20),
    "Principles of Macroeconomics 3e": ("economics", 0.20),
    "Principles of Microeconomics 3e": ("economics", 0.20),
    "Psychology 2e": ("psychology", 0.20),
    "Introduction to Sociology 3e": ("sociology", 0.10),
    "Biology 2e": ("biology", 0.05),
    "Concepts of Biology": ("biology", 0.05),
    "Introductory Business Statistics 2e": ("statistics", 0.15),
    "Introductory Statistics 2e": ("statistics", 0.10),
}

BAD_PARA = re.compile(
    r"(\b(Figure|Fig\.|Table|Equation|Exercise|Exercises|Chapter|Section|Example|Problem|Review Questions?|"
    r"Check Your Understanding|Link to Learning|Learning Objectives?|Key Terms?|Summary)\b\s*\d*)"
    r"|\b(e\.g|i\.e|U\.S|vs|etc|Inc|Corp|Ltd|Co|Mr|Mrs|Ms|Dr|St|No|approx|cf|al)\.\s"
    r"|[=<>±×÷∑√σμπ^_*\[\]{}|#@\\/]|\bhttps?:|www\.|\.com\b|\.org\b"
    r"|\([A-Z][A-Za-z .&]*(, [A-Z]{2})?: |\bpp?\. ?\d|\bibid\b|\(\d{4}\)|\b(19|20)\d\d\)",
)
# sensitive / unsuitable for a daily-study adult feed (conservative)
SENSITIVE = re.compile(
    r"\b(sex|sexual\w*|rape\w*|suicid\w*|genital\w*|porn\w*|erotic\w*|abus\w+|assault\w*|molest\w*|kill\w*|murder\w*|"
    r"cocaine|heroin|opioid\w*|alcoholi\w+|addict\w*|racis\w+|slave\w*|genocide|terroris\w+|abortion\w*|"
    r"psychopath\w*|self-harm|weapon\w*|gun|guns|pregnan\w*|contracepti\w*|orgasm\w*|penis|vagina\w*|nude|naked|"
    r"fetus\w*|cadaver\w*|torture\w*|hitler|nazi\w*|holocaust|semen|sperm\w*|ovum|ova|zygote\w*|embryo\w*)\b", re.I)
# paragraphs that are course scaffolding rather than expository prose
SCAFFOLD = re.compile(
    r"\b(this (chapter|section|text|textbook|book)|chapters?|you('ve| have) (learned|seen)|we (will|have) (learned|seen|discussed)|as we (saw|discussed)|in this (chapter|section)|students?|instructors?|learners?|"
    r"OpenStax|you will (learn|be able)|click|download|quiz)\b", re.I)
START_BAD = re.compile(r"^(However|This|These|That|Those|Thus|Therefore|Also|It|They|He|She|Such|Another|Both|But|And|"
                       r"Second|Third|Finally|Next|Then|For example|For instance|In addition|In contrast|As a result)\b")
CAP_MID = re.compile(r"[a-z,;:] ([A-Z][a-z]+)")


def _slug(s: str) -> str:
    return ids.slug(s)


def cmd_fetch(a):
    raw = Path(a.raw)
    raw.mkdir(parents=True, exist_ok=True)
    if any(raw.iterdir()):
        sys.exit(f"{raw} is not empty; delete it to refetch")
    for name in ("README.md", "openstax_books.jsonl"):
        with urllib.request.urlopen(BASE + name) as r:
            (raw / name).write_bytes(r.read())
    print("fetched", [p.name for p in raw.iterdir()])


def _walk(node, path):
    """Yield (path, section_title, text) for every section with a paragraph, at any nesting depth."""
    if isinstance(node, dict):
        if "paragraph" in node and isinstance(node["paragraph"], str) and node["paragraph"].strip():
            yield path, node.get("title", ""), node["paragraph"]
        t = node.get("title", "")
        for k in ("chapters", "sections"):
            for ch in node.get(k) or []:
                yield from _walk(ch, path + [t] if k == "chapters" else path)


def clean_para(p: str) -> str:
    p = textnorm.fix_unicode(p)
    p = p.replace("\\$", "$")
    p = re.sub(r"\*([^*\n]{1,60})\*", r"\1", p)  # markdown emphasis
    p = p.replace("U.S.", "US")
    p = re.sub(r"\s+", " ", p).strip()
    return p


def extract_paragraphs(raw: Path):
    """Yield dict rows for every candidate paragraph (before filtering) plus reject reasons."""
    with open(raw / "openstax_books.jsonl", encoding="utf-8") as f:
        for line in f:
            book = json.loads(line)
            title = book["book_title"]
            if book.get("language") != "en":
                continue
            if title not in BOOKS:
                continue
            for path, sec, text in _walk({"chapters": book["chapters"], "title": title}, []):
                for pi, para in enumerate(re.split(r"\n\s*\n", text)):
                    yield {"book": title, "chapter": " > ".join(path[1:]) if path else "", "section": sec,
                           "pi": pi, "raw": para}


def cmd_extract(a):
    raw, stage = Path(a.raw), Path(a.stage)
    stage.mkdir(parents=True, exist_ok=True)
    rej = Counter()
    kept, seen = [], set()
    n_total = 0
    for r in extract_paragraphs(raw):
        n_total += 1
        p = clean_para(r["raw"])
        wc = textnorm.word_count(p)
        if wc < 80:
            rej["too short (<80 words)"] += 1
            continue
        if wc > 180:
            rej["too long (>180 words)"] += 1
            continue
        if BAD_PARA.search(p):
            rej["formula / figure-table ref / citation / abbreviation / symbols"] += 1
            continue
        if sum(c.isdigit() for c in p) > 12 or len(re.findall(r"\d", p)) / max(1, len(p)) > 0.02:
            rej["number-heavy"] += 1
            continue
        if SENSITIVE.search(p):
            rej["sensitive/unsuitable keyword"] += 1
            continue
        if SCAFFOLD.search(p):
            rej["course scaffolding wording"] += 1
            continue
        if re.search(r"\b[A-Za-z]\b(?<!\bI)(?<!\bA)(?<!\ba)", p.replace("'", "")):
            rej["stray single letters (variables)"] += 1
            continue
        if "?" in p or "$" in p:
            rej["question / dollar-amount (exercise-like)"] += 1
            continue
        if not re.search(r"[.?!]$", p):
            rej["no terminal punctuation"] += 1
            continue
        if re.search(r"[^\x20-\x7E]", p):
            rej["non-ascii after normalisation"] += 1
            continue
        sents = textnorm.split_sentences(p)
        if len(sents) < 4:
            rej["<4 sentences"] += 1
            continue
        if any(len(s.split()) > 45 for s in sents):
            rej["sentence >45 words"] += 1
            continue
        h = textnorm.text_hash(p)
        if h in seen:
            rej["duplicate paragraph"] += 1
            continue
        seen.add(h)
        topic, boost = BOOKS[r["book"]]
        key = f'{r["book"]}|{r["chapter"]}|{r["section"]}|{r["pi"]}'
        sid = hashlib.sha256(key.encode()).hexdigest()[:10]
        share = "cw" if int(hashlib.sha256(("share|" + key).encode()).hexdigest(), 16) % 10 < 3 else "other"
        kept.append({"sourceId": sid, "book": r["book"], "chapter": r["chapter"], "section": r["section"],
                     "paraIndex": r["pi"], "topic": topic, "words": wc, "text": p, "share": share,
                     "workplace": round(workplace.score(p), 3), "boost": boost,
                     "cefr": cefr.estimate(p)})
    with open(stage / "paragraphs.jsonl", "w", encoding="utf-8") as f:
        for k in kept:
            f.write(json.dumps(k, ensure_ascii=False) + "\n")
    rep = ["# OpenStax (C05) extract report", "",
           f"Source: {URL} (license cc-by-4.0 per HF API tag and README front matter; retrieved from the repo file "
           "openstax_books.jsonl).", "",
           f"Candidate paragraphs in whitelisted English books: {n_total}", "", "## Rejects (extract)", ""]
    rep += [f"- {k}: {v}" for k, v in rej.most_common()]
    rep += ["", f"Kept (staged, 80-180 words): {len(kept)}", "",
            "By share: " + str(dict(Counter(k["share"] for k in kept))),
            "By book: " + str(dict(Counter(k["book"] for k in kept))),
            "By CEFR estimate: " + str(dict(Counter(k["cefr"] for k in kept))), ""]
    Path(a.report).parent.mkdir(parents=True, exist_ok=True)
    Path(a.report).write_text("\n".join(rep) + "\n", encoding="utf-8")
    print("\n".join(rep))


def _gap_caps(passage: str) -> int:
    """Gapped words that are capitalised mid-sentence (proper nouns are hard to guess)."""
    n = 0
    for m in re.finditer(r"([A-Za-z]+)\{\{", passage):
        w = m.group(1)
        pre = passage[:m.start()].rstrip()
        if w[0].isupper() and pre and pre[-1] not in ".?!":
            n += 1
        elif sum(ch.isupper() for ch in w) >= 2:
            n += 3  # acronyms (WANs, GDPs): reject
    return n


def best_window(text: str):
    """First valid gapped window whose opening sentence stands alone; None if there is none."""
    sents = textnorm.split_sentences(text)
    cands = []
    for i in range(len(sents)):
        n, cur = 0, []
        for s in sents[i:]:
            w = len(s.split())
            if n + w > gaps.MAX_WORDS:
                break
            cur.append(s)
            n += w
            if n >= gaps.MIN_WORDS:
                break
        if n < gaps.MIN_WORDS or n > gaps.MAX_WORDS or len(cur) < 4:
            continue
        if START_BAD.match(cur[0]):
            continue
        p = gaps.make_gaps(cur)
        if p and _gap_caps(p) <= 2:
            cands.append((i, " ".join(cur), p))
    return cands[0] if cands else None


def cmd_emit(a):
    stage, content = Path(a.stage), Path(a.content)
    rows = [json.loads(l) for l in open(stage / "paragraphs.jsonl", encoding="utf-8")]
    rej = Counter()
    # the index is built from all of Content/, including this converter's previous output: drop it first so a
    # rerun does not dedupe against itself (emit rewrites the file wholesale anyway)
    (content / "items" / FILENAME).unlink(missing_ok=True)
    idx = dedupe.DedupeIndex.from_content(content)
    pool = []
    for r in rows:
        if r["share"] != "cw":
            rej["not in the 30% completeWords share (kept for other types)"] += 1
            continue
        w = best_window(r["text"])
        if not w:
            rej["no valid 70-110 word window (gaps / proper nouns / opener)"] += 1
            continue
        i, plain, passage = w
        lvl = r["cefr"]
        score = r["boost"] + 0.6 * r["workplace"] + {"B1": 0.1, "B1+": 0.2, "B2": 0.25, "B2+": 0.2, "C1": 0.05}[lvl]
        pool.append((score, r, i, plain, passage))
    pool.sort(key=lambda t: (-t[0], t[1]["sourceId"]))
    out, per_book = [], Counter()
    group_seen, first_seen = set(), set()
    for score, r, i, plain, passage in pool:
        if len(out) >= TARGET:
            break
        if per_book[r["book"]] >= PER_BOOK_CAP:
            rej["per-book cap"] += 1
            continue
        group = "openstax:" + hashlib.sha256(f'{r["book"]}|{r["chapter"]}|{r["section"]}'.encode()).hexdigest()[:10]
        if group in group_seen:
            rej["one window per section (group)"] += 1
            continue
        item = {"id": ids.item_id("completeWords", SOURCE, f'{r["sourceId"]}-{i}'), "type": "completeWords",
                "cefr": r["cefr"], "skill": "reading", "passage": passage, "source": SOURCE,
                "sourceId": r["sourceId"], "license": "CC BY 4.0", "tier": "permissive", "group": group,
                "origin": "verbatim", "topics": [r["topic"]] + (["workplace"] if r["workplace"] >= 0.15 else [])}
        probs = schema.problems_item(item)
        if probs:
            rej["schema: " + probs[0][:60]] += 1
            continue
        fs = textnorm.text_hash(plain.split(". ")[0])
        if fs in first_seen:
            rej["near duplicate across books (same opening sentence)"] += 1
            continue
        why = idx.check_and_add(item["id"], dedupe.item_text(item))
        if why:
            rej["dedupe: " + ("exact duplicate" if why.startswith("exact") else "near duplicate") + " of existing Content/"] += 1
            continue
        group_seen.add(group)
        first_seen.add(fs)
        per_book[r["book"]] += 1
        out.append(item)
    out.sort(key=lambda x: x["id"])
    entry = emitlib.emit(content, "items", FILENAME, out, source="OpenStax paragraphs (HuggingFaceTB/openstax_paragraphs)",
                         url=URL, license="CC BY 4.0", tier="permissive",
                         attribution="OpenStax, Rice University (CC BY 4.0); via HuggingFaceTB/openstax_paragraphs. "
                                     "Passages are verbatim excerpts with letters hidden.")
    # report
    rp = Path(a.report)
    rep = rp.read_text(encoding="utf-8") if rp.exists() else ""
    rep = rep.split("\n## Emit")[0]
    sec = ["", "## Emit", "", f"Staged paragraphs: {len(rows)}; completeWords share: {sum(r['share']=='cw' for r in rows)}",
           f"Pool with valid windows: {len(pool)}; emitted: {len(out)}", "", "### Rejects (emit)", ""]
    sec += [f"- {k}: {v}" for k, v in rej.most_common()]
    sec += ["", "By book: " + str(dict(per_book)),
            "By CEFR: " + str(dict(Counter(o["cefr"] for o in out))),
            "By topic: " + str(dict(Counter(o["topics"][0] for o in out))),
            f"With workplace tag: {sum('workplace' in o['topics'] for o in out)}", "",
            f"licenses.json entry: {json.dumps(entry)}", "", "## 30 random emitted items (skimmed)", ""]
    rnd = random.Random(7)
    for o in rnd.sample(out, min(30, len(out))):
        sec.append(f"- `{o['id']}` [{o['cefr']}, {o['topics']}] {o['passage']}")
    Path(a.report).write_text(rep.rstrip() + "\n" + "\n".join(sec) + "\n", encoding="utf-8")
    print(f"emitted {len(out)}; per book {dict(per_book)}")


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    f = sub.add_parser("fetch"); f.add_argument("--raw", required=True); f.set_defaults(fn=cmd_fetch)
    e = sub.add_parser("extract")
    e.add_argument("--raw", required=True); e.add_argument("--stage", required=True); e.add_argument("--report", required=True)
    e.set_defaults(fn=cmd_extract)
    m = sub.add_parser("emit")
    m.add_argument("--stage", required=True); m.add_argument("--content", required=True); m.add_argument("--report", required=True)
    m.set_defaults(fn=cmd_emit)
    a = ap.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
