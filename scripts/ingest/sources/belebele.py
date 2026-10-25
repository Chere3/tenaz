"""C02 belebele: HF facebook/belebele eng_Latn (CC BY-SA 4.0) -> completeWords items (+ staged QA for readDaily).

  fetch   -> .ingest/raw/belebele/rows_<offset>.json   (datasets-server rows API, 100 per page)
  extract -> .ingest/stage/belebele/passages.jsonl     (one row per distinct passage, with its questions + share)
             .ingest/reports/belebele.md
  emit    -> Content/items/complete-words-belebele.json

Partition (plan 3.4): sha256(passage) % 10 < 3 -> completeWords share (30%), else readDaily/readAcademic share (70%).
Run: uv run --project scripts/ingest python -I scripts/ingest/sources/belebele.py extract
"""
from __future__ import annotations

import argparse
import hashlib
import json
import random
import re
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib import cefr, dedupe, emit as emit_lib, gaps, ids, schema, textnorm, workplace  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
URL = "https://huggingface.co/datasets/facebook/belebele"
API = ("https://datasets-server.huggingface.co/rows?dataset=facebook/belebele&config=eng_Latn&split=test"
       "&offset={o}&length=100")
LICENSE = "CC BY-SA 4.0"
# violence / sex / drugs vocabulary is filtered out of a daily-practice bank
BLOCK = re.compile(r"\b(kill\w*|murder\w*|rape\w*|sex\w*|suicid\w*|bomb\w*|massacre\w*|terror\w*|genocide|nude|naked|porn\w*|"
                   r"corpse\w*|dead|deaths?|died|dies|attack\w*|shoot\w*|shot|weapons?|gunmen|hostages?|prostitut\w*|"
                   r"alcohol\w*|drunk\w*|gambl\w*|casinos?|drugs?|cocaine|heroin|abuse\w*|slave\w*|torture\w*|war|wars|riot\w*|casualt\w*|injur\w*|wounded|"
                   r"explosi\w*|militants?|insurgen\w*|stabb\w*|victims?|hell|damn)\b", re.I)


def fetch(raw: Path) -> None:
    raw.mkdir(parents=True, exist_ok=True)
    for o in range(0, 900, 100):
        with urllib.request.urlopen(API.format(o=o), timeout=60) as r:
            (raw / f"rows_{o}.json").write_bytes(r.read())


def load_passages(raw: Path) -> dict[str, dict]:
    P: dict[str, dict] = {}
    for f in sorted(raw.glob("rows_*.json")):
        for r in json.loads(f.read_text(encoding="utf-8"))["rows"]:
            r = r["row"]
            p = P.setdefault(r["flores_passage"], {"link": r["link"], "questions": []})
            opts = [r[f"mc_answer{i}"] for i in range(1, 5)]
            p["questions"].append({"q": r["question"], "options": opts, "answer": int(r["correct_answer_num"]) - 1,
                                   "n": r["question_number"]})
    return P


def share_of(passage: str) -> str:
    return "completeWords" if int(hashlib.sha256(passage.encode()).hexdigest(), 16) % 10 < 3 else "reading"


def midcaps(passage: str) -> int:
    n = 0
    for s in textnorm.split_sentences(passage):
        n += sum(1 for t in s.split()[1:] if t[:1].isupper())
    return n


