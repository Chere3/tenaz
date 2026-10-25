"""C03 cosmosqa: HF allenai/cosmos_qa (CC BY 4.0) -> readDaily items (STAGE ONLY: fetch + extract + fill batches).

  fetch   -> .ingest/raw/cosmosqa/{train,validation}.parquet + meta.json (license check; aborts if not CC BY 4.0)
             (refs/convert/parquet branch; test split skipped: labels are hidden)
  extract -> .ingest/stage/cosmosqa/contexts.jsonl        all accepted contexts (ranked, capped)
             .ingest/stage/cosmosqa/batches/batch_NNN.jsonl   rows for the LLM fill agents (40-60 rows each)
             .ingest/reports/cosmosqa.md
Run: uv run --project scripts/ingest python -I scripts/ingest/sources/cosmosqa.py extract
"""
from __future__ import annotations

import argparse
import json
import random
import re
import sys
import urllib.request
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib import cefr, dedupe, ids, schema, textnorm, workplace  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
URL = "https://huggingface.co/datasets/allenai/cosmos_qa"
LICENSE = "CC BY 4.0"
API = "https://huggingface.co/api/datasets/allenai/cosmos_qa"
PQ = "https://huggingface.co/datasets/allenai/cosmos_qa/resolve/refs%2Fconvert%2Fparquet/default/{s}/0000.parquet"
SPLITS = ("train", "validation")
TARGET = 600
MIN_W, MAX_W = 40, 150

NONE_OF = re.compile(r"none of the above|no answer|not enough information|cannot be determined|can't be determined", re.I)
# childish / sensitive / not-for-daily-practice vocabulary (contexts containing any of these are dropped)
BLOCK = re.compile(
    r"\b(kill\w*|murder\w*|rape\w*|sex\w*|suicid\w*|bomb\w*|massacre\w*|terror\w*|nude|naked|porn\w*|corpse\w*|dead|deaths?|"
    r"died|dies|dying|funeral\w*|cancer|chemo\w*|attack\w*|shoot\w*|gun\w*|weapons?|hostages?|prostitut\w*|alcohol\w*|drunk\w*|"
    r"beer|vodka|wine|booze|gambl\w*|casinos?|drugs?|cocaine|heroin|weed|marijuana|abus\w*|slave\w*|torture\w*|riot\w*|injur\w*|"
    r"wounded|stabb\w*|victims?|hell|damn\w*|shit\w*|fuck\w*|bitch\w*|ass|crap|pissed|sucks?|hate[sd]?|wtf|lmao|lol|"
    r"god|jesus|church|pray\w*|bible|muslim\w*|islam\w*|jewish|christian\w*|atheis\w*|trump|obama|democrat\w*|republican\w*|"
    r"election\w*|politic\w*|abortion|gay|lesbian|transgender|racis\w*|"
    r"kids?|child\w*|babies|baby|toddler\w*|infant\w*|newborn|pregnan\w*|diapers?|daycare|preschool\w*|kindergarten\w*|"
    r"nursery|homework|recess|teacher\w*|classmates?|mommy|daddy|mama|papa|santa|puppy|kitten|boyfriend|girlfriend|"
    r"dating|crush|honeymoon|kiss\w*|cheat\w*|breakup|broke up|stalk\w*|evil|daughters?|sons?|grandkids?|divorc\w*|widow\w*|hospital\w*|surgery|depress\w*|anxiety|therap\w*|suicide|"
    r"boobs?|breasts?|poop\w*|fart\w*|vomit\w*|diarrh\w*|menstrua\w*)\b", re.I)
EMOTICON = re.compile(r"(:\)|:\(|:D|;\)|:P|<3|\bxD\b|\^_\^|!{2,}|\?{2,}|\.{4,}|[A-Z]{5,}\b)")
TOKEN_ART = re.compile(r"\s'\s|\w\s-\s\w|\s[,.;:!?]|\s'(s|t|re|ve|ll|d|m)\b|``|''|\u00a0")
# the source is PTB-tokenized; detokenize() undoes that mechanically (grammar and spelling are left untouched)
INFORMAL = re.compile(r"(?<![\w'])(i|im|dont|cant|didnt|wont|isnt|wasnt|ive|ill|thats|youre|gonna|wanna|gotta|u|ur|b4|ppl|pics?|bday)(?![\w'])")
URLISH = re.compile(r"\(\d{3}\)|:\s-\s|https?:|www\.|\.com\b|@\w+|#\w+")


