"""C04 OneStopEnglish (Int + Adv) -> Content/items/complete-words-ose.json, programmatic, no LLM.

  python -I scripts/ingest/sources/onestopenglish.py fetch   --raw .ingest/raw/onestopenglish
  python -I scripts/ingest/sources/onestopenglish.py extract --raw .ingest/raw/onestopenglish --stage .ingest/stage/onestopenglish
  python -I scripts/ingest/sources/onestopenglish.py emit    --stage .ingest/stage/onestopenglish
Also stages clean 150-220 word paragraphs for a later readAcademic LLM-question pass (stage/readacademic.jsonl).
"""
from __future__ import annotations

import argparse
import json
import math
import random
import re
import subprocess
import unicodedata
import sys
from collections import Counter
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from wordfreq import zipf_frequency as zipf  # noqa: E402
from lib import cefr, dedupe, emit as emitlib, gaps, ids, schema, textnorm, workplace  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
REPO = "https://github.com/nishkalavallabhi/OneStopEnglishCorpus"
LEVELS = {"Int": ("int", "B2"), "Adv": ("adv", "C1")}
TARGET = 600
MAX_PER_ARTICLE = 4
FILE = "complete-words-ose.json"

# adult / sensitive / childish content we do not want in a workplace-English trainer
BAD = re.compile(r"\b(sex|sexual|sexy|rape[ds]?|porn\w*|murder\w*|kill(?:s|ed|ing|er|ers)?|suicid\w*|genocide|massacre\w*|"
                 r"terroris[mt]\w*|bomb(?:s|ing|ed)?|abus(?:e|ed|ive)|torture\w*|slaves?|slavery|naked|nude|drugs?|cocaine|"
                 r"heroin|cannabis|paedophil\w*|prostitut\w*|corpses?|dead bod\w+|shooting|gunman|hostages?|"
                 r"fairy|santa|toys?|cartoons?|nursery|bloody|damn|crap|shit|fuck\w*|bastard|hell)\b", re.I)
BAD_START = re.compile(r"^(But|And|So|Or|Yet|However|Also|Then|Thus|Still|Even|Although|Though|He|She|They|It|This|That|These|"
                       r"Those|His|Her|Their|Its|Such|Both|Another|Other|One|Some|Many|Most|There|Here|In addition|For example|"
                       r"Meanwhile|Instead|Indeed|Because|Since|While|Not|No|Neither|Either|Each|All)\b")
SKIP_PARA = re.compile(r"(Wikipedia|Guardian|www\.|http|@|©|Photograph|Source:|Interview by|Read more|click|Copyright)", re.I)
TITLE_SKIP = re.compile(r"(horoscope|quiz|crossword|recipe)", re.I)


def run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True)


