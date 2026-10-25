"""P4 RACE-high (HF ehovy/race, config high, train shard; NON-COMMERCIAL research license) -> readAcademic + readDaily, STAGE ONLY.

  python -I scripts/ingest/sources/race.py fetch   --raw .ingest/raw/race
  python -I scripts/ingest/sources/race.py extract --raw .ingest/raw/race --stage .ingest/stage/race
  python -I scripts/ingest/sources/race.py emit    --stage .ingest/stage/race     (after the fill agents ran)

License (verified in the HF card README, which quotes the CMU RACE terms): "RACE dataset is available for non-commercial research
purpose only"; passages come from the Internet and are not CMU's property; no reproduction/redistribution for commercial use.
Tier `nc` (the schema's name for non-commercial), files `*.nc.json`. Personal study only, never redistribute.

Dataset facts: one row per question (example_id, article, question, options[4], answer 'A'-'D'); articles repeat across rows.
There are no titles and no explanations. Option order is kept as in the source (it often matters: "Both A and B", sequences).

extract writes
  .ingest/stage/race/items.jsonl             full drafts (key included)
  .ingest/stage/race/batches/*.jsonl         rows for the fill agents, WITHOUT the key (so the verification is blind)
  .ingest/reports/race.md
"""
from __future__ import annotations

import argparse
import json
import random
import re
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
SOURCE = "race"
URL = "https://huggingface.co/datasets/ehovy/race"
HF_API = "https://huggingface.co/api/datasets/ehovy/race"
README = "https://huggingface.co/datasets/ehovy/race/raw/main/README.md"
PARQUET = "https://huggingface.co/datasets/ehovy/race/resolve/main/high/train-00000-of-00001.parquet"
LICENSE = "Non-commercial research use only (CMU RACE terms; HF card license: other)"
TIER = "nc"
CAP = {"readAcademic": 300, "readDaily": 400}
ACAD_WORDS = (140, 230)
DAILY_WORDS = (40, 150)
OVERLAP_REJECT = 0.5

BAD = re.compile(r"\b(sex|sexual|sexy|rape[ds]?|porn\w*|murder\w*|kill(?:s|ed|ing|er|ers)?|suicid\w*|genocide|massacre\w*|"
                 r"terroris[mt]\w*|bomb(?:s|ing|ed)?|abus(?:e|ed|ive)|torture\w*|slaves?|slavery|naked|nude|drugs?|cocaine|"
                 r"heroin|cannabis|prostitut\w*|corpses?|shooting|gunman|hostages?|fairy|santa|toys?|cartoons?|nursery|"
                 r"bloody|damn|crap|shit|fuck\w*|bastard|hell|alcohol\w*|drunk\w*|gambl\w*|weapons?|riot\w*|casualt\w*|"
                 r"wounded|victims?|jesus|ghosts?|"
                 r"puppy|kitten|bunny|princess|prince|dwarfs?|witch|monsters?)\b", re.I)
# China-school moralising stories and school life
CHINA = re.compile(r"\b(China|Chinese|Beijing|Shanghai|Hong Kong|Taiwan|Guangzhou|Nanjing|Wuhan|Mr\.? (?:Li|Wang|Zhang|Liu|Chen|Zhao)|"
                   r"Li Ming|Wang Lei|Han Mei|Lin Tao|Junior High|Senior High|Middle School|classmates?|headmaster|"
                   r"homework|schoolmates?|schoolboy|schoolgirl|pupils?|kindergarten|orphan\w*|poor family)\b")
STEM_BAD = re.compile(r"(_|\bNOT\b|\bnot true\b|\bexcept\b|\bwhich of the following is wrong\b|\bfalse\b|\bunderlin|\bin the (?:first|second|third|"
                      r"last) paragraph\b|\bparagraph \d|\bAccording to the (?:picture|chart|table|map|ad|advertisement)\b|\bphoto\b|"
                      r"\bpicture\b|\bthe title\b|\b(?:A|B|C|D)\)|\bchart\b)", re.I)
OPT_BAD = re.compile(r"(all of the above|none of the above|\b(?:both|neither)\b.*\b[ABCD]\b|\b[ABCD]\s*(?:and|&|,)\s*[ABCD]\b|"
                     r"\bA\b.*\bB\b.*\bC\b|\bonly\s+[ABCD]\b|\bof the above\b|\ball (?:the )?(?:three|four|these)\b|"
                     r"\bboth (?:of )?(?:them|the above)\b)", re.I)