def fetch(raw: Path) -> None:
    with urllib.request.urlopen(API, timeout=60) as r:
        meta = json.load(r)
    lic = (meta.get("cardData") or {}).get("license")
    if lic not in ("cc-by-4.0", ["cc-by-4.0"]) or "license:cc-by-4.0" not in meta.get("tags", []):
        sys.exit(f"STOP: license at source is {lic!r}, expected cc-by-4.0")
    raw.mkdir(parents=True, exist_ok=True)
    (raw / "meta.json").write_text(json.dumps({"license": lic, "sha": meta.get("sha"), "lastModified": meta.get("lastModified")}), encoding="utf-8")
    for s in SPLITS:
        with urllib.request.urlopen(PQ.format(s=s), timeout=300) as r:
            (raw / f"{s}.parquet").write_bytes(r.read())
    print("license ok:", lic, "| files:", sorted(p.name for p in raw.iterdir()))


def load_rows(raw: Path):
    import pyarrow.parquet as pq  # parsing as data only
    for s in SPLITS:
        t = pq.read_table(raw / f"{s}.parquet").to_pylist()
        for i, r in enumerate(t):
            r["_split"] = s
            r["_i"] = i
            yield r


def norm(s: str) -> str:
    s = textnorm.detokenize(s or "")
    s = re.sub(r"(?<=\w) ' (?=(m|s|t|re|ve|ll|d)\b)", "'", s)  # "I ' m" -> "I'm"
    s = re.sub(r"(?<=\d) - (?=\d)", "-", s)  # "6 - 3" -> "6-3"
    return s


def typo_rate(text: str) -> float:
    from wordfreq import zipf_frequency
    toks = re.findall(r"[A-Za-z']+", text)
    bad = 0
    for t in toks:
        if len(t) < 3 or t[0].isupper() or "'" in t:
            continue
        if zipf_frequency(t.lower(), "en") == 0:
            bad += 1
    return bad / max(1, len(toks)) * 100


def context_problem(ctx: str) -> str | None:
    n = textnorm.word_count(ctx)
    if n < MIN_W or n > MAX_W:
        return "context not 40-150 words"
    if BLOCK.search(ctx):
        return "childish/sensitive vocabulary"
    if URLISH.search(ctx) or EMOTICON.search(ctx):
        return "emoticons/shouting/urls/odd punctuation"
    if TOKEN_ART.search(ctx):
        return "tokenization artifacts"
    if ctx.count('"') % 2:
        return "unbalanced quotes"
    if INFORMAL.search(ctx):
        return "lowercase i / missing apostrophes / texting slang"
    if re.search(r"[.!?]\s+[a-z]", ctx) or ctx[0].islower():
        return "lowercase sentence start"
    if typo_rate(ctx) > 1.5:
        return ">1.5 misspellings per 100 words"
    sents = textnorm.split_sentences(ctx)
    if sents and not re.search(r"[.!?\"')]$", ctx.strip()):
        return "does not end in sentence punctuation"
    return None


def question_problem(q: dict) -> str | None:
    opts = q["options"]
    if any(NONE_OF.search(o) for o in opts):
        return "none-of-the-above option"
    if TOKEN_ART.search(q["q"] + " | " + " | ".join(opts)) or typo_rate(q["q"] + " " + " ".join(opts)) > 0:
        return "tokenization artifact or misspelling in question/options"
    if len({o.lower() for o in opts}) < 4:
        return "duplicate options"
    if q["q"][:1].islower() or any(o[:1].islower() or o[:1].isdigit() for o in opts):
        return "lowercase/odd start of question or option"
    if not q["q"].endswith("?"):
        return "question without ?"
    if BLOCK.search(q["q"] + " " + " ".join(opts)):
        return "childish/sensitive vocabulary in question/options"
    if any(len(o.split()) > 25 or len(o.split()) < 1 for o in opts):
        return "option length"
    if any(o[-1:] not in ".!?\"'" and len(o.split()) > 8 for o in opts):
        return "long option without final punctuation"
    return None