def extract(raw: Path, stage: Path, report: Path) -> None:
    P = load_passages(raw)
    stage.mkdir(parents=True, exist_ok=True)
    report.parent.mkdir(parents=True, exist_ok=True)
    rej: dict[str, int] = {}
    rows = []
    for passage, d in sorted(P.items(), key=lambda kv: kv[0]):
        text = textnorm.fix_unicode(passage).strip()
        text = re.sub(r"\s+", " ", text)
        # CSV-escaped quotes in the source: "" -> ", """ -> "; then drop one stray outer quote
        text = re.sub(r'"{2,}', '"', text)
        if text.count('"') % 2:
            text = text.strip('"') if text.startswith('"') or text.endswith('"') else text
        key = hashlib.sha256(passage.encode()).hexdigest()[:8]
        row = {"sourceId": d["link"], "key": key, "text": text, "share": share_of(passage),
               "words": textnorm.word_count(text), "questions": sorted(d["questions"], key=lambda q: q["n"])}
        rows.append(row)
    with (stage / "passages.jsonl").open("w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    cw = [r for r in rows if r["share"] == "completeWords"]
    lines = [f"# belebele extract\n", f"- distinct passages: {len(rows)}; questions: {sum(len(r['questions']) for r in rows)}",
             f"- completeWords share (hash%10<3): {len(cw)}; reading share: {len(rows) - len(cw)}", "- staged: .ingest/stage/belebele/passages.jsonl"]
    report.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))


def candidates(stage: Path):
    rej: dict[str, int] = {}
    out = []
    # emit rewrites its own file, so keep it out of the dedupe index (idempotent reruns)
    (ROOT / "Content/items/complete-words-belebele.json").unlink(missing_ok=True)
    idx = dedupe.DedupeIndex.from_content(ROOT / "Content")
    rows = [json.loads(l) for l in (stage / "passages.jsonl").read_text(encoding="utf-8").splitlines()]
    rej["total passages"] = len(rows)

    def no(reason):
        rej[reason] = rej.get(reason, 0) + 1

    for r in rows:
        if r["share"] != "completeWords":
            no("reading share (70%)"); continue
        link = r["sourceId"]
        if "wikijunior" in link.lower():
            no("wikijunior (childish)"); continue
        text = r["text"]
        if r["words"] < 70:
            no("<70 words"); continue
        if text.count('"') % 2:
            no("unbalanced quotes"); continue
        if re.match(r"(For (example|instance)|However|Thus|Therefore|Also|But|And|So|This|These|Those|That|Such|Another|In addition|Moreover|Then|It|They|He|She|Both|Yet|Still|Instead|Meanwhile)\b", text):
            no("starts with a dangling connector/pronoun"); continue
        if BLOCK.search(text):
            no("violence/sex/drugs vocabulary"); continue
        if re.search(r"\d", text) and len(re.findall(r"\d+", text)) > 6:
            no(">6 numbers"); continue
        sents = textnorm.split_sentences(text)
        passages = None
        for i in range(len(sents)):  # first valid window, preferring the start of the passage
            ws = list(gaps.windows(" ".join(sents[i:])))
            if ws and ws[0] and sents[i:][0] == ws[0][0]:
                passages = gaps.make_gaps(ws[0]); win = ws[0]
                if passages:
                    break
        if not passages:
            no("no valid 10-gap window (<70 or >110 words, or too few eligible words)"); continue
        win_text = " ".join(win)
        if midcaps(win_text) > 8 or len(re.findall(r"\b[A-Z][a-z]*\{\{", passages)) > 1:
            no("proper-noun heavy (>8 mid-sentence capitals or >1 capitalized gap)"); continue
        stats = gaps.passage_stats(passages)
        if schema.problems_item({"id": "x", "type": "completeWords", "cefr": "B2", "passage": passages}):
            no("schema problems"); continue
        iid = ids.item_id("completeWords", "belebele", r["key"])
        dup = idx.check(win_text)
        if dup:
            no("dedupe vs Content: " + dup.split(":")[0]); continue
        idx.add(iid, win_text)
        wp = workplace.score(win_text)
        lvl = cefr.estimate(win_text)
        out.append({"r": r, "id": iid, "passage": passages, "text": win_text, "cefr": lvl, "wp": wp})
    return out, rej