def fetch(raw: Path) -> None:
    if raw.exists() and any(raw.iterdir()):
        print("raw dir not empty; leaving as is"); return
    raw.mkdir(parents=True, exist_ok=True)
    run(["git", "clone", "--depth", "1", REPO, str(raw / "repo")])
    head = subprocess.run(["git", "-C", str(raw / "repo"), "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    (raw / "COMMIT").write_text(head + "\n")


def read_article(path: Path) -> list[str]:
    """Paragraphs (one per line), unicode-normalized, stripped of odd spacing."""
    txt = unicodedata.normalize("NFKC", path.read_text(encoding="utf-8-sig", errors="replace"))
    paras = []
    for line in txt.splitlines():
        line = textnorm.fix_unicode(re.sub(r"\s+", " ", line.replace(" ", " ")).strip())
        line = re.sub(r"\s+([,.;:!?])", r"\1", line)
        if line:
            paras.append(line)
    return paras


MISSING_APOS = re.compile(r"\b(dont|doesnt|didnt|isnt|arent|wasnt|werent|wont|cant|couldnt|wouldnt|shouldnt|hasnt|havent|hadnt|"
                          r"thats|theres|heres|whats|lets|youre|theyre|weve|youve|theyve|ive|im|ill|id|hes|shes|its a|its not|"
                          r"its been|its the|its very|its one|its also)\b", re.I)
LIG = ("fi", "fl", "ff", "ffi", "ffl")


def damaged_text(text: str) -> str | None:
    """Detect extraction damage in the corpus: dropped ligatures, stripped apostrophes/quotes/currency."""
    if text.count('"') % 2: return "unbalanced quotes"
    if re.search(r'\w \"[,.;)]|\d -\d|\d- \d|\w- \w|\d,\d{3}\b', text): return "spacing/currency damage"
    if MISSING_APOS.search(re.sub(r"[\u2019']", "", text)) and not re.search(r"\w['\u2019]\w", text): return "stripped apostrophes"
    toks = re.findall(r"[A-Za-z]+", text)
    low = [t for t in toks]
    for i, t in enumerate(low):
        if t in ("fi", "ff", "fl", "ffi", "ffl", "ft") or re.search(r"\b(fi|ff|fl) [a-z]{2,4}\b", text) and t in ("fi", "ff", "fl"):
            return f"split ligature {t}"
        if t.islower() and len(t) >= 2 and zipf(t, "en") < 1.5:
            return f"unknown token {t!r}"
        if i + 1 < len(low) and t.islower() and low[i + 1].islower():
            b = low[i + 1]
            if zipf(b, "en") < 2.0 and any(zipf(t + l + b, "en") >= 3.0 for l in LIG):
                return f"split ligature {t} {b}"
    return None


def sentence_ok(s: str) -> bool:
    return not re.search(r"\d{4,}|https?:|\bwww\b", s)


def candidate_windows(paras: list[str]):
    """Yield (start_para, sentences) windows of 70-110 words that begin at a paragraph start and stay in clean paragraphs."""
    sents, pstart = [], []
    for pi, p in enumerate(paras):
        if SKIP_PARA.search(p) or len(p.split()) < 8:
            sents.append(None); pstart.append(pi); continue   # barrier
        for k, s in enumerate(textnorm.split_sentences(p)):
            sents.append(s); pstart.append(pi if k == 0 else -1)
    for i, s in enumerate(sents):
        if s is None or pstart[i] < 0:
            continue
        cur, n = [], 0
        for t in sents[i:]:
            if t is None:
                break
            w = len(t.split())
            if n + w > gaps.MAX_WORDS:
                break
            cur.append(t); n += w
            if n >= gaps.MIN_WORDS:
                yield i / max(1, len(sents)), list(cur)
                break


def extract(raw: Path, stage: Path) -> None:
    stage.mkdir(parents=True, exist_ok=True)
    base = raw / "repo" / "Texts-SeparatedByReadingLevel"
    rejects: Counter = Counter()
    rows, ra = [], []
    total_articles = 0
    for lvl, (short, prior) in LEVELS.items():
        d = base / f"{lvl}-Txt"
        # NB: the top-level Int-Txt/*.txt files are damaged (all apostrophes and quotes stripped, ligatures dropped);
        # the intact copies are in the nested Int-Txt/Int-Txt/ folder. Adv-Txt is intact at the top level.
        if (d / f"{lvl}-Txt").is_dir():
            d = d / f"{lvl}-Txt"
        for f in sorted(d.glob(f"*-{short}.txt")):
            title = f.name[: -len(f"-{short}.txt")]
            total_articles += 1
            if TITLE_SKIP.search(title):
                rejects["title skip"] += 1; continue
            paras = read_article(f)
            art = ids.slug(title)
            whole = " ".join(paras)
            if len(whole.split()) > 250 and not re.search(r"\w['\u2019]\w", whole):
                rejects["article: no apostrophes at all (stripped)"] += 1; continue
            # readAcademic staging: 150-220 word runs of whole paragraphs, Adv only
            if lvl == "Adv":
                i = 0
                while i < len(paras):
                    j, n = i, 0
                    while j < len(paras) and n + len(paras[j].split()) <= 220:
                        n += len(paras[j].split()); j += 1
                    chunk = " ".join(paras[i:j])
                    if 150 <= n <= 220 and not SKIP_PARA.search(chunk) and not BAD.search(chunk):
                        ra.append({"sourceId": f"{short}-{art}-p{i}", "article": art, "title": title, "level": "C1",
                                   "words": n, "text": chunk})
                    i = max(j, i + 1)
            for pos, sl in candidate_windows(paras):
                text = " ".join(sl)
                reason = None
                if len(sl) < 4: reason = "<4 sentences"
                elif BAD.search(text): reason = "sensitive/childish word"
                elif BAD_START.match(sl[0]) or re.search(r"\b(the same|these|those|such|this|former|latter|the other|the first|the second)\b", " ".join(sl[0].split()[:8]), re.I): reason = "first sentence not self-contained"
                elif not all(sentence_ok(s) for s in sl): reason = "numbers/urls"
                elif re.search(r"[A-Za-z]\s?[\[\]{}<>|_]|\.\.\.|…|\([^)]*$", text): reason = "odd punctuation"
                elif sum(c.isupper() for c in text) / len(text) > 0.06: reason = "many capitals"
                elif (dm := damaged_text(text)): reason = "damaged: " + dm.split(" ")[0] + (" " + dm.split(" ")[1] if dm.startswith(("unbal", "split", "stripped", "spacing")) else "")
                if reason:
                    rejects[reason] += 1; continue
                p = gaps.make_gaps(sl)
                if not p: rejects["<10 gaps"] += 1; continue
                gw = re.findall(r"(\w*)\{\{(\w+)\}\}", p)
                caps = sum(1 for v, h in gw if (v + h)[0].isupper())
                if caps > 2: rejects[">2 capitalised gapped words"] += 1; continue
                plain = p.replace("{{", "").replace("}}", "")
                rows.append({"sourceId": f"{short}-{art}-s{round(pos*1000):03d}", "article": art, "title": title,
                             "level": prior, "pos": pos, "text": text, "passage": p,
                             "workplace": round(workplace.score(plain), 4)})
    (stage / "windows.jsonl").write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows), encoding="utf-8")
    (stage / "readacademic.jsonl").write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in ra), encoding="utf-8")
    (stage / "meta.json").write_text(json.dumps({"articles_read": total_articles, "windows_after_filters": len(rows),
                                                 "readacademic_staged": len(ra), "rejects": dict(rejects)}, indent=1))
    print(f"articles {total_articles}, windows {len(rows)}, readAcademic staged {len(ra)}, rejects {dict(rejects)}")