def extract(raw: Path, stage: Path, report: Path) -> None:
    if json.loads((raw / "meta.json").read_text())["license"] not in ("cc-by-4.0", ["cc-by-4.0"]):
        sys.exit("STOP: license mismatch")
    stage.mkdir(parents=True, exist_ok=True)
    (stage / "batches").mkdir(exist_ok=True)
    for old in (stage / "batches").glob("*.jsonl"):
        old.unlink()
    report.parent.mkdir(parents=True, exist_ok=True)
    rej: dict[str, int] = defaultdict(int)
    by_ctx: dict[str, dict] = {}
    total = 0
    for r in load_rows(raw):
        total += 1
        if r.get("label") not in (0, 1, 2, 3):
            rej["label hidden/invalid"] += 1
            continue
        ctx = norm(r["context"])
        opts = [norm(r[f"answer{i}"]) for i in range(4)]
        q = {"q": norm(r["question"]), "options": opts, "answer": int(r["label"]),
             "sourceId": f"{r['_split']}-{ids.sha8(r['id'])}"}
        why = question_problem(q)
        if why:
            rej["question: " + why] += 1
            continue
        d = by_ctx.setdefault(ctx, {"context": ctx, "questions": []})
        if all(x["q"].lower() != q["q"].lower() for x in d["questions"]):
            d["questions"].append(q)
    rej["rows read"] = total
    rej["distinct contexts with >=1 usable question"] = len(by_ctx)

    # context-level filters, then dedupe vs Content/ and within the set
    (ROOT / "Content/items/read-daily-cosmos.json").exists()  # (not emitted yet; any existing file would count as Content)
    idx = dedupe.DedupeIndex.from_content(ROOT / "Content")
    cands = []
    for ctx, d in sorted(by_ctx.items()):
        why = context_problem(ctx)
        if why:
            rej["context: " + why] += 1
            continue
        key = ids.sha8(textnorm.normalize_for_hash(ctx))
        wp = workplace.score(ctx)
        lvl = cefr.estimate(ctx)
        cands.append({"key": key, "context": ctx, "questions": d["questions"][:3], "wp": round(wp, 3), "cefr": lvl})
    cands.sort(key=lambda c: (-c["wp"], c["key"]))
    chosen = []
    for c in cands:
        if len(chosen) >= TARGET:
            rej["capped (ranked by workplace score, then hash)"] += 1
            continue
        dup = idx.check(c["context"])
        if dup:
            rej["dedupe: " + dup.split(" of ")[0]] += 1
            continue
        first = c["questions"][0]["sourceId"]
        c["id"] = ids.item_id("readDaily", "cosmos", first)
        item = {"id": c["id"], "type": "readDaily", "cefr": c["cefr"], "title": "Placeholder title", "text": c["context"],
                "questions": [{"q": q["q"], "options": q["options"], "answer": q["answer"], "explanation": "Placeholder."}
                              for q in c["questions"]] * (1 if len(c["questions"]) > 1 else 2)}
        if schema.problems_item(item):
            rej["schema/hygiene: " + schema.problems_item(item)[0][:60]] += 1
            continue
        idx.add(c["id"], c["context"])
        c["topics"] = ["workplace"] if c["wp"] >= 0.1 else []
        chosen.append(c)
    with (stage / "contexts.jsonl").open("w", encoding="utf-8") as f:
        for c in chosen:
            f.write(json.dumps(c, ensure_ascii=False) + "\n")

    rows = []
    for c in chosen:
        qs = c["questions"]
        rows.append({
            "id": c["id"], "group": f"cosmos:ctx:{c['key']}", "cefr": c["cefr"], "topics": c["topics"],
            "text": c["context"], "needExtraQuestion": len(qs) == 1,
            "questions": [{"sourceId": q["sourceId"], "q": q["q"], "options": q["options"], "answer": q["answer"]} for q in qs],
        })
    rows.sort(key=lambda r: (not r["needExtraQuestion"], r["id"]))
    n = len(rows)
    nb = max(1, round(n / 50))
    size, extra = divmod(n, nb)
    pos = 0
    paths = []
    for b in range(nb):
        k = size + (1 if b < extra else 0)
        p = stage / "batches" / f"batch_{b + 1:03d}.jsonl"
        with p.open("w", encoding="utf-8") as f:
            for r in rows[pos:pos + k]:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
        pos += k
        paths.append(p)

    dist: dict[str, int] = defaultdict(int)
    for c in chosen:
        dist[c["cefr"]] += 1
    one = sum(1 for r in rows if r["needExtraQuestion"])
    lines = ["# cosmosqa extract", "", f"- accepted texts: {n} (1 question: {one}; 2-3 questions: {n - one}); batches: {nb}",
             "- CEFR (weak lexical estimate): " + ", ".join(f"{k}={v}" for k, v in sorted(dist.items())),
             f"- workplace-tagged: {sum(1 for c in chosen if c['topics'])}", "", "## Counts and reject reasons", ""]
    lines += [f"- {k}: {v}" for k, v in rej.items()]
    lines += ["", "## 30 random accepted texts", ""]
    for c in random.Random(7).sample(chosen, min(30, n)):
        lines.append(f"- `{c['id']}` [{c['cefr']}, wp={c['wp']}] {c['context']}  \n  Q: {c['questions'][0]['q']} -> {c['questions'][0]['options'][c['questions'][0]['answer']]}")
    report.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines[:20]))
    print("\n".join(str(p) for p in paths))


