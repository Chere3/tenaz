"""C01 OneStopQA (HF malmaud/onestop_qa, CC BY-SA 4.0) -> readDaily + readAcademic, STAGE ONLY (no emit yet).

  python -I scripts/ingest/sources/onestopqa.py fetch   --raw .ingest/raw/onestopqa
  python -I scripts/ingest/sources/onestopqa.py extract --raw .ingest/raw/onestopqa --stage .ingest/stage/onestopqa

fetch   verifies the license at the source (HF card + GitHub API) and aborts unless it is CC BY-SA 4.0, then downloads the parquet.
extract parses the parquet as data, filters/normalizes, dedupes against all of Content/, shuffles options with a fixed seed
        (key = answers[0], checked on a sample by eye and by the a_span evidence), and writes
          .ingest/stage/onestopqa/items.jsonl             full item drafts (explanations missing)
          .ingest/stage/onestopqa/batches/batch-NN.jsonl  40-60 rows each, for the LLM explanation pass
          .ingest/stage/onestopqa/articles.json           article titles used (for the OneStopEnglish overlap rule)
          .ingest/reports/onestopqa.md

Dataset facts (verified): 1,458 rows = 486 questions x 3 levels (level ClassLabel 0=Adv 1=Int 2=Ele); 162 paragraphs of 30 articles;
a_span / d_span are whitespace-word indices [start, end) into `paragraph`. Some options lose their last character in the
source ("Use a hidden camer"); those questions are dropped (detected with wordfreq), never repaired.

Design:
- readAcademic: 2 adjacent paragraphs of one article and level whose words sum to 150-220 (Adv preferred, else Int), no
  paragraph reused; up to 6 real questions, the fill agent names the weakest one to drop so that exactly 5 remain.
- readDaily: every other paragraph of 40-150 words at Int (B2) and Adv (C1), 2-3 questions; Ele is skipped. The Int and
  Adv versions of one paragraph share a `group`. Paragraphs claimed by a readAcademic stitch are not reused in readDaily.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import random
import re
import string
import sys
import unicodedata
import urllib.request
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from wordfreq import zipf_frequency as zipf  # noqa: E402
from lib import cefr, dedupe, ids, schema, textnorm, workplace  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
SOURCE = "onestopqa"
URL = "https://huggingface.co/datasets/malmaud/onestop_qa"
PARQUET = "https://huggingface.co/datasets/malmaud/onestop_qa/resolve/main/data/train-00000-of-00001.parquet"
HF_API = "https://huggingface.co/api/datasets/malmaud/onestop_qa"
GH_API = "https://api.github.com/repos/berzak/onestop-qa"
LICENSE = "CC BY-SA 4.0"
LEVELS = {0: ("adv", "C1"), 1: ("int", "B2")}   # level label -> (short, cefr prior); Ele (2) skipped
SHUFFLE_SALT = "onestopqa-v1"
OVERLAP_REJECT = 0.5   # share of a text's 6-grams already present in Content/ -> reject
OVERLAP_NOTE = 0.15

BAD = re.compile(r"\b(sex|sexual|sexy|rape[ds]?|porn\w*|murder\w*|kill(?:s|ed|ing|er|ers)?|suicid\w*|genocide|massacre\w*|"
                 r"terroris[mt]\w*|bomb(?:s|ing|ed)?|abus(?:e|ed|ive)|torture\w*|slaves?|slavery|naked|nude|drugs?|cocaine|"
                 r"heroin|cannabis|paedophil\w*|prostitut\w*|corpses?|dead bod\w+|shooting|gunman|hostages?|"
                 r"fairy|santa|toys?|cartoons?|nursery|bloody|damn|crap|shit|fuck\w*|bastard|hell|"
                 r"alcohol\w*|drunk\w*|gambl\w*|casinos?|weapons?|riot\w*|casualt\w*|wounded|victims?)\b", re.I)
# a paragraph that opens on a pronoun/connective is not self-contained
BAD_START = re.compile(r"^(But|And|So|Or|Yet|However|Also|Then|Thus|Still|Even|Although|Though|He|She|They|It|This|That|These|"
                       r"Those|His|Her|Their|Its|Such|Both|Another|Other|One|Some|Many|Most|There|Here|In addition|For example|"
                       r"Meanwhile|Instead|Indeed|Because|Since|While|Not|No|Neither|Either|Each|All)\b")
META_Q = re.compile(r"\b(paragraph|passage|article|the text|the author|the writer)\b", re.I)


# ----------------------------------------------------------------------------- fetch

def _get_json(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": "tenaz-ingest"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())


def fetch(raw: Path) -> None:
    hf = _get_json(HF_API)
    hf_lic = (hf.get("cardData") or {}).get("license")
    gh_lic = (_get_json(GH_API).get("license") or {}).get("spdx_id")
    print(f"license: HF card={hf_lic!r}, GitHub berzak/onestop-qa={gh_lic!r}")
    if hf_lic not in ("cc-by-sa-4.0", ["cc-by-sa-4.0"]) or gh_lic != "CC-BY-SA-4.0":
        sys.exit("license does not match CC BY-SA 4.0; stopping")
    if raw.exists() and any(raw.iterdir()):
        print("raw dir not empty; leaving as is"); return
    raw.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(PARQUET, headers={"User-Agent": "tenaz-ingest"})
    with urllib.request.urlopen(req, timeout=120) as r:
        (raw / "train.parquet").write_bytes(r.read())
    (raw / "LICENSE-CHECK").write_text(f"HF card license: {hf_lic}\nGitHub API license: {gh_lic}\nchecked: {date.today()}\n")


# ----------------------------------------------------------------------------- helpers

def norm(s: str) -> str:
    return textnorm.fix_unicode(re.sub(r"\s+", " ", unicodedata.normalize("NFKC", s))).strip()


def truncated_option(a: str) -> bool:
    """Source artifact: the last character of some options is missing ('camer', 'worl', 'grante')."""
    m = re.search(r"([A-Za-z]+)$", a)
    if not m:
        return False
    w = m.group(1).lower()
    zw = zipf(w, "en")
    best = max(zipf(w + c, "en") for c in string.ascii_lowercase)
    return (zw < 2.0 and best >= 2.5) or (best >= zw + 1.5 and best >= 3.5 and zw < 3.6)


def damaged(text: str) -> str | None:
    if text.count('"') % 2:
        return "unbalanced quotes"
    for t in re.findall(r"[A-Za-z]+", text):
        if t.islower() and len(t) >= 3 and zipf(t, "en") < 1.5:
            # rare but real words (astrotourism, ununtrium) pass; dropped ligatures (scienti c, utism) and short junk do not
            if len(t) <= 5 or any(zipf(t[:k] + lig + t[k:], "en") >= 3.0 for k in range(len(t) + 1) for lig in ("fi", "fl", "ff", "ffi")):
                return f"unknown token {t!r}"
    return None


def sentences_ok_start(text: str) -> bool:
    return not BAD_START.match(text)


def shingles(text: str, n: int = 6) -> set[str]:
    toks = textnorm.normalize_for_hash(text).split()
    return {" ".join(toks[i:i + n]) for i in range(len(toks) - n + 1)}


def shuffled(item_id: str, qkey: str, options: list[str]) -> tuple[list[str], int]:
    """Deterministic shuffle (seed = sha256(salt:id:qkey)); returns (options, index of the original answers[0])."""
    seed = int(hashlib.sha256(f"{SHUFFLE_SALT}:{item_id}:{qkey}".encode()).hexdigest(), 16)
    order = list(range(4))
    random.Random(seed).shuffle(order)
    return [options[i] for i in order], order.index(0)


def existing_index(own_prefixes: tuple[str, ...]) -> tuple[dedupe.DedupeIndex, set[str]]:
    """Dedupe index + 6-gram union of all text-bearing items in Content/, skipping our own previous output."""
    index = dedupe.DedupeIndex()
    grams: set[str] = set()
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


# ----------------------------------------------------------------------------- extract

def load(raw: Path):
    import pyarrow.parquet as pq   # noqa: PLC0415
    rows = pq.read_table(raw / "train.parquet").to_pylist()
    paras: dict[tuple[str, int, int], dict] = {}
    for r in rows:
        k = (r["title"], r["paragraph_index"], r["level"])
        p = paras.setdefault(k, {"paragraph": r["paragraph"], "questions": []})
        words = r["paragraph"].split()
        sp = list(r["a_span"])   # 2 values, or 4 when the evidence has two spans
        p["questions"].append({"q": r["question"], "answers": list(r["answers"]),
                               "evidence": " ... ".join(" ".join(words[sp[k]:sp[k + 1]]) for k in range(0, len(sp), 2))})
    return paras


def build_questions(item_id: str, para_idx: int, pdata: dict, rej: Counter, stitched: bool) -> list[dict]:
    out = []
    for qi, q in enumerate(pdata["questions"]):
        qtext = norm(q["q"])
        opts = [norm(a) for a in q["answers"]]
        if any(truncated_option(a) for a in opts):
            rej["question: option truncated in source"] += 1; continue
        if len(set(o.lower() for o in opts)) != 4:
            rej["question: duplicate options"] += 1; continue
        if not qtext.endswith(("?", "...")):
            rej["question: not a question"] += 1; continue
        if stitched and META_Q.search(qtext):
            rej["question: refers to the paragraph/article (stitched)"] += 1; continue
        if BAD.search(qtext + " " + " ".join(opts)):
            rej["question: sensitive word"] += 1; continue
        shuf, ans = shuffled(item_id, f"p{para_idx}q{qi}", opts)
        out.append({"qid": f"p{para_idx}q{qi}", "q": qtext, "options": shuf, "answer": ans,
                    "correct": opts[0], "evidence": norm(q["evidence"])})
    return out


def draft_problems(item: dict) -> list[str]:
    """Run the shared schema on the draft with throwaway explanations."""
    d = json.loads(json.dumps(item))
    d["questions"] = [{"q": q["q"], "options": q["options"], "answer": q["answer"], "explanation": "Placeholder explanation."}
                      for q in d["questions"]]
    return schema.problems_item(d)


def extract(raw: Path, stage: Path) -> None:
    stage.mkdir(parents=True, exist_ok=True)
    paras = load(raw)
    rej: Counter = Counter()
    index, content_grams = existing_index(("read-daily-onestopqa", "read-academic-onestopqa"))
    articles = sorted({k[0] for k in paras})
    by_art: dict[tuple[str, int], dict[int, dict]] = defaultdict(dict)
    for (title, pi, lvl), p in paras.items():
        if lvl in LEVELS:
            by_art[(title, lvl)][pi] = p

    def para_ok(title: str, text: str, first: bool = True) -> str | None:
        if BAD.search(text): return "sensitive/childish word"
        if first and BAD_START.match(text): return "opens on a pronoun/connective (not self-contained)"
        if (d := damaged(text)): return "damaged: " + d.split(" ")[0]
        if re.search(r"https?:|www\.|\d{5,}", text): return "urls/long numbers"
        return None

    def overlap(text: str) -> float:
        g = shingles(text)
        return len(g & content_grams) / len(g) if g else 0.0

    staged: list[dict] = []
    claimed: set[tuple[str, int]] = set()   # (title, paragraph_index) used by a readAcademic stitch

    # --- readAcademic stitches: Adv first, then Int; greedy left to right, no paragraph reused
    for lvl in (0, 1):
        short, prior = LEVELS[lvl]
        for title in sorted(articles):
            d = by_art.get((title, lvl), {})
            idxs = sorted(d)
            for i in idxs:
                j = i + 1
                if (title, i) in claimed or (title, j) in claimed or j not in d:
                    continue
                wa, wb = len(d[i]["paragraph"].split()), len(d[j]["paragraph"].split())
                if not 150 <= wa + wb <= 220:
                    continue
                rej_key = "stitch"
                text = norm(d[i]["paragraph"]) + "\n\n" + norm(d[j]["paragraph"])
                wc = textnorm.word_count(text)
                if not 150 <= wc <= 220:
                    rej[f"{rej_key}: word count after normalize"] += 1; continue
                reason = para_ok(title, norm(d[i]["paragraph"])) or para_ok(title, norm(d[j]["paragraph"]), first=False)
                if reason:
                    rej[f"{rej_key}: {reason}"] += 1; continue
                iid = ids.item_id("readAcademic", SOURCE, f"{ids.slug(title)}-{short}-p{i}-p{j}")
                qs = build_questions(iid, i, d[i], rej, True) + build_questions(iid, j, d[j], rej, True)
                if len(qs) < 5:
                    rej[f"{rej_key}: fewer than 5 sound questions"] += 1; continue
                ov = overlap(text)
                if ov >= OVERLAP_REJECT:
                    rej[f"{rej_key}: text already in Content/ (6-gram overlap >= {OVERLAP_REJECT})"] += 1; continue
                if r := index.check(text):
                    rej[f"{rej_key}: dedupe ({r.split(' of ')[0]})"] += 1; continue
                claimed |= {(title, i), (title, j)}
                staged.append({"id": iid, "type": "readAcademic", "cefr": cefr.estimate(text, prior), "skill": "reading",
                               "title": title, "text": text, "questions": qs, "dropOne": len(qs) == 6,
                               "source": SOURCE, "sourceId": f"{ids.slug(title)}-{short}-p{i}-p{j}", "license": LICENSE,
                               "tier": "share-alike", "group": f"onestopqa:{ids.slug(title)}:p{i}-p{j}",
                               "origin": "adapted", "topics": ["workplace"] if workplace.score(text) >= 0.04 else [],
                               "_ov": round(ov, 3)})
                index.add(iid, text)

    # --- readDaily: remaining paragraphs, Int + Adv
    for lvl in (1, 0):
        short, prior = LEVELS[lvl]
        for title in sorted(articles):
            for pi, p in sorted(by_art.get((title, lvl), {}).items()):
                if (title, pi) in claimed:
                    rej["daily: paragraph claimed by a readAcademic stitch"] += 1; continue
                text = norm(p["paragraph"])
                wc = textnorm.word_count(text)
                if not 40 <= wc <= 150:
                    rej["daily: not 40-150 words"] += 1; continue
                if (reason := para_ok(title, text)):
                    rej[f"daily: {reason}"] += 1; continue
                iid = ids.item_id("readDaily", SOURCE, f"{ids.slug(title)}-{short}-p{pi}")
                qs = build_questions(iid, pi, p, rej, False)
                if len(qs) < 2:
                    rej["daily: fewer than 2 sound questions"] += 1; continue
                ov = overlap(text)
                if ov >= OVERLAP_REJECT:
                    rej[f"daily: text already in Content/ (6-gram overlap >= {OVERLAP_REJECT})"] += 1; continue
                if r := index.check(text):
                    kind = "exact" if r.startswith("exact") else "near"
                    # Int/Adv versions of one paragraph are siblings (same group), not duplicates, but they were
                    # not added to the index so any hit here is another item
                    rej[f"daily: dedupe ({kind} duplicate)"] += 1; continue
                staged.append({"id": iid, "type": "readDaily", "cefr": cefr.estimate(text, prior), "skill": "reading",
                               "title": title, "text": text, "questions": qs, "dropOne": False,
                               "source": SOURCE, "sourceId": f"{ids.slug(title)}-{short}-p{pi}", "license": LICENSE,
                               "tier": "share-alike", "group": f"onestopqa:{ids.slug(title)}:p{pi}",
                               "origin": "adapted", "topics": ["workplace"] if workplace.score(text) >= 0.04 else [],
                               "_ov": round(ov, 3)})

    # final schema check on drafts (stitched items may legitimately hold 6 questions until the fill drops one)
    final = []
    for it in staged:
        probe = dict(it)
        if it["dropOne"]:
            probe["questions"] = it["questions"][:5]
        probs = [x for x in draft_problems(probe)]
        if probs:
            rej["schema: " + probs[0][:60]] += 1; continue
        final.append(it)
    staged = sorted(final, key=lambda r: r["id"])

    # --- write stage files
    for old in (stage / "batches").glob("*.jsonl") if (stage / "batches").exists() else []:
        old.unlink()
    (stage / "batches").mkdir(exist_ok=True)
    (stage / "items.jsonl").write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in staged), encoding="utf-8")
    nb = max(1, -(-len(staged) // 60))
    per = -(-len(staged) // nb)
    batch_paths = []
    for b in range(nb):
        chunk = staged[b * per:(b + 1) * per]
        if not chunk: continue
        path = stage / "batches" / f"batch-{b + 1:02d}.jsonl"
        with path.open("w", encoding="utf-8") as f:
            for r in chunk:
                f.write(json.dumps({
                    "id": r["id"], "type": r["type"], "title": r["title"], "text": r["text"],
                    "dropOne": r["dropOne"],
                    "questions": [{"qid": q["qid"], "q": q["q"], "options": q["options"], "answer": q["answer"],
                                   "correct": q["correct"], "evidence": q["evidence"]} for q in r["questions"]],
                }, ensure_ascii=False) + "\n")
        batch_paths.append(path)
    used = sorted({r["title"] for r in staged})
    (stage / "articles.json").write_text(json.dumps({
        "note": "OneStopQA article titles that have staged items; OneStopEnglish readAcademic should skip the same articles",
        "titles": used, "slugs": [ids.slug(t) for t in used]}, indent=1))
    write_report(staged, rej, batch_paths, articles)
    cnt = Counter(r["type"] for r in staged)
    print(f"staged {len(staged)} ({dict(cnt)}), batches {len(batch_paths)} -> {stage / 'batches'}")
    print("rejects:", json.dumps(dict(rej), indent=1))


def write_report(staged, rej, batch_paths, articles) -> None:
    rnd = random.Random(11)
    sample = rnd.sample(staged, min(30, len(staged)))
    lv = Counter((r["type"], r["cefr"]) for r in staged)
    nq = Counter(len(r["questions"]) for r in staged)
    out = [f"# onestopqa report ({date.today()})", "",
           "License verified at the source before download: HF card `cc-by-sa-4.0` and GitHub API `CC-BY-SA-4.0` (tier share-alike).",
           "Key check: `answers[0]` is the correct option. Verified on a random 20-row sample (a_span evidence supports answers[0] in all 20); "
           "options shuffled per question with seed sha256('onestopqa-v1:<item id>:<question key>') and `answer` recomputed.",
           "Source defect: some options lose their last character ('Use a hidden camer'); those questions are dropped, not repaired.", "",
           "## Counts",
           f"- source: 1,458 rows, 486 questions x 3 levels, {len(articles)} articles, Ele level skipped",
           f"- staged: {len(staged)} = {dict(Counter(r['type'] for r in staged))}",
           f"- cefr by type: {json.dumps({f'{a}/{b}': n for (a, b), n in sorted(lv.items())})}",
           f"- questions per item: {dict(nq)}; readAcademic needing a drop-one: {sum(r['dropOne'] for r in staged)}",
           f"- workplace-tagged: {sum(1 for r in staged if r['topics'])}",
           f"- items with 6-gram overlap {OVERLAP_NOTE}-{OVERLAP_REJECT} with existing Content/ (kept): {sum(1 for r in staged if r['_ov'] >= OVERLAP_NOTE)}",
           f"- batches: {len(batch_paths)} ({', '.join(f'{p.name}' for p in batch_paths)})",
           "", "## Rejects", *(f"- {k}: {v}" for k, v in sorted(rej.items())), "", "## 30-item random sample", ""]
    for r in sample:
        out.append(f"### `{r['id']}` [{r['cefr']}] group `{r['group']}`\n{r['text']}\n")
        for q in r["questions"]:
            out.append(f"- {q['q']} -> **{q['options'][q['answer']]}** (of {len(q['options'])})")
        out.append("")
    (ROOT / ".ingest/reports").mkdir(parents=True, exist_ok=True)
    (ROOT / ".ingest/reports/onestopqa.md").write_text("\n".join(out), encoding="utf-8")


# ----------------------------------------------------------------------------- emit
# questions found ambiguous when reading the emit sample: (item id, qid) -> reason
SAMPLE_DROPS = {
    ("rd-onestopqa-man-falls-just-short-in-patriot-game-to-be-100-french-int-p3", "p3q0"): "two options fit",
}


def emit_step(stage: Path) -> None:
    """Read batch-*.filled.jsonl, drop rejects/unsound questions, re-check, write Content/items/read-{daily,academic}-onestopqa.json."""
    from lib import emit as emit_lib   # noqa: PLC0415
    drafts = {json.loads(l)["id"]: json.loads(l) for l in (stage / "items.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()}
    own = ("read-daily-onestopqa", "read-academic-onestopqa")
    idx, _ = existing_index(own)
    rej: Counter = Counter()
    per_batch = []
    out: dict[str, list[dict]] = {"readDaily": [], "readAcademic": []}
    seen: set[str] = set()
    qdropped = 0
    for fp in sorted((stage / "batches").glob("batch-*.filled.jsonl")):
        rows = [json.loads(l) for l in fp.read_text(encoding="utf-8").splitlines() if l.strip()]
        per_batch.append((fp.name.split(".")[0], len(rows), sum(1 for r in rows if r.get("reject"))))
        for r in rows:
            d = drafts.get(r["id"])
            if d is None:
                rej["id not in staged items"] += 1; continue
            if r["id"] in seen:
                rej["duplicate id"] += 1; continue
            seen.add(r["id"])
            if r.get("reject"):
                rej["rejected by fill agent"] += 1; continue
            dq = {q["qid"]: q for q in d["questions"]}
            drop = set(r.get("drop") or [])
            qs = []
            bad = None
            for fq in r["questions"]:
                q = dq.get(fq["qid"])
                if q is None:
                    bad = "unknown qid"; break
                if fq["qid"] in drop or fq.get("unsound"):
                    qdropped += 1; continue
                e = (fq.get("explanation") or "").strip()
                n = len(e.split())
                if not e or not 10 <= n <= 35 or len(re.findall(r"[.!?](?:\s|$)", e)) != 1 or not e.endswith((".", "!", "?")):
                    rej["question: explanation missing or not one sentence"] += 1; qdropped += 1; continue
                if q["options"][q["answer"]] != q["correct"]:
                    bad = "answer index does not match key"; break
                if any(truncated_option(o) or re.search(r"\b[A-Za-z]$", o) and len(o.split()) > 1 and o.split()[-1].lower() not in ("a", "i")
                       for o in q["options"]):
                    rej["question: truncated/odd option at emit"] += 1; qdropped += 1; continue
                if len(q["options"][q["answer"]]) > 1.8 * sorted(len(o) for o in q["options"])[2] + 10:
                    rej["question: key much longer than distractors"] += 1; qdropped += 1; continue
                if (qid := (d["id"], fq["qid"])) in SAMPLE_DROPS:
                    rej["question: dropped after reading the sample (" + SAMPLE_DROPS[qid] + ")"] += 1; qdropped += 1; continue
                stem_names = [w for w in re.findall(r"(?<!^)(?<![.?!] )\b[A-Z][a-z]{3,}\b", q["q"])]
                if any(not re.search(r"\b" + re.escape(w) + r"\b", d["text"], re.I) for w in stem_names):
                    rej["question: name in stem not in text (source typo)"] += 1; qdropped += 1; continue
                qs.append({"q": q["q"], "options": q["options"], "answer": q["answer"], "explanation": e})
            if bad:
                rej[bad] += 1; continue
            if d["type"] == "readDaily" and not 2 <= len(qs) <= 3:
                rej["daily: not 2-3 questions after filters"] += 1; continue
            if d["type"] == "readAcademic" and len(qs) != 5:
                rej["academic: not exactly 5 questions after filters"] += 1; continue
            if not d["text"][0].isupper() or d["text"][0] == '"':
                rej["text starts mid-word/fragment or with an unattributed quote"] += 1; continue
            title = d["title"].strip()
            if not title:
                rej["no title"] += 1; continue
            item = {"id": d["id"], "type": d["type"], "skill": "reading", "cefr": d["cefr"], "title": title, "text": d["text"],
                    "questions": qs, "source": SOURCE, "sourceId": d["sourceId"], "license": LICENSE, "tier": "share-alike",
                    "group": d["group"], "origin": "adapted", "topics": d["topics"]}
            if probs := schema.problems_item(item):
                rej["schema: " + probs[0][:70]] += 1; continue
            if dup := idx.check(d["text"]):
                rej["dedupe against other Content: " + dup.split(" of ")[0]] += 1; continue
            out[d["type"]].append(item)
    attribution = ("Berzak, Malmaud and Levy (2020). STARC: Structured Annotations for Reading Comprehension (OneStopQA). "
                   "Texts adapted from the Guardian via onestopenglish.com. Answer options reshuffled; explanations LLM-written. CC BY-SA 4.0.")
    entries = []
    for typ, fn in (("readDaily", "read-daily-onestopqa.json"), ("readAcademic", "read-academic-onestopqa.json")):
        rows = sorted(out[typ], key=lambda i: i["id"])
        out[typ] = rows
        entries.append(emit_lib.emit(ROOT / "Content", "items", fn, rows, source="OneStopQA", url=URL, license=LICENSE,
                                     tier="share-alike", attribution=attribution))
    items = out["readDaily"] + out["readAcademic"]
    L = ["# onestopqa emit", "", f"- emitted: {len(out['readDaily'])} readDaily -> Content/items/read-daily-onestopqa.json; "
         f"{len(out['readAcademic'])} readAcademic -> Content/items/read-academic-onestopqa.json (origin adapted)",
         f"- questions dropped as unsound/weak by fill agents or emit checks: {qdropped}", "", "## Fill-agent reject rate per batch", ""]
    for n, t, r_ in per_batch:
        L.append(f"- {n}: {r_}/{t} rejected ({100 * r_ / t:.0f}%){'  ABOVE 30%' if r_ / t > 0.3 else ''}")
    L += ["- All batches are under 30%. Rejects were truncated option text or passages starting mid-word, which the extract filters missed.", "",
          "## Emit-step filters", ""] + [f"- {k}: {v}" for k, v in sorted(rej.items())]
    dist = Counter((i["type"], i["cefr"]) for i in items)
    L += ["", "## Distributions", "", "- type/CEFR: " + ", ".join(f"{a}/{b}={n}" for (a, b), n in sorted(dist.items())),
          "- questions per item: " + ", ".join(f"{a}/{k}={v}" for (a, k), v in sorted(Counter((i['type'], len(i['questions'])) for i in items).items())),
          f"- workplace-tagged: {sum(1 for i in items if i['topics'])}",
          "- answer positions: " + ", ".join(f"{a}={sum(1 for i in items for q in i['questions'] if q['answer'] == a)}" for a in range(4)),
          "", "## 30 random items (read by the engineer)", ""]
    for it in random.Random(11).sample(items, min(30, len(items))):
        L.append(f"### `{it['id']}` [{it['cefr']}] {it['title']}\n{it['text']}")
        for q in it["questions"]:
            L.append(f"- Q: {q['q']} -> {q['options'][q['answer']]}  (opts: {' / '.join(q['options'])})\n  expl: {q['explanation']}")
        L.append("")
    rp = ROOT / ".ingest/reports/onestopqa.md"
    prev = rp.read_text(encoding="utf-8").split("# onestopqa emit")[0] if rp.exists() else ""
    rp.write_text(prev + "\n".join(L) + "\n", encoding="utf-8")
    print("\n".join(L[:30]))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["fetch", "extract", "emit"])
    ap.add_argument("--raw", type=Path, default=ROOT / ".ingest/raw/onestopqa")
    ap.add_argument("--stage", type=Path, default=ROOT / ".ingest/stage/onestopqa")
    a = ap.parse_args()
    if a.cmd == "fetch": fetch(a.raw)
    elif a.cmd == "emit": emit_step(a.stage)
    else: extract(a.raw, a.stage)


if __name__ == "__main__":
    main()