def emit_cmd(stage: Path, report: Path) -> None:
    out, rej = candidates(stage)
    items = []
    for c in out:
        r = c["r"]
        it = {"id": c["id"], "type": "completeWords", "cefr": c["cefr"], "skill": "reading", "passage": c["passage"],
              "source": "belebele", "sourceId": r["sourceId"], "license": LICENSE, "tier": "share-alike",
              "group": f"belebele:{r['key']}", "origin": "verbatim"}
        if c["wp"] >= 0.04:
            it["topics"] = ["workplace"]
        items.append(it)
    items.sort(key=lambda x: x["id"])
    emit_lib.emit(ROOT / "Content", "items", "complete-words-belebele.json", items, source="belebele", url=URL,
                  license=LICENSE, tier="share-alike",
                  attribution="Belebele (Meta AI, facebook/belebele eng_Latn); passages from FLORES-200 (Wikinews, Wikivoyage), CC BY-SA 4.0")
    rnd = random.Random(7)
    sample = rnd.sample(items, min(30, len(items)))
    dist: dict[str, int] = {}
    for i in items:
        dist[i["cefr"]] = dist.get(i["cefr"], 0) + 1
    lines = [f"\n## emit: {len(items)} completeWords items -> Content/items/complete-words-belebele.json\n",
             "CEFR (weak lexical estimate): " + ", ".join(f"{k}={v}" for k, v in sorted(dist.items())),
             f"workplace-tagged: {sum(1 for i in items if 'topics' in i)}", "\n### Reject reasons\n"]
    lines += [f"- {k}: {v}" for k, v in rej.items()]
    lines += ["\n### 30 random emitted items\n"]
    for i in sample:
        lines.append(f"- `{i['id']}` [{i['cefr']}] {i['passage']}")
    with report.open("a", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines[:6]))


# ---------------------------------------------------------------- reading share: batches for the LLM fill step
BAD_Q = re.compile(r"\b(NOT|EXCEPT)\b|all of the above|none of the|both [A-D] and", re.I)
NEG_STEM = re.compile(r"\b(not|never)\b|n't", re.I)  # negated stems read as double negatives
DANGLING = re.compile(r"(For (example|instance)|However|Thus|Therefore|Also|But|And|So|This|These|Those|That|Such|Another|"
                      r"In addition|Moreover|Then|It|They|He|She|Both|Yet|Still|Instead|Meanwhile|There|Their|His|Her|Its|"
                      r"Although|Despite|Because|Since|While|After|Before|When|If)\b")


def clean_passage_text(passage: str) -> str:
    text = re.sub(r"\s+", " ", textnorm.fix_unicode(passage)).strip()
    return re.sub(r'"{2,}', '"', text)