# emit-time re-filter, added after reading the sample: crude/slangy text and ungrammatical source questions/options
EMIT_TEXT_BLOCK = re.compile(r"\b(sucked|screwed|naughty|debauchery|bloody|hells?|peeved|groupies|kick\w*|gouge|fleece|crappy|stupid|idiot\w*|"
                             r"horrible|suck|freaking|friggin\w*|butt|sexy|hot tub|wasted|hung over|hangover|blog(?:ging)? about my)\b", re.I)
EMIT_Q_BAD = re.compile(r"\b(Their|Your) (looking|going|is|are|was|were|trying)\b|\bhurted\b|\bi\b(?! ?\.)|\ban [^aeiouAEIOU\W]|\bout of that\b|"
                        r"\b(writed|taked|goed|buyed|maked)\b|\bhappened\?? *$|\bwhat happened to my\b|\bdoes? .{0,20} (said|went|came)\b|"
                        r"\bwhy did what\b|\bbecause of he\b|\bhave (took|went|ate)\b|\bmay i\b|\btheir (not|going|being)\b|\bless (cars|buses|bicycles|motorcycles|people|items)\b|"
                        r"\bbmws?\b|\bsnowfall lined\b|\bbad man\b|\bwhy may be\b|\bpail\b|\bthe reason \"|\bwhat is the reason\b.*\"", re.I)


def options_differ_by_one_word(opts: list[str]) -> bool:
    toks = [set(re.findall(r"[\w']+", o.lower())) for o in opts]
    close = sum(1 for i in range(4) for j in range(i + 1, 4) if len(toks[i] ^ toks[j]) <= 2)
    return close >= 3