BAD_START = re.compile(r"^(But|And|So|Or|Yet|However|Also|Then|Thus|He|She|They|It|This|That|These|Those|His|Her|Their)\b")
# OCR / extraction noise: stray characters, doubled spaces before punctuation, spaced hyphens, mojibake
NOISE = re.compile(r"([a-z]{2}[.,;!?][A-Za-z]{2}|\?\?+|\.\.\.\.+|[ ​]|\bhttps?:|www\.|\s[,.;:!?](?=\s|$)|\(\s|\s\)|[A-Za-z]-\s[a-z]|[_~^|\\<>{}\[\]]|"
                   r"\b\w+\s{2,}\w+\b.*\b\w+\s{2,}\w+\b|\*|\bPicture\b|\bPhoto\b|\bFig\.|\bwww)")


def _get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "tenaz-ingest"})
    with urllib.request.urlopen(req, timeout=180) as r:
        return r.read()


def fetch(raw: Path) -> None:
    card = json.loads(_get(HF_API))
    lic = (card.get("cardData") or {}).get("license")
    readme = _get(README).decode("utf-8", "replace")
    if "non-commercial research purpose only" not in readme:
        sys.exit("RACE non-commercial wording not found in the HF card; stopping (re-verify the license by hand)")
    print(f"license: HF tag={lic!r}; card text confirms 'non-commercial research purpose only'")
    if raw.exists() and any(raw.iterdir()):
        print("raw dir not empty; leaving as is"); return
    raw.mkdir(parents=True, exist_ok=True)
    (raw / "train.parquet").write_bytes(_get(PARQUET))
    (raw / "LICENSE-CHECK").write_text(f"HF tag license: {lic}\ncard quote: RACE dataset is available for non-commercial research purpose only\n"
                                       f"checked: {date.today()}\n")


# ----------------------------------------------------------------------------- helpers

def norm(s: str) -> str:
    s = textnorm.fix_unicode(unicodedata.normalize("NFKC", s))
    s = re.sub(r"[ \t]+", " ", s)
    s = re.sub(r"\s*\n\s*", "\n\n", s.strip())
    s = re.sub(r" +([,.;:!?])", r"\1", s)
    return s.strip()


def norm_inline(s: str) -> str:
    return re.sub(r"\s+", " ", norm(s)).strip()


def shingles(text: str, n: int = 6) -> set[str]:
    toks = textnorm.normalize_for_hash(text).split()
    return {" ".join(toks[i:i + n]) for i in range(len(toks) - n + 1)}


def existing_index(own_prefixes: tuple[str, ...]):
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


def noisy(text: str) -> str | None:
    if m := NOISE.search(text):
        return f"noise {m.group(0)[:12]!r}"
    if text.count('"') % 2:
        return "unbalanced quotes"
    for t in re.findall(r"[A-Za-z']+", text):
        if "'" not in t and t.islower() and len(t) >= 3 and zipf(t, "en") < 1.5:
            return f"unknown token {t!r}"
    return None


def question_ok(q: str, opts: list[str]) -> str | None:
    if STEM_BAD.search(q): return "stem: blank/NOT/underlined/picture"
    if not q.endswith("?"): return "stem: not a question"
    if len({o.lower() for o in opts}) != 4: return "duplicate options"
    if any(OPT_BAD.search(o) for o in opts): return "options: all-of-the-above / letter reference"
    if any(not o or len(o.split()) > 22 for o in opts): return "options: empty or too long"
    if any(re.search(r"(?:^|\s)_+(?:\s|$)|\.\.\.$", o) for o in opts): return "options: blank"
    if BAD.search(q + " " + " ".join(opts)): return "sensitive word"
    if noisy(" ".join([q] + opts)): return "noise in question"
    return None


# ----------------------------------------------------------------------------- extract