def batches_cmd(stage: Path, report: Path) -> None:
    """readDaily from the reading share (70%). readAcademic: see report (no link has >1 passage, so no joins exist)."""
    idx = dedupe.DedupeIndex.from_content(ROOT / "Content")
    rows = [json.loads(l) for l in (stage / "passages.jsonl").read_text(encoding="utf-8").splitlines()]
    rej: dict[str, int] = {}

    def no(reason):
        rej[reason] = rej.get(reason, 0) + 1

    out, acad = [], []
    for r in rows:
        if r["share"] != "reading":
            no("completeWords share (30%)"); continue
        link = r["sourceId"]
        if "wikijunior" in link.lower():
            no("wikijunior (childish)"); continue
        text = clean_passage_text(r["text"])
        wc = textnorm.word_count(text)
        if text.count('"') % 2:
            no("unbalanced quotes"); continue
        if DANGLING.match(text) or not text[:1].isupper():
            no("starts mid-thought (connector/pronoun/lowercase)"); continue
        if not re.search(r'[.!?]["\u201d]?$', text):
            no("does not end on a sentence"); continue
        if BLOCK.search(text):
            no("violence/sex/drugs vocabulary in text"); continue
        if len(re.findall(r"\d+", text)) > 8:
            no(">8 numbers"); continue
        qs = []
        for q in r["questions"]:
            qt = textnorm.fix_unicode(q["q"]).strip()
            opts = [textnorm.fix_unicode(o).strip() for o in q["options"]]
            if NEG_STEM.search(qt):
                no("question dropped: negated stem"); continue
            if BAD_Q.search(qt) or any(BAD_Q.search(o) for o in opts):
                no("question dropped: NOT/EXCEPT/all-of-the-above"); continue
            if len(set(o.lower() for o in opts)) < 4 or any(not o for o in opts):
                no("question dropped: duplicate/empty options"); continue
            if BLOCK.search(qt) or any(BLOCK.search(o) for o in opts):
                no("question dropped: violence/sex/drugs vocabulary"); continue
            if not 0 <= q["answer"] <= 3:
                no("question dropped: bad key"); continue
            qs.append({"q": qt, "options": opts, "answer": q["answer"]})
        qs = qs[:3]
        if 150 <= wc <= 220 and qs:
            acad.append({"key": r["key"], "words": wc, "questions": len(qs)})
        if not 40 <= wc <= 150:
            no("readDaily needs 40-150 words (%s)" % ("<40" if wc < 40 else ">150")); continue
        if len(qs) < 2:
            no("fewer than 2 usable questions"); continue
        iid = ids.item_id("readDaily", "belebele", r["key"])
        dup = idx.check(text + "\n" + "\n".join(q["q"] for q in qs))
        if dup:
            no("dedupe vs Content: " + dup.split(":")[0]); continue
        idx.add(iid, text + "\n" + "\n".join(q["q"] for q in qs))
        item = {"id": iid, "type": "readDaily", "cefr": cefr.estimate(text), "skill": "reading", "title": "Placeholder title",
                "text": text, "questions": [dict(q, explanation="Placeholder explanation.") for q in qs]}
        probs = schema.problems_item(item)
        if probs:
            no("schema: " + probs[0][:50]); continue
        wp = workplace.score(text)
        meta = {"cefr": item["cefr"], "skill": "reading", "source": "belebele", "sourceId": link, "license": LICENSE,
                "tier": "share-alike", "group": f"belebele:{r['key']}", "origin": "verbatim"}
        if wp >= 0.04:
            meta["topics"] = ["workplace"]
        out.append({"id": iid, "type": "readDaily", "text": text,
                    "questions": [dict(q, correct=q["options"][q["answer"]]) for q in qs], "locked_meta": meta, "_wp": wp})
    out.sort(key=lambda x: (-x["_wp"], x["id"]))
    for o in out:
        del o["_wp"]
    import shutil
    bdir = stage / "batches"
    shutil.rmtree(bdir, ignore_errors=True)
    bdir.mkdir(parents=True)
    n = len(out)
    nb = max(1, -(-n // 60))
    sizes = [n // nb + (1 if i < n % nb else 0) for i in range(nb)]
    pos, paths = 0, []
    for i, sz in enumerate(sizes, 1):
        path = bdir / f"batch-{i:02d}.jsonl"
        with path.open("w", encoding="utf-8") as f:
            for row in out[pos:pos + sz]:
                f.write(json.dumps(row, ensure_ascii=False) + "\n")
        paths.append(path); pos += sz
    lines = ["\n## batches (readDaily from reading share)\n", f"- readDaily rows staged: {n} in {nb} batch files {sizes}",
             "- readAcademic: 0 staged. Every `link` in eng_Latn has exactly ONE passage (488 passages, 488 links), so the plan's "
             "same-`link` join is impossible, and joining passages of different pages would be incoherent. Native 150-220 word "
             f"passages (all have <=2 real questions, so the required 5 would need LLM-written questions): {json.dumps(acad)}",
             f"- workplace-tagged: {sum(1 for o in out if 'topics' in o['locked_meta'])}", "\n### Reject reasons\n"]
    lines += [f"- {k}: {v}" for k, v in sorted(rej.items(), key=lambda kv: -kv[1])]
    lines += ["\n### 30 random staged rows\n"]
    for o in random.Random(7).sample(out, min(30, n)):
        lines.append(f"- `{o['id']}` [{o['locked_meta']['cefr']}] {o['text'][:140]} | Q1: {o['questions'][0]['q']}")
    prev = report.read_text(encoding="utf-8") if report.exists() else ""
    prev = prev.split("\n## batches")[0]
    report.write_text(prev + "\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines[:5])); print(*map(str, paths), sep="\n")


# found while reading the emitted sample: political, military, tragedy or sensitive topics are filtered out of daily practice
POST_BLOCK = re.compile(r"\b(ISIS|Taliban|Trump|Obama|Iraq|Afghan\w*|Palestin\w*|Gaza|stereotyp\w*|Planned Parenthood|abortion|"
                        r"troops?|regiments?|reinforcements?|Colonists?|memorial|skyscrapers?|earthquakes?|tsunami|nuclear)\b", re.I)
MANUAL_REJECT = {
    "rd-belebele-ef9c5cf1": "text refers to an unnamed 'this arrangement' (missing context)",
    "rd-belebele-48a4e86f": "arrests/detention topic",
    "rd-belebele-8b97b8e6": "WWII naval war topic",
    "rd-belebele-bab487b3": "party politics",
    "rd-belebele-6f31c264": "party politics",
    "rd-belebele-143f48c1": "starts mid-thought ('The work done')",
    "rd-belebele-09f64b91": "starts mid-thought ('Following the race')",
    "rd-belebele-b81376ee": "starts mid-thought ('Be assured that once')",
    "rd-belebele-a72bad12": "Q2 key mixes the venue with a wrong distance (La Plata is the city 31 miles away); ambiguous",
}


def emit_reading_cmd(stage: Path, report: Path) -> None:
    """Merge the filled batches (title + explanations by the fill step) into readDaily items."""
    bdir = stage / "batches"
    items, rej, stats = [], {}, []
    # emit rewrites its own file, so keep it out of the dedupe index (idempotent reruns)
    (ROOT / "Content/items/read-daily-belebele.json").unlink(missing_ok=True)
    idx = dedupe.DedupeIndex.from_content(ROOT / "Content")

    def no(reason):
        rej[reason] = rej.get(reason, 0) + 1

    for bf in sorted(bdir.glob("batch-*.jsonl")):
        if bf.name.endswith(".filled.jsonl"):
            continue
        base = [json.loads(l) for l in bf.read_text(encoding="utf-8").splitlines()]
        ff = bf.with_name(bf.stem + ".filled.jsonl")
        filled = {r["id"]: r for r in (json.loads(l) for l in ff.read_text(encoding="utf-8").splitlines())}
        nrej = 0
        for b in base:
            f = filled.get(b["id"])
            if f is None:
                no("missing from filled file"); nrej += 1; continue
            if f.get("reject") or f.get("flag"):
                no("rejected by fill step (key/ambiguity)"); nrej += 1; continue
            title = (f.get("title") or "").strip()
            exps = f.get("explanations") or []
            if not title or len(title.split()) > 8:
                no("bad title"); nrej += 1; continue
            if len(exps) != len(b["questions"]) or any(not str(e).strip() for e in exps):
                no("explanation count mismatch/empty"); nrej += 1; continue
            qs = [{"q": q["q"], "options": q["options"], "answer": q["answer"], "explanation": str(e).strip()}
                  for q, e in zip(b["questions"], exps)]
            if any(q["options"][q["answer"]] != bq["correct"] for q, bq in zip(qs, b["questions"])):
                no("key changed vs staged"); nrej += 1; continue
            if b["id"] in MANUAL_REJECT:
                no("manual reject: " + MANUAL_REJECT[b["id"]]); nrej += 1; continue
            alltext = b["text"] + " " + " ".join(q["q"] + " " + " ".join(q["options"]) for q in qs)
            if POST_BLOCK.search(alltext):
                no("politics/military/tragedy/stereotype vocabulary"); nrej += 1; continue
            if re.search(r"\b[a-z]{3,}[.!?] [a-z]", b["text"]) or re.match(r"[a-z]", b["text"]):
                no("corrupted sentence start (lowercase after full stop)"); nrej += 1; continue
            if re.search(r"\b(Figure|Fig\.|Table) \d|see (the )?(figure|above|below)", b["text"], re.I):
                no("figure/table reference in text"); nrej += 1; continue
            m = b["locked_meta"]
            it = {"id": b["id"], "type": "readDaily", "cefr": m["cefr"], "skill": "reading", "title": title,
                  "text": b["text"], "questions": qs, "source": m["source"], "sourceId": m["sourceId"],
                  "license": m["license"], "tier": m["tier"], "group": m["group"], "origin": "adapted"}
            if "topics" in m:
                it["topics"] = m["topics"]
            probs = schema.problems_item(it)
            if probs:
                no("schema: " + probs[0][:60]); nrej += 1; continue
            dup = idx.check_and_add(it["id"], b["text"] + "\n" + "\n".join(q["q"] for q in qs))
            if dup:
                no("dedupe: " + dup.split(":")[0]); nrej += 1; continue
            items.append(it)
        stats.append((bf.name, len(base), nrej))
    items.sort(key=lambda x: x["id"])
    emit_lib.emit(ROOT / "Content", "items", "read-daily-belebele.json", items, source="belebele", url=URL,
                  license=LICENSE, tier="share-alike",
                  attribution="Belebele (Meta AI, facebook/belebele eng_Latn); passages from FLORES-200 (Wikinews, Wikivoyage), CC BY-SA 4.0; titles and explanations written by Claude")
    dist, keys = {}, {}
    for i in items:
        dist[i["cefr"]] = dist.get(i["cefr"], 0) + 1
        for q in i["questions"]:
            keys[q["answer"]] = keys.get(q["answer"], 0) + 1
    lines = [f"\n## emit-reading: {len(items)} readDaily items -> Content/items/read-daily-belebele.json\n",
             "readAcademic: 0 emitted (every link has a single passage; no joins possible, see batches section)",
             "CEFR (weak lexical estimate): " + ", ".join(f"{k}={v}" for k, v in sorted(dist.items())),
             "answer index distribution: " + ", ".join(f"{k}={v}" for k, v in sorted(keys.items())),
             f"workplace-tagged: {sum(1 for i in items if 'topics' in i)}", "\n### Reject rate per batch\n"]
    lines += [f"- {n}: {r}/{t} rejected ({100 * r / t:.0f}%)" for n, t, r in stats]
    lines += ["\n### Reject reasons\n"] + [f"- {k}: {v}" for k, v in rej.items()]
    lines += ["\n### 30 random emitted items\n"]
    for i in random.Random(11).sample(items, min(30, len(items))):
        lines.append(f"- `{i['id']}` [{i['cefr']}] **{i['title']}** | {i['text']}")
        for q in i["questions"]:
            lines.append(f"    - Q: {q['q']} | key: {q['options'][q['answer']]} | opts: {q['options']} | why: {q['explanation']}")
    prev = report.read_text(encoding="utf-8") if report.exists() else ""
    prev = prev.split("\n## emit-reading")[0]
    report.write_text(prev + "\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines[:12]))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["fetch", "extract", "emit", "batches", "emit-reading"])
    ap.add_argument("--raw", default=str(ROOT / ".ingest/raw/belebele"))
    ap.add_argument("--stage", default=str(ROOT / ".ingest/stage/belebele"))
    ap.add_argument("--report", default=str(ROOT / ".ingest/reports/belebele.md"))
    a = ap.parse_args()
    if a.cmd == "fetch":
        fetch(Path(a.raw))
    elif a.cmd == "extract":
        extract(Path(a.raw), Path(a.stage), Path(a.report))
    elif a.cmd == "emit-reading":
        emit_reading_cmd(Path(a.stage), Path(a.report))
    elif a.cmd == "batches":
        batches_cmd(Path(a.stage), Path(a.report))
    else:
        emit_cmd(Path(a.stage), Path(a.report))


if __name__ == "__main__":
    main()
