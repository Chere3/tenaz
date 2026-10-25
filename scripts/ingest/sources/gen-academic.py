"""P3 readAcademic: 150-220 word academic texts + 5 LLM-written questions -> read-academic-openstax.json, read-academic-ose.json.

  python -I scripts/ingest/sources/gen-academic.py fetch                       # nothing to download: reuses raw/openstax and stage/onestopenglish
  python -I scripts/ingest/sources/gen-academic.py extract                     # builds stage/gen-academic/{openstax,ose}.jsonl + batches/batch-NN.jsonl
  python -I scripts/ingest/sources/gen-academic.py emit                        # reads batches/batch-NN.filled.jsonl -> Content/items/*

Texts are verbatim (whole paragraphs, 1-3 consecutive ones of one OpenStax section, or one OneStopEnglish Adv chunk),
so origin is "adapted" only because questions/options/explanations are LLM-written. Licenses were verified by the
openstax (CC BY 4.0, tier permissive) and onestopenglish (CC BY-SA 4.0, tier share-alike) converters.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import random
import re
import sys
from collections import Counter
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib import cefr, dedupe, emit as emitlib, ids, schema, textnorm, workplace  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
STAGE = ROOT / ".ingest/stage/gen-academic"
RAW_OPENSTAX = ROOT / ".ingest/raw/openstax"
OSE_STAGE = ROOT / ".ingest/stage/onestopenglish"
QA_ARTICLES = ROOT / ".ingest/stage/onestopqa/articles.json"
REPORT = ROOT / ".ingest/reports/gen-academic.md"
BATCH_SIZE = 40
TARGET = {"openstax": 300, "ose": 120}
STAGE_N = {"openstax": 345, "ose": 140}          # ~15% over target for LLM rejects
OWN_FILES = ("read-academic-openstax", "read-academic-ose")
SHUFFLE_SALT = "gen-academic-v1"

OPENSTAX_META = dict(file="read-academic-openstax.json", name="OpenStax (HuggingFaceTB/openstax_paragraphs)",
                     url="https://huggingface.co/datasets/HuggingFaceTB/openstax_paragraphs", license="CC BY 4.0", tier="permissive",
                     attribution=("OpenStax, Rice University (CC BY 4.0); via HuggingFaceTB/openstax_paragraphs. Passages are verbatim "
                                  "paragraphs from the textbooks; questions, options and explanations are LLM-written."))
OSE_META = dict(file="read-academic-ose.json", name="OneStopEnglish corpus (Adv-Txt)",
                url="https://github.com/nishkalavallabhi/OneStopEnglishCorpus", license="CC BY-SA 4.0", tier="share-alike",
                attribution=("Vajjala, S. and Lucic, I. (2018). OneStopEnglish corpus: A new corpus for automatic readability assessment "
                             "and text simplification. BEA Workshop, ACL. Texts adapted from Guardian articles by onestopenglish.com. "
                             "Passages unchanged; questions, options and explanations LLM-written. CC BY-SA 4.0."))
GENERIC_TITLE = re.compile(r"^(introduction|summary|preface|key terms|chapter|overview|conclusion|review|about|glossary|"
                           r"learning objectives|check your|link to learning|case|appendix)\b", re.I)


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def shingles(text: str, n: int = 6) -> set[str]:
    toks = textnorm.normalize_for_hash(text).split()
    return {" ".join(toks[i:i + n]) for i in range(len(toks) - n + 1)}


def existing(own_prefixes=OWN_FILES):
    """Dedupe index + 6-gram set over all text in Content/ (skipping our own previous output, so reruns are stable)."""
    index, grams = dedupe.DedupeIndex(), set()
    for sub in ("items", "vocab"):
        for f in sorted((ROOT / "Content" / sub).glob("*.json")):
            if f.name.startswith(own_prefixes):
                continue
            for row in json.loads(f.read_text(encoding="utf-8")):
                index.add(row["id"], dedupe.item_text(row))
                for k in ("text", "passage", "script"):
                    v = row.get(k)
                    if isinstance(v, str):
                        grams |= shingles(v.replace("{{", "").replace("}}", ""))
    return index, grams


def overlap(text: str, grams: set[str]) -> float:
    s = shingles(text)
    return len(s & grams) / max(1, len(s))


def fetch(_a) -> None:
    for p in (RAW_OPENSTAX / "openstax_books.jsonl", OSE_STAGE / "readacademic.jsonl"):
        print(("ok      " if p.exists() else "MISSING ") + str(p))
    print("Nothing to download: run sources/openstax.py fetch and sources/onestopenglish.py fetch+extract first if MISSING.")


# ----------------------------------------------------------------------------- OpenStax

def openstax_candidates(rej: Counter):
    ox = load_module("openstax_conv", Path(__file__).with_name("openstax.py"))
    chapters: dict[tuple, list[dict]] = {}
    for r in ox.extract_paragraphs(RAW_OPENSTAX):
        chapters.setdefault((r["book"], r["chapter"]), []).append(r)
    out = []
    for (book, chapter), paras in chapters.items():
        units = []                      # chapter order; None marks a paragraph that failed a filter (a barrier)
        for r in paras:
            section = r["section"]
            p = ox.clean_para(r["raw"])
            wc = textnorm.word_count(p)
            key = f'{book}|{chapter}|{section}|{r["pi"]}'
            share = "cw" if int(hashlib.sha256(("share|" + key).encode()).hexdigest(), 16) % 10 < 3 else "other"
            why = None
            if not section or re.search(r"[^\x20-\x7E]", section): why = "odd section title"
            elif wc < 25 or wc > 200: why = "paragraph length"
            elif share == "cw": why = "paragraph in the completeWords share"
            elif ox.BAD_PARA.search(p): why = "formula / figure-table ref / citation / symbols"
            elif len(re.findall(r"\d", p)) > 10 or len(re.findall(r"\d", p)) / len(p) > 0.02: why = "number-heavy"
            elif ox.SENSITIVE.search(p): why = "sensitive keyword"
            elif ox.SCAFFOLD.search(p): why = "course scaffolding wording"
            elif re.search(r"\b[A-Za-z]\b(?<!\bI)(?<!\bA)(?<!\ba)", p.replace("'", "")): why = "stray single letters"
            elif "?" in p or "$" in p: why = "question / dollar sign"
            elif not re.search(r"[.!]$", p): why = "no terminal punctuation"
            elif re.search(r"[^\x20-\x7E]", p): why = "non-ascii"
            elif any(len(x.split()) > 45 for x in textnorm.split_sentences(p)): why = "sentence >45 words"
            if why:
                rej["paragraph: " + why] += 1
                units.append(None)
                continue
            units.append({"section": section.strip(), "pi": r["pi"], "p": p, "wc": wc})
        i = 0
        while i < len(units):
            u = units[i]
            if u is None or ox.START_BAD.match(u["p"]) or GENERIC_TITLE.match(u["section"]):
                i += 1
                continue
            n, take = 0, []
            for k in range(4):
                if i + k >= len(units) or units[i + k] is None:
                    break
                take.append(units[i + k]); n += units[i + k]["wc"]
                if n >= 150:
                    break
            if not 150 <= n <= 220 or len(textnorm.split_sentences(" ".join(t["p"] for t in take))) < 6:
                i += 1
                continue
            text = " ".join(t["p"] for t in take)
            secs = []
            for t in take:
                if t["section"] not in secs:
                    secs.append(t["section"])
            topic, boost = ox.BOOKS[book]
            out.append({"source": "openstax", "sourceId": hashlib.sha256(f"{book}|{chapter}|{take[0]['section']}|{take[0]['pi']}".encode()).hexdigest()[:10],
                        "book": book, "title": secs[0], "sections": secs, "text": text, "words": n, "paras": len(take),
                        "topic": topic, "boost": boost})
            i += len(take)
    rej["windows built"] = len(out)
    return out


def openstax_select(cands: list[dict], index, grams, rej: Counter) -> list[dict]:
    pool = []
    for c in cands:
        c["cefrEstimate"] = cefr.estimate(c["text"])
        c["workplace"] = round(workplace.score(c["text"]), 3)
        c["score"] = c["workplace"] + c["boost"] + {"B2": 0.3, "B2+": 0.25}.get(c["cefrEstimate"], 0.0) + random.Random(c["sourceId"]).random() * 0.15
        pool.append(c)
    pool.sort(key=lambda c: -c["score"])
    caps = {"biology": 40}
    per_book, per_topic, chosen = Counter(), Counter(), []
    for c in pool:
        if len(chosen) >= STAGE_N["openstax"]:
            break
        if per_book[c["book"]] >= 45 or per_topic[c["topic"]] >= caps.get(c["topic"], 400):
            rej["selection cap (per book 45 / biology 40)"] += 1
            continue
        if (o := overlap(c["text"], grams)) >= 0.3:
            rej["6-gram overlap >= 0.3 with existing Content/"] += 1
            continue
        iid = ids.item_id("readAcademic", "openstax", c["sourceId"])
        if reason := index.check_and_add(iid, c["text"]):
            rej["dedupe: " + reason.split(" of ")[0]] += 1
            continue
        c["id"] = iid
        per_book[c["book"]] += 1; per_topic[c["topic"]] += 1
        chosen.append(c)
    return chosen


# ----------------------------------------------------------------------------- OneStopEnglish

def ose_select(index, grams, rej: Counter) -> list[dict]:
    oe = load_module("ose_conv", Path(__file__).with_name("onestopenglish.py"))
    qa_titles = {ids.slug(t) for t in json.loads(QA_ARTICLES.read_text())["titles"]}
    rows = [json.loads(l) for l in (OSE_STAGE / "readacademic.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()]
    pool = []
    for r in rows:
        text, art = r["text"], r["article"]
        why = None
        if art in qa_titles or ids.slug(r["title"]) in qa_titles: why = "article already used by OneStopQA"
        elif oe.BAD.search(text): why = "sensitive/childish word"
        elif oe.SKIP_PARA.search(text): why = "byline/boilerplate"
        elif not text[0].isupper() or text[0] == '"': why = "opens mid-sentence or on an unattributed quote"
        elif oe.BAD_START.match(text) or re.search(r"\b(the same|these|those|such|this|former|latter|the other)\b", " ".join(text.split()[:8]), re.I): why = "opening not self-contained"
        elif oe.damaged_text(text): why = "extraction damage"
        elif len(re.findall(r"\d", text)) > 10: why = "number-heavy"
        elif len(textnorm.split_sentences(text)) < 6: why = "<6 sentences"
        elif re.search(r"[A-Za-z]\s?[\[\]{}<>|_]|\.\.\.|…|\([^)]*$", text): why = "odd punctuation"
        elif re.search(r"[^\x20-\x7E]", text): why = "non-ascii"
        if why:
            rej["ose: " + why] += 1
            continue
        r["cefrEstimate"] = cefr.estimate(text, "C1")
        r["workplace"] = round(workplace.score(text), 3)
        r["score"] = r["workplace"] + random.Random(r["sourceId"]).random() * 0.15
        pool.append(r)
    pool.sort(key=lambda c: -c["score"])
    per_art, chosen = Counter(), []
    for c in pool:
        if len(chosen) >= STAGE_N["ose"]:
            break
        if per_art[c["article"]] >= 2:
            rej["ose: article cap (2)"] += 1
            continue
        if overlap(c["text"], grams) >= 0.3:
            rej["ose: 6-gram overlap >= 0.3 with existing Content/ (e.g. complete-words-ose)"] += 1
            continue
        iid = ids.item_id("readAcademic", "ose", c["sourceId"])
        if reason := index.check_and_add(iid, c["text"]):
            rej["ose: dedupe: " + reason.split(" of ")[0]] += 1
            continue
        per_art[c["article"]] += 1
        chosen.append({"id": iid, "source": "ose", "sourceId": c["sourceId"], "book": None, "title": c["title"], "text": c["text"],
                       "words": c["words"], "topic": "news", "cefrEstimate": c["cefrEstimate"], "workplace": c["workplace"],
                       "group": f"ose:{c['article']}"})
    return chosen


# ----------------------------------------------------------------------------- extract

def extract(_a) -> None:
    (STAGE / "batches").mkdir(parents=True, exist_ok=True)
    for old in (STAGE / "batches").glob("batch-*.jsonl"):
        if ".filled." not in old.name:
            old.unlink()
    rej: Counter = Counter()
    index, grams = existing()
    ox = openstax_select(openstax_candidates(rej), index, grams, rej)
    oe = ose_select(index, grams, rej)
    for c in ox:
        c.setdefault("group", None)
    staged = {"openstax": ox, "ose": oe}
    batches = []
    for src, rows in staged.items():
        rows.sort(key=lambda r: r["id"])
        (STAGE / f"{src}.jsonl").write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows), encoding="utf-8")
        nb = max(1, round(len(rows) / BATCH_SIZE))      # even split keeps every batch inside 25-50 rows
        for j in range(nb):
            batches.append((src, rows[j * len(rows) // nb:(j + 1) * len(rows) // nb]))
    paths = []
    for n, (src, chunk) in enumerate(batches, 1):
        p = STAGE / "batches" / f"batch-{n:02d}.jsonl"
        with p.open("w", encoding="utf-8") as f:
            for r in chunk:
                f.write(json.dumps({"id": r["id"], "source": src, "title": r["title"], "text": r["text"], "words": r["words"],
                                    "topic": r["topic"], "cefrEstimate": r["cefrEstimate"],
                                    **({"sectionTitles": r["sections"]} if len(r.get("sections", [])) > 1 else {})}, ensure_ascii=False) + "\n")
        paths.append(p)
        print(p, len(chunk))
    L = [f"# gen-academic report ({date.today()})", "",
         "Licenses: OpenStax paragraphs CC BY 4.0 (permissive), checked by sources/openstax.py; OneStopEnglish CC BY-SA 4.0 (share-alike), checked by sources/onestopenglish.py.", "",
         "## Staged for LLM questions", ""]
    for src, rows in staged.items():
        L.append(f"- {src}: {len(rows)} (target after rejects {TARGET[src]}); CEFR {dict(Counter(r['cefrEstimate'] for r in rows))}; "
                 f"words min/median/max {min(r['words'] for r in rows)}/{sorted(r['words'] for r in rows)[len(rows)//2]}/{max(r['words'] for r in rows)}")
    L.append(f"- openstax by book: {dict(Counter(r['book'] for r in ox))}")
    L.append(f"- openstax by topic: {dict(Counter(r['topic'] for r in ox))}; multi-paragraph windows: {sum(1 for r in ox if r['paras'] > 1)}")
    L.append(f"- ose distinct articles: {len({r['group'] for r in oe})}")
    L.append(f"- batches: {len(paths)} -> " + ", ".join(p.name for p in paths))
    L += ["", "## Rejects", ""] + [f"- {k}: {v}" for k, v in rej.most_common()]
    REPORT.write_text("\n".join(L) + "\n", encoding="utf-8")
    print("\n".join(L))


# ----------------------------------------------------------------------------- emit

def shuffled(item_id: str, qi: int, options: list[str]) -> tuple[list[str], int]:
    """Fill agents write the correct option first; shuffle deterministically and return (options, new answer index)."""
    seed = int(hashlib.sha256(f"{SHUFFLE_SALT}:{item_id}:{qi}".encode()).hexdigest(), 16)
    order = list(range(4))
    random.Random(seed).shuffle(order)
    return [options[i] for i in order], order.index(0)


def question_problems(q: dict, text: str, qi: int) -> str | None:
    opts = q.get("options")
    if not isinstance(opts, list) or len(opts) != 4 or not all(isinstance(o, str) and o.strip() for o in opts):
        return "options not 4 strings"
    if len({o.strip().lower() for o in opts}) != 4:
        return "duplicate options"
    stem = (q.get("q") or "").strip()
    completion = qi in (2, 3) and not stem.endswith(("?", ".")) and re.search(r"(closest in meaning to|most likely\b.*|likely \w+|believes|feel that|because it|looking at|would|infer|suggest)\s*$", stem, re.I)
    if (not stem.endswith(("?", ".")) and not completion) or len(stem.split()) < 4:
        return "bad stem"
    e = (q.get("explanation") or "").strip()
    if not 8 <= len(e.split()) <= 35 or len(re.findall(r"[.!?](?:\s|$)", e)) != 1 or not e.endswith((".", "!", "?")):
        return "explanation not one sentence of 8-35 words"
    if len(opts[0]) > 1.8 * sorted(len(o) for o in opts)[2] + 12:
        return "key much longer than distractors"
    if re.search(r"\b(all|none) of the above\b|\bboth [A-D]\b", " ".join(opts), re.I):
        return "all/none of the above"
    low = text.lower()
    if qi in (2, 4):
        m = re.search(r"['\"‘’]([^'\"‘’]{2,120})['\"‘’]", stem)
        if not m or m.group(1).lower().strip(".,;") not in low:
            return "vocabulary/purpose stem must quote words that appear verbatim in the text"
    if qi == 2 and "closest in meaning" not in stem.lower():
        return "vocabulary stem must say 'closest in meaning'"
    if qi == 4 and not re.match(r"why does the (author|writer)", stem, re.I):
        return "purpose stem must start 'Why does the author'"
    if qi == 3 and not re.search(r"\b(infer\w*|suggest\w*|impl\w+|likely|probably|would|might|could|conclusion|supported|what happens|how can)\b", stem, re.I):
        return "inference stem lacks an inference cue"
    if re.search(r"\b(paragraph|passage says|according to the (text|passage|author)) ?\d", stem, re.I):
        return "stem refers to paragraph numbers"
    return None


def emit_step(_a) -> None:
    staged = {}
    for src in ("openstax", "ose"):
        for l in (STAGE / f"{src}.jsonl").read_text(encoding="utf-8").splitlines():
            if l.strip():
                r = json.loads(l); staged[r["id"]] = (src, r)
    index, _ = existing()
    rej: Counter = Counter()
    out: dict[str, list[dict]] = {"openstax": [], "ose": []}
    per_batch, seen = [], set()
    for fp in sorted((STAGE / "batches").glob("batch-*.filled.jsonl")):
        rows = [json.loads(l) for l in fp.read_text(encoding="utf-8").splitlines() if l.strip()]
        per_batch.append((fp.name.split(".")[0], len(rows), sum(1 for r in rows if r.get("reject") or r.get("arguable"))))
        for r in rows:
            if r["id"] not in staged: rej["id not staged"] += 1; continue
            if r["id"] in seen: rej["duplicate id"] += 1; continue
            seen.add(r["id"])
            src, d = staged[r["id"]]
            if r.get("reject"): rej["rejected by fill agent"] += 1; continue
            if r.get("arguable"): rej["a question had two defensible answers (arguable)"] += 1; continue
            qs_in = r.get("questions") or []
            if len(qs_in) != 5: rej["not 5 questions"] += 1; continue
            qs, bad = [], None
            for qi, q in enumerate(qs_in):
                bad = question_problems(q, d["text"], qi)
                if bad: break
                opts, ans = shuffled(d["id"], qi, [o.strip() for o in q["options"]])
                qs.append({"q": q["q"].strip(), "options": opts, "answer": ans, "explanation": q["explanation"].strip()})
            if bad: rej["question: " + bad] += 1; continue
            level = r.get("cefr") if r.get("cefr") in ("B1+", "B2", "B2+", "C1") else d["cefrEstimate"]
            meta = OPENSTAX_META if src == "openstax" else OSE_META
            title = (r.get("title") or "").strip() if len(d.get("sections", [])) > 1 else d["title"]
            if not 1 <= len(title.split()) <= 8: rej["title missing/too long (joined sections need a 2-7 word title)"] += 1; continue
            item = {"id": d["id"], "type": "readAcademic", "skill": "reading", "cefr": level, "title": title, "text": d["text"],
                    "questions": qs, "source": src if src == "openstax" else "onestopenglish", "sourceId": d["sourceId"],
                    "license": meta["license"], "tier": meta["tier"], "origin": "adapted",
                    "topics": [t for t in {d["topic"], "workplace" if d.get("workplace", 0) >= 0.04 else ""} if t]}
            if d.get("group"): item["group"] = d["group"]
            if probs := schema.problems_item(item): rej["schema: " + probs[0][:70]] += 1; continue
            if dup := index.check(d["text"]): rej["dedupe against Content/: " + dup.split(" of ")[0]] += 1; continue
            out[src].append(item)
    for src, meta in (("openstax", OPENSTAX_META), ("ose", OSE_META)):
        rows = sorted(out[src], key=lambda i: i["id"])
        if rows:
            emitlib.emit(ROOT / "Content", "items", meta["file"], rows, source=meta["name"], url=meta["url"], license=meta["license"],
                         tier=meta["tier"], attribution=meta["attribution"])
    items = out["openstax"] + out["ose"]
    L = ["", "# gen-academic emit", "",
         f"- emitted: {len(out['openstax'])} openstax -> Content/items/read-academic-openstax.json; {len(out['ose'])} ose -> Content/items/read-academic-ose.json", "",
         "## Fill-agent reject rate per batch (above 15% = the prompt is wrong)", ""]
    L += [f"- {n}: {r_}/{t} ({100 * r_ / max(1, t):.0f}%)" for n, t, r_ in per_batch]
    L += ["", "## Emit filters", ""] + [f"- {k}: {v}" for k, v in sorted(rej.items())]
    L += ["", "- CEFR: " + str(dict(Counter(i["cefr"] for i in items))),
          "- answer positions: " + ", ".join(f"{a}={sum(1 for i in items for q in i['questions'] if q['answer'] == a)}" for a in range(4)), "",
          "## 30 random items", ""]
    for it in random.Random(11).sample(items, min(30, len(items))):
        L.append(f"### `{it['id']}` [{it['cefr']}] {it['title']}\n{it['text']}")
        for q in it["questions"]:
            L.append(f"- Q: {q['q']} -> {q['options'][q['answer']]}  (opts: {' / '.join(q['options'])})\n  expl: {q['explanation']}")
        L.append("")
    prev = REPORT.read_text(encoding="utf-8").split("\n# gen-academic emit")[0] if REPORT.exists() else ""
    REPORT.write_text(prev + "\n".join(L) + "\n", encoding="utf-8")
    print("\n".join(L[:25]))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["fetch", "extract", "emit"])
    a = ap.parse_args()
    {"fetch": fetch, "extract": extract, "emit": emit_step}[a.cmd](a)


if __name__ == "__main__":
    main()