def emit_step(stage: Path, report: Path) -> None:
    """Read *.filled.jsonl, drop rejects, re-check, build readDaily items, write Content/items/read-daily-cosmos.json."""
    from lib import emit as emit_lib
    rej: dict[str, int] = defaultdict(int)
    per_batch = []
    items, seen_ids = [], set()
    own = ROOT / "Content/items/read-daily-cosmos.json"
    idx = dedupe.DedupeIndex()
    for ex in sorted((ROOT / "Content/items").glob("*.json")):
        if ex.resolve() == own.resolve():
            continue
        for it in json.loads(ex.read_text(encoding="utf-8")):
            t = dedupe.item_text(it)
            if t:
                idx.add(it["id"], t)
    for fp in sorted((stage / "batches").glob("batch_*.filled.jsonl")):
        rows = [json.loads(l) for l in fp.read_text(encoding="utf-8").splitlines() if l.strip()]
        nrej = sum(1 for r in rows if r.get("reject"))
        per_batch.append((fp.name.split(".")[0], len(rows), nrej))
        for r in rows:
            if r.get("reject"):
                rej["rejected by fill agent"] += 1
                continue
            qs = [dict(q) for q in r["questions"]]
            expl = r.get("explanations") or []
            if len(expl) != len(qs) or not all(isinstance(e, str) and e.strip() for e in expl):
                rej["missing explanation"] += 1
                continue
            for q, e in zip(qs, expl):
                q.pop("sourceId", None)
                q["explanation"] = e.strip()
            ex = r.get("extraQuestion")
            if ex:
                o = ex["options"]
                if len({x.lower() for x in o}) < 4 or not (0 <= ex["answer"] < 4):
                    rej["bad extra question options"] += 1
                    continue
                if len(o[ex["answer"]]) > 1.5 * sorted(len(x) for x in o)[2]:
                    rej["extra question: key much longer than distractors"] += 1
                    continue
                if not str(ex.get("explanation", "")).strip():
                    rej["extra question without explanation"] += 1
                    continue
                if question_problem({"q": ex["q"], "options": o}):
                    rej["extra question fails hygiene"] += 1
                    continue
                qs.append({"q": ex["q"].strip(), "options": o, "answer": ex["answer"], "explanation": ex["explanation"].strip()})
            if len(qs) < 2 or len(qs) > 3:
                rej["question count not 2-3"] += 1
                continue
            if EMIT_TEXT_BLOCK.search(r["text"]):
                rej["emit: crude/slangy/alcohol vocabulary in text"] += 1
                continue
            if any(EMIT_Q_BAD.search(q["q"] + " | " + " | ".join(q["options"])) for q in qs):
                rej["emit: ungrammatical source question/options"] += 1
                continue
            if any(options_differ_by_one_word(q["options"]) for q in qs):
                rej["emit: options differ by a single word (ambiguous key)"] += 1
                continue
            title = (r.get("title") or "").strip()
            if not title or len(title.split()) > 6:
                rej["bad title"] += 1
                continue
            first = r["questions"][0]["sourceId"]
            item = {"id": r["id"], "type": "readDaily", "skill": "reading", "cefr": r["cefr"], "title": title,
                    "text": r["text"], "questions": qs, "source": "cosmosqa", "sourceId": first, "license": LICENSE,
                    "tier": "permissive", "group": r["group"], "origin": "adapted", "topics": r.get("topics", [])}
            probs = schema.problems_item(item)
            if probs:
                rej["schema: " + probs[0][:70]] += 1
                continue
            if r["id"] in seen_ids:
                rej["duplicate id"] += 1
                continue
            dup = idx.check(r["text"])
            if dup:
                rej["dedupe: " + dup.split(" of ")[0]] += 1
                continue
            idx.add(r["id"], r["text"])
            seen_ids.add(r["id"])
            items.append(item)
    items.sort(key=lambda i: i["id"])
    entry = emit_lib.emit(ROOT / "Content", "items", "read-daily-cosmos.json", items, source="Cosmos QA", url=URL,
                          license=LICENSE, tier="permissive", attribution="Huang et al. 2019, allenai/cosmos_qa (CC BY 4.0); explanations and extra questions LLM-written")
    lines = ["# cosmosqa emit", "", f"- emitted: {len(items)} readDaily items -> Content/items/read-daily-cosmos.json (origin adapted)", "",
             "## Fill-agent reject rate per batch", ""]
    for n, t, r_ in per_batch:
        lines.append(f"- {n}: {r_}/{t} rejected ({100 * r_ / t:.0f}%){'  ABOVE 30%' if r_ / t > 0.3 else ''}")
    tot = sum(t for _, t, _ in per_batch)
    lines.append(f"- total: {sum(r_ for *_, r_ in per_batch)}/{tot} rejected. Every batch is above 30% by design: extract() is a loose pre-filter and the fill agents judged key support, ambiguity, sensitivity and fragments; fewer clean items were preferred over the 600 target.")
    lines += ["", "## Emit-step filters", ""] + [f"- {k}: {v}" for k, v in rej.items()]
    lc, cc = defaultdict(int), defaultdict(int)
    for it in items:
        lc[it["cefr"]] += 1
        cc[len(it["questions"])] += 1
    lines += ["", "## Distributions", "", "- CEFR: " + ", ".join(f"{k}={v}" for k, v in sorted(lc.items())),
              "- questions per text: " + ", ".join(f"{k}={v}" for k, v in sorted(cc.items())),
              f"- workplace-tagged: {sum(1 for i in items if i['topics'])}",
              "- answer positions: " + ", ".join(f"{a}={sum(1 for i in items for q in i['questions'] if q['answer'] == a)}" for a in range(4)),
              "", "## 30 random items (read by the engineer)", ""]
    for it in random.Random(11).sample(items, min(30, len(items))):
        lines.append(f"### `{it['id']}` [{it['cefr']}] {it['title']}\n{it['text']}")
        for q in it["questions"]:
            lines.append(f"- Q: {q['q']} -> {q['options'][q['answer']]}  (opts: {' / '.join(q['options'])})\n  expl: {q['explanation']}")
        lines.append("")
    prev = report.read_text(encoding="utf-8").split("# cosmosqa emit")[0] if report.exists() else ""
    report.write_text(prev + "\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps(entry)[:300]); print("\n".join(lines[:30]))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["fetch", "extract", "emit"])
    ap.add_argument("--raw", default=str(ROOT / ".ingest/raw/cosmosqa"))
    ap.add_argument("--stage", default=str(ROOT / ".ingest/stage/cosmosqa"))
    ap.add_argument("--report", default=str(ROOT / ".ingest/reports/cosmosqa.md"))
    a = ap.parse_args()
    if a.cmd == "fetch":
        fetch(Path(a.raw))
    elif a.cmd == "emit":
        emit_step(Path(a.stage), Path(a.report))
    else:
        extract(Path(a.raw), Path(a.stage), Path(a.report))


if __name__ == "__main__":
    main()