def extract(raw: Path, stage: Path) -> None:
    import pyarrow.parquet as pq   # noqa: PLC0415
    stage.mkdir(parents=True, exist_ok=True)
    rows = pq.read_table(raw / "train.parquet").to_pylist()
    arts: dict[str, list[dict]] = defaultdict(list)
    order: list[str] = []
    for r in rows:
        if r["article"] not in arts:
            order.append(r["article"])
        arts[r["article"]].append(r)
    rej: Counter = Counter()
    index, grams = existing_index(("read-academic-race", "read-daily-race"))
    cands: list[dict] = []

    for art in order:
        text = norm(art)
        wc = textnorm.word_count(text)
        if DAILY_WORDS[0] <= wc <= ACAD_WORDS[1]:
            pass
        else:
            rej["article: length outside 40-230 words"] += 1; continue
        if CHINA.search(text): rej["article: China/school-life/moral-story keyword"] += 1; continue
        if BAD.search(text): rej["article: sensitive/childish word"] += 1; continue
        if BAD_START.match(text): rej["article: opens on a pronoun/connective"] += 1; continue
        if (n := noisy(text)): rej["article: OCR/format noise"] += 1; continue
        if textnorm.word_count(text.replace("\n\n", " ")) != wc: rej["article: wc mismatch"] += 1; continue
        qs = []
        for r in arts[art]:
            q = norm_inline(r["question"]); opts = [norm_inline(o) for o in r["options"]]
            if (why := question_ok(q, opts)):
                rej["question: " + why] += 1; continue
            if len(set(q.lower() for _, q in [(0, x["q"]) for x in qs] + [(0, q)])) != len(qs) + 1:
                rej["question: duplicate stem"] += 1; continue
            qs.append({"qid": f"q{len(qs)}", "q": q, "options": opts, "answer": "ABCD".index(r["answer"]), "exampleId": r["example_id"]})
        key = ids.sha8(text)
        base = {"wc": wc, "text": text, "key": key, "qs": qs}
        if ACAD_WORDS[0] <= wc <= ACAD_WORDS[1] and len(qs) >= 3:
            base["type"] = "readAcademic"
        elif DAILY_WORDS[0] <= wc <= DAILY_WORDS[1] and len(qs) >= 2:
            base["type"] = "readDaily"
        else:
            rej["article: not enough clean questions for its length"] += 1; continue
        ov = (lambda g: len(g & grams) / len(g) if g else 0.0)(shingles(text))
        if ov >= OVERLAP_REJECT: rej["article: already in Content/ (6-gram overlap)"] += 1; continue
        if (r_ := index.check(text)):
            rej["article: dedupe " + r_.split(" of ")[0]] += 1; continue
        cands.append(base)

    # selection: academic prefers articles that already have 5 clean questions; daily prefers 3
    rnd = random.Random(20261024)
    acad = [c for c in cands if c["type"] == "readAcademic"]
    daily = [c for c in cands if c["type"] == "readDaily"]
    for lst in (acad, daily):
        rnd.shuffle(lst)
    acad.sort(key=lambda c: -min(len(c["qs"]), 5))
    daily.sort(key=lambda c: -min(len(c["qs"]), 3))
    sel = acad[:CAP["readAcademic"]] + daily[:CAP["readDaily"]]
    rej["selection: over cap"] += len(cands) - len(sel)

    staged = []
    for c in sel:
        t = c["type"]
        short = "ra" if t == "readAcademic" else "rd"
        want = 5 if t == "readAcademic" else 3
        qs = c["qs"][:want]
        # a 6th question is not used; a 4-question academic article needs one more written by the fill agent
        iid = ids.item_id(t, SOURCE, c["key"])
        item = {"id": iid, "type": t, "skill": "reading", "cefr": cefr.estimate(c["text"], "B2"), "title": "",
                "text": c["text"], "questions": qs, "needsExtra": 5 - len(qs) if t == "readAcademic" else 0,
                "source": SOURCE, "sourceId": c["key"], "license": LICENSE, "tier": TIER, "group": f"race:{c['key']}",
                "origin": "adapted", "topics": ["workplace"] if workplace.score(c["text"]) >= 0.04 else []}
        probe = json.loads(json.dumps(item))
        probe["title"] = "Placeholder Title"
        probe["questions"] = [{"q": q["q"], "options": q["options"], "answer": q["answer"], "explanation": "Placeholder explanation here."}
                              for q in qs]
        while t == "readAcademic" and len(probe["questions"]) < 5:
            probe["questions"].append(dict(probe["questions"][0]))
        if (probs := schema.problems_item(probe)):
            rej["schema: " + probs[0][:70]] += 1; continue
        staged.append(item)

    staged.sort(key=lambda r: r["id"])
    (stage / "batches").mkdir(exist_ok=True)
    for old in (stage / "batches").glob("*.jsonl"):
        old.unlink()
    (stage / "items.jsonl").write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in staged), encoding="utf-8")
    paths = []
    for t, size, tag in (("readAcademic", 25, "academic"), ("readDaily", 40, "daily")):
        part = [r for r in staged if r["type"] == t]
        nb = max(1, -(-len(part) // size)) if part else 0
        per = -(-len(part) // nb) if nb else 0
        for b in range(nb):
            p = stage / "batches" / f"batch-{tag}-{b + 1:02d}.jsonl"
            with p.open("w", encoding="utf-8") as f:
                for r in part[b * per:(b + 1) * per]:
                    f.write(json.dumps({"id": r["id"], "type": t, "text": r["text"], "needsExtra": r["needsExtra"],
                                        "questions": [{"qid": q["qid"], "q": q["q"], "options": q["options"]} for q in r["questions"]]},
                                       ensure_ascii=False) + "\n")
            paths.append(p)
    write_report(staged, rej, paths, len(order))
    print(f"staged {len(staged)} {dict(Counter(r['type'] for r in staged))}; batches {len(paths)}")
    print("rejects:", json.dumps(dict(rej), indent=1))


def write_report(staged, rej, paths, n_art) -> None:
    sample = random.Random(5).sample(staged, min(30, len(staged)))
    out = [f"# race report ({date.today()})", "",
           "License verified at the source: HF card README quotes the CMU terms 'RACE dataset is available for non-commercial research purpose only' "
           "and forbids reproducing/trading derived data for commercial purposes. HF tag `other`. Tier `nc`, files `*.nc.json`, personal study only.", "",
           "## Counts", f"- source: high/train, {n_art} unique articles",
           f"- staged: {dict(Counter(r['type'] for r in staged))}; readAcademic needing a written 5th question: "
           f"{sum(1 for r in staged if r['needsExtra'])}",
           f"- cefr: {dict(Counter((r['type'], r['cefr']) for r in staged))}",
           f"- batches: {', '.join(p.name for p in paths)}", "", "## Rejects", *(f"- {k}: {v}" for k, v in sorted(rej.items())),
           "", "## 30-item random sample", ""]
    for r in sample:
        out.append(f"### `{r['id']}` [{r['cefr']}]\n{r['text']}\n")
        for q in r["questions"]:
            out.append(f"- {q['q']} -> **{q['options'][q['answer']]}**")
        out.append("")
    (ROOT / ".ingest/reports").mkdir(parents=True, exist_ok=True)
    (ROOT / ".ingest/reports/race.md").write_text("\n".join(out), encoding="utf-8")


# ----------------------------------------------------------------------------- emit (run after the fill)

# Hand review of the 30-item sample (2026-10-24): items dropped for residual OCR noise that the extract filters missed.
MANUAL_EXCLUDE = {"ra-race-fa4a8b4d": "typo in an option ('nose of the car')", "rd-race-c9931162": "OCR noise 'Helsinki(,)' in the text"}


def emit_step(stage: Path) -> None:
    """Reads batches/*.filled.jsonl: {id, reject, title, questions:[{qid, blindAnswer, explanation, unsound}], extra:[{q, options, answer, blindAnswer, explanation, unsound}]}.
    A question is kept only when blindAnswer equals the source key (and is not unsound). Extras are written by the fill agent
    (origin stays `adapted`: the text is the source's, some questions are LLM-made). Writes the final report."""
    from lib import emit as emit_lib   # noqa: PLC0415
    drafts = {json.loads(l)["id"]: json.loads(l) for l in (stage / "items.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()}
    out: dict[str, list[dict]] = {"readAcademic": [], "readDaily": []}
    seen: set[str] = set()
    rej: Counter = Counter()
    per_batch: dict[str, Counter] = {}
    index, grams = existing_index(("read-academic-race", "read-daily-race"))
    filled_ids: set[str] = set()
    n_q_src = n_q_extra = 0
    for fp in sorted((stage / "batches").glob("batch-*.filled.jsonl")):
        bc = per_batch.setdefault(fp.name, Counter())
        for l in fp.read_text(encoding="utf-8").splitlines():
            if not l.strip(): continue
            r = json.loads(l); d = drafts.get(r["id"])
            bc["rows"] += 1
            if d is None or r["id"] in seen:
                rej["unknown/duplicate id"] += 1; bc["bad id"] += 1; continue
            seen.add(r["id"]); filled_ids.add(r["id"])
            if r["id"] in MANUAL_EXCLUDE or re.search(r"\(\W{1,2}\)", d["text"]):
                rej["hand review: OCR noise"] += 1; bc["hand review"] += 1; continue
            if r.get("reject"):
                rej["agent reject"] += 1; bc["agent reject"] += 1; continue
            fq = {q["qid"]: q for q in r["questions"]}
            qs = []
            for q in d["questions"]:
                f = fq.get(q["qid"])
                if not f or f.get("unsound") or f.get("blindAnswer") != q["answer"]:
                    rej["question: key disagrees or unsound"] += 1; continue
                if not (f.get("explanation") or "").strip(): rej["question: no explanation"] += 1; continue
                qs.append({"q": q["q"].lstrip(". ").strip(), "options": q["options"], "answer": q["answer"], "explanation": f["explanation"].strip()})
            n_q_src += len(qs)
            for x in r.get("extra") or []:
                if x.get("unsound") or x.get("blindAnswer") != x.get("answer") or not (x.get("explanation") or "").strip():
                    rej["extra question: unsound/disagrees"] += 1; continue
                qs.append({"q": x["q"], "options": x["options"], "answer": x["answer"], "explanation": x["explanation"].strip()})
                n_q_extra += 1
            need = 5 if d["type"] == "readAcademic" else 2
            if len(qs) < need:
                rej["item: too few sound questions"] += 1; bc["too few sound"] += 1; continue
            if not (r.get("title") or "").strip():
                rej["item: no title"] += 1; continue
            qs = qs[:5] if d["type"] == "readAcademic" else qs[:3]
            if (why := index.check_and_add(d["id"], d["text"])):
                rej["item: dedupe " + why.split(" of ")[0]] += 1; continue
            row = {"id": d["id"], "type": d["type"], "skill": d["skill"], "cefr": d["cefr"], "title": r["title"].strip(),
                   "text": d["text"], "questions": qs, **{k: d[k] for k in ("source", "sourceId", "license", "tier", "group", "origin", "topics")}}
            bc["kept"] += 1
            out[d["type"]].append(row)
    for t, fn in (("readAcademic", "read-academic-race.nc.json"), ("readDaily", "read-daily-race.nc.json")):
        if out[t]:
            emit_lib.emit(ROOT / "Content", "items", fn, sorted(out[t], key=lambda x: x["id"]), source="RACE (high)", url=URL,
                          license=LICENSE, tier=TIER, attribution="Lai et al. 2017, RACE (CMU); personal study only, not redistributed")
    final = sorted(out["readAcademic"] + out["readDaily"], key=lambda x: x["id"])
    not_filled = len(drafts) - len(filled_ids)
    lines = [f"# race report, emit ({date.today()})", "",
             "License: CMU RACE terms, 'available for non-commercial research purpose only' (HF card). Tier `nc`, files `*.nc.json`, personal study only.", "",
             "## Counts", f"- staged drafts: {len(drafts)}; never filled (no batch row): {not_filled}",
             f"- emitted: {len(out['readAcademic'])} readAcademic (cap 300), {len(out['readDaily'])} readDaily (cap 400)",
             f"- questions: {n_q_src} from the source (key confirmed blind), {n_q_extra} written by the fill agent and blind-verified",
             f"- cefr: {dict(sorted(Counter((x['type'], x['cefr']) for x in final).items()))}",
             f"- word counts: " + ", ".join(f"{t} {min(textnorm.word_count(x['text']) for x in v)}-{max(textnorm.word_count(x['text']) for x in v)}" for t, v in out.items() if v),
             f"- topics workplace-tagged: {sum(1 for x in final if x['topics'])}",
             "", "## Per-batch reject rates", "| batch | rows | agent reject | too few sound | kept | reject rate |", "|---|---|---|---|---|---|"]
    for n, bc in per_batch.items():
        lines.append(f"| {n} | {bc['rows']} | {bc['agent reject']} | {bc['too few sound']} | {bc['kept']} | {1 - bc['kept'] / max(1, bc['rows']):.0%} |")
    lines += ["", "## Filter counts at emit", *(f"- {k}: {v}" for k, v in sorted(rej.items())),
              "", "Extract-stage filter counts are in `.ingest/stage/race/extract-report.md` (copied from the earlier report).", "",
              "## 30-item random sample (read by hand)", ""]
    for x in random.Random(11).sample(final, min(30, len(final))):
        lines.append(f"### `{x['id']}` {x['type']} [{x['cefr']}] {x['title']}\n{x['text']}\n")
        for q in x["questions"]:
            lines.append(f"- {q['q']} -> **{q['options'][q['answer']]}** ({q['explanation']})")
        lines.append("")
    rp = ROOT / ".ingest/reports/race.md"
    old = rp.read_text(encoding="utf-8") if rp.exists() else ""
    ex = stage / "extract-report.md"
    if old.startswith("# race report (") and not ex.exists():
        ex.write_text(old, encoding="utf-8")
    rp.write_text("\n".join(lines), encoding="utf-8")
    print({t: len(v) for t, v in out.items()}, dict(rej))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["fetch", "extract", "emit"])
    ap.add_argument("--raw", default=".ingest/raw/race")
    ap.add_argument("--stage", default=".ingest/stage/race")
    a = ap.parse_args()
    {"fetch": lambda: fetch(ROOT / a.raw), "extract": lambda: extract(ROOT / a.raw, ROOT / a.stage),
     "emit": lambda: emit_step(ROOT / a.stage)}[a.cmd]()


if __name__ == "__main__":
    main()