def emit(stage: Path) -> None:
    meta = json.loads((stage / "meta.json").read_text())
    cands = [json.loads(l) for l in (stage / "windows.jsonl").read_text(encoding="utf-8").splitlines()]
    # lib's from_content would also load our own previous output (making reruns dedupe against themselves): skip FILE
    index = dedupe.DedupeIndex()
    for sub in ("items", "vocab"):
        for f in sorted((ROOT / "Content" / sub).glob("*.json")):
            if f.name == FILE:
                continue
            for row in json.loads(f.read_text(encoding="utf-8")):
                index.add(row["id"], dedupe.item_text(row))
    rng = random.Random(7)
    rej: Counter = Counter()
    # rank: workplace relevance first, tiny deterministic jitter
    for c in cands:
        c["rank"] = c["workplace"] + rng.random() * 0.005
    cands.sort(key=lambda c: -c["rank"])
    per_article: Counter = Counter()
    taken_pos: dict[str, list[tuple[str, float]]] = {}
    rows = []
    for c in cands:
        if len(rows) >= TARGET: break
        a = c["article"]
        if per_article[a] >= MAX_PER_ARTICLE: rej["article cap"] += 1; continue
        # Int and Adv are the same article: do not take overlapping regions
        if any(abs(p - c["pos"]) < 0.15 for _, p in taken_pos.get(a, [])):
            rej["overlaps region taken for this article"] += 1; continue
        plain = c["passage"].replace("{{", "").replace("}}", "")
        iid = ids.item_id("completeWords", "ose", c["sourceId"])
        r = index.check_and_add(iid, plain)
        if r: rej["dedupe: " + ("exact" if r.startswith("exact") else "near") + " duplicate"] += 1; continue
        taken_pos.setdefault(a, []).append((c["level"], c["pos"]))
        per_article[a] += 1
        rows.append({"id": iid, "type": "completeWords", "cefr": cefr.estimate(plain, c["level"]), "skill": "reading",
                     "passage": c["passage"], "source": "onestopenglish", "sourceId": c["sourceId"],
                     "license": "CC BY-SA 4.0", "tier": "share-alike", "group": f"ose:{c['article']}",
                     "origin": "verbatim", "topics": ["workplace"] if c["workplace"] >= 0.04 else []})
    rows.sort(key=lambda r: r["id"])
    commit = (ROOT / ".ingest/raw/onestopenglish/COMMIT")
    attribution = ("Vajjala, S. and Lucic, I. (2018). OneStopEnglish corpus: A new corpus for automatic readability assessment "
                   "and text simplification. BEA Workshop, ACL. Texts adapted from Guardian articles by onestopenglish.com. "
                   "Gaps added; text otherwise unchanged. Licensed CC BY-SA 4.0"
                   + (f" (repo commit {commit.read_text().strip()[:10]})." if commit.exists() else "."))
    emitlib.emit(ROOT / "Content", "items", FILE, rows, source="OneStopEnglish corpus (Int-Txt, Adv-Txt)", url=REPO,
                 license="CC BY-SA 4.0", tier="share-alike", attribution=attribution)
    # report
    sample = random.Random(11).sample(rows, min(30, len(rows)))
    lv = Counter(r["cefr"] for r in rows); tp = sum(1 for r in rows if r["topics"])
    out = [f"# onestopenglish report ({date.today()})", "",
           "License verified at source: repo LICENSE.markdown + README badge + GitHub API = CC BY-SA 4.0 (tier share-alike).",
           "Caveat: the texts are Guardian articles republished by onestopenglish.com (Macmillan); the corpus authors license the compilation as CC BY-SA 4.0, upstream article copyright is not ours to verify.", "",
           "## Counts", f"- articles read (Int+Adv files): {meta['articles_read']}",
           f"- windows after extract filters: {meta['windows_after_filters']}",
           f"- extract rejects: {json.dumps(meta['rejects'])}",
           f"- emit rejects: {json.dumps(dict(rej))}",
           f"- emitted completeWords: {len(rows)} (target {TARGET}); distinct articles: {len(per_article)}",
           f"- cefr distribution: {dict(lv)}; workplace-tagged (score>=0.04): {tp}",
           f"- readAcademic paragraphs staged (Adv, 150-220 words): {meta['readacademic_staged']} in stage/readacademic.jsonl", "",
           "## 30-item random sample", ""]
    for r in sample:
        out.append(f"- `{r['id']}` [{r['cefr']}] {r['passage']}\n")
    (ROOT / ".ingest/reports").mkdir(parents=True, exist_ok=True)
    (ROOT / ".ingest/reports/onestopenglish.md").write_text("\n".join(out), encoding="utf-8")
    print(f"emitted {len(rows)} rows, levels {dict(lv)}, rejects {dict(rej)}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["fetch", "extract", "emit"])
    ap.add_argument("--raw", type=Path); ap.add_argument("--stage", type=Path)
    a = ap.parse_args()
    if a.cmd == "fetch": fetch(a.raw)
    elif a.cmd == "extract": extract(a.raw, a.stage)
    else: emit(a.stage)


if __name__ == "__main__":
    main()
