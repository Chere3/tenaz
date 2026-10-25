"""C14: databricks-dolly-15k (CC BY-SA 3.0), category summarization -> lifeParagraph kind "summary".

  fetch   -> .ingest/raw/dolly/databricks-dolly-15k.jsonl   (network)
  extract -> .ingest/stage/dolly/rows.jsonl + .ingest/reports/dolly.md (data only)
  emit    -> Content/items/life-summary-dolly.json

Run: uv run --project scripts/ingest python -I scripts/ingest/sources/dolly.py <cmd>
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

from wordfreq import zipf_frequency
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib import cefr, dedupe, emit as emitlib, ids, schema, textnorm, workplace  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
URL = "https://huggingface.co/datasets/databricks/databricks-dolly-15k/resolve/main/databricks-dolly-15k.jsonl"
CARD = "https://huggingface.co/datasets/databricks/databricks-dolly-15k"
FILENAME = "life-summary-dolly.json"
PROMPT = "Summarise this in 2-3 sentences."
TARGET = 200
MUST_POOL = ["the main point", "according to", "in short", "focuses on", "as a result", "in other words",
             "this shows that", "overall"]

# Adult / sensitive / childish / trivia topics we do not want in a learner's daily bank.
BAD = re.compile(r"\b(sex|sexual|rape|rapist|porn|nude|naked|murder|murdered|kill|killed|killing|suicide|genocide|"
                 r"massacre|terror\w*|nazi\w*|holocaust|slave\w*|racis\w*|drug|drugs|cocaine|heroin|abuse\w*|"
                 r"torture\w*|shot dead|stabbed|bomb\w*|gun|guns|weapon\w*|war|wars|battle|invasion|"
                 r"cartoon\w*|pok[eé]mon|kids?|children's|toddler\w*|nursery|fairy|disney|"
                 r"god|jesus|church|islam\w*|christian\w*|hindu\w*|muslim\w*|bible|prayer|"
                 r"trump|biden|obama|election\w*|republican\w*|democrat\w*|"
                 r"temple|prophet|biblical|knockout|fighters?|martial|mixed martial|cannabis|marijuana|alcohol\w*|beer|vodka|wine|erotic|prostitut\w*|casino|gambl\w*)\b", re.I)
LIST_START = re.compile(r"^\s*(\d+[.)]|[-*•])\s")
CITE = re.compile(r"\[\d+\]|\[citation|\[edit\]|\(\s*[;,]?\s*\)|\bpronounced\b|\bIPA\b|/[^/\s]+/")
WIKI_NOISE = re.compile(r"\b(born|died|née|is an? (american|british|english|indian|german|french)\b.*\b(actor|actress|singer|footballer|politician|rapper|musician)|"
                        r"discography|episode|season \d|cricketer|footballer|midfielder|"
                        r"township|village|municipality|county|census|constituency|species|genus|family \w+idae)\b", re.I)

# Manual review of the first pass: crowd-written references with typos / ungrammatical text / not a real summary.
MANUAL_REJECT = ['7d150823eb9d', '9ef69ff6dd3b', '6d623e6a17ab', '601d32cf7527', '1e96c6920934', '019eb5085f54', '7a05f4a3ff0d', '7d08666f2fc2', '904fab7e7ae7', '97dd838dc2c5', 'db1209359306', 'e7baa6eb1854', 'fdb8f213b90c']


def fetch(raw: Path) -> None:
    raw.mkdir(parents=True, exist_ok=True)
    dest = raw / "databricks-dolly-15k.jsonl"
    with urllib.request.urlopen(URL) as r, dest.open("wb") as f:
        f.write(r.read())
    print("wrote", dest)


def sents(s: str) -> list[str]:
    return [x for x in re.split(r"(?<=[.!?])\s+(?=[A-Z\"'])", s.strip()) if x]


def ngrams(s: str, n: int = 4) -> set:
    t = textnorm.normalize_for_hash(s).split()
    return {" ".join(t[i:i + n]) for i in range(len(t) - n + 1)}


def reject_reason(r: dict) -> str | None:
    if hashlib.sha256(r["context"].encode()).hexdigest()[:12] in MANUAL_REJECT:
        return "manual review: flawed reference"
    ctx_raw, resp_raw = r["context"], r["response"]
    if "\n" in resp_raw.strip() or LIST_START.match(resp_raw):
        return "response is a list / multi-paragraph"
    ctx = textnorm.fix_unicode(re.sub(r"\s+", " ", ctx_raw)).strip()
    resp = textnorm.fix_unicode(re.sub(r"\s+", " ", resp_raw)).strip()
    n = textnorm.word_count(ctx)
    if not 80 <= n <= 180:
        return "context not 80-180 words"
    rn = textnorm.word_count(resp)
    if not 20 <= rn <= 80:
        return "response not 20-80 words"
    if not 2 <= len(sents(resp)) <= 4:
        return "response not 2-4 sentences"
    for s in (ctx, resp):
        if any(ord(c) > 0x24F for c in s):
            return "non-ASCII after normalisation"
        if CITE.search(s) or re.search(r"https?://|www\.|<|>|\{|\}|_{2,}", s):
            return "citation / pronunciation / markup noise"
        if BAD.search(s):
            return "sensitive or off-profile topic"
    if len(re.findall(r"\d", ctx)) / len(ctx) > 0.05:
        return "too many digits"
    if WIKI_NOISE.search(ctx):
        return "biography / media / place trivia"
    if re.search(r"\([^)]{0,80}\)", ctx) and len(re.findall(r"\(", ctx)) > 2:
        return "heavy parentheticals"
    caps = [w for w in re.findall(r"(?<![.!?] )(?<!^)\b[A-Z][a-z]+", ctx)]
    if len(caps) / n > 0.18:
        return "proper-noun heavy"
    if not resp[0].isupper() or resp[-1] not in ".!?":
        return "response not a clean sentence"
    if ngrams(resp) and len(ngrams(resp) & ngrams(ctx)) / len(ngrams(resp)) > 0.75:
        return "response mostly copies the text"
    if re.search(r"[a-z][.!?][A-Z]|\b[A-Z][A-Z][a-z]|\s=\s|\s\+\s|\bthis (paragraph|passage|text)\b|\bbased on\b", resp):
        return "response typo / not a clean summary"
    ctx_words = set(re.findall(r"[a-z']+", ctx.lower()))
    typos = [w for w in re.findall(r"[A-Za-z']+", resp)
             if w.lower() not in ctx_words and zipf_frequency(w.lower(), "en") < 1.5 and not w[0].isupper()]
    if typos:
        return "response has probable typos"
    if re.search(r"\b(\w+) \1\b", resp, re.I):
        return "response repeated word"
    if r["instruction"].strip().lower().startswith(("write a poem", "translate")):
        return "instruction not a summary"
    return None


def extract(raw: Path, stage: Path, report: Path) -> None:
    rows = [json.loads(l) for l in (raw / "databricks-dolly-15k.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()]
    summ = [r for r in rows if r["category"] == "summarization"]
    reasons: Counter = Counter()
    keep = []
    for r in summ:
        why = reject_reason(r)
        if why:
            reasons[why] += 1
            continue
        ctx = textnorm.fix_unicode(re.sub(r"\s+", " ", r["context"])).strip()
        resp = textnorm.fix_unicode(re.sub(r"\s+", " ", r["response"])).strip()
        wp = workplace.score(ctx)
        lvl = cefr.estimate(ctx)
        sid = hashlib.sha256(r["context"].encode()).hexdigest()[:12]
        # rank: workplace relevance boost, B2-ish level preferred, sentence-length sanity
        fit = {"B1": 0.3, "B1+": 0.6, "B2": 1.0, "B2+": 1.0, "C1": 0.6}[lvl]
        keep.append({"sourceId": sid, "text": ctx, "reference": resp, "cefr": lvl,
                     "workplace": round(wp, 3), "rank": round(wp * 2 + fit, 3)})
    keep.sort(key=lambda x: (-x["rank"], x["sourceId"]))
    stage.mkdir(parents=True, exist_ok=True)
    (stage / "rows.jsonl").write_text("\n".join(json.dumps(k) for k in keep) + "\n", encoding="utf-8")
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text("# dolly extract\n\nsummarization rows: %d\npassed filters: %d\n\n## Reject reasons\n%s\n"
                      % (len(summ), len(keep), "\n".join(f"- {k}: {v}" for k, v in reasons.most_common())),
                      encoding="utf-8")
    print(len(summ), "->", len(keep))


def emit(stage: Path, report: Path) -> None:
    content = ROOT / "Content"
    cand = [json.loads(l) for l in (stage / "rows.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()]
    (content / "items" / FILENAME).unlink(missing_ok=True)  # do not dedupe against our own previous output
    idx = dedupe.DedupeIndex.from_content(content)
    out, rej = [], Counter()
    for c in cand:
        if len(out) >= TARGET:
            break
        iid = ids.item_id("lifeParagraph", "dolly", c["sourceId"])
        rn = textnorm.word_count(c["reference"])
        item = {
            "id": iid, "type": "lifeParagraph", "cefr": c["cefr"], "skill": "writing",
            "prompt": PROMPT, "text": c["text"], "reference": [c["reference"]],
            "mustUse": random.Random(c["sourceId"]).sample(MUST_POOL, 2),
            "minWords": 40 if rn <= 55 else 50,
            "kind": "summary", "source": "dolly", "sourceId": c["sourceId"],
            "license": "CC BY-SA 3.0", "tier": "share-alike", "origin": "verbatim",
            "topics": ["workplace"] if c["workplace"] >= 0.15 else ["general"],
        }
        probs = schema.problems_item(item)
        if probs:
            rej["schema: " + probs[0][:50]] += 1
            continue
        why = idx.check_and_add(iid, c["text"])
        if why:
            rej["dedupe"] += 1
            continue
        out.append(item)
    entry = emitlib.emit(content, "items", FILENAME, out, source="databricks-dolly-15k", url=CARD,
                         license="CC BY-SA 3.0", tier="share-alike",
                         attribution="Conover et al. 2023, Databricks, databricks/databricks-dolly-15k "
                                     "(contexts from Wikipedia, also CC BY-SA 3.0)")
    lv = Counter(i["cefr"] for i in out)
    tp = Counter(i["topics"][0] for i in out)
    lines = ["\n## Emit\n", f"emitted: {len(out)} (candidates {len(cand)}, target {TARGET})",
             f"reject: {dict(rej)}", f"levels: {dict(lv)}", f"topics: {dict(tp)}", f"licenses entry: {entry}",
             "\n## 30 random emitted items\n"]
    for i in random.Random(7).sample(out, min(30, len(out))):
        lines.append(f"### {i['id']} [{i['cefr']}, minWords {i['minWords']}, {i['topics'][0]}]\n\n"
                     f"TEXT: {i['text']}\n\nREFERENCE: {i['reference']}\n")
    base = report.read_text(encoding="utf-8").split("\n## Emit")[0]
    report.write_text(base + "\n".join(lines), encoding="utf-8")
    print(len(out), dict(rej), dict(lv))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["fetch", "extract", "emit"])
    ap.add_argument("--raw", default=str(ROOT / ".ingest/raw/dolly"))
    ap.add_argument("--stage", default=str(ROOT / ".ingest/stage/dolly"))
    ap.add_argument("--report", default=str(ROOT / ".ingest/reports/dolly.md"))
    a = ap.parse_args()
    if a.cmd == "fetch":
        fetch(Path(a.raw))
    elif a.cmd == "extract":
        extract(Path(a.raw), Path(a.stage), Path(a.report))
    else:
        emit(Path(a.stage), Path(a.report))


if __name__ == "__main__":
    main()
