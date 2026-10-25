"""C09: Mozilla Common Voice English sentence text (CC0) -> listenRepeat.

Commands (run with `uv run --project scripts/ingest python -I scripts/ingest/sources/commonvoice.py <cmd>`):
  fetch    download selected server/data/en/*.txt files into .ingest/raw/commonvoice/ (must be empty/new)
  extract  filter raw/ (data only) -> .ingest/stage/commonvoice/candidates.jsonl + .ingest/reports/commonvoice.md
  emit     stage/ -> Content/items/listen-repeat-commonvoice.json (+ licenses.json entry)

License verified at the source (2026-10-23): the common-voice/common-voice README states the sentence text in
/server/data is released under CC0; server/data/en/LICENSE is the CC0 1.0 Universal legal text.
The huge wiki.en*.txt files (encyclopedic, proper-noun heavy) are deliberately not downloaded.
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

from lib import cefr, dedupe, emit as emit_mod, ids, textnorm, workplace  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
BASE = "https://raw.githubusercontent.com/common-voice/common-voice/main/server/data/en/"
FILES = ["LICENSE", "sentence-collector.txt", "DNGros.txt", "ajaydee.txt", "elleo.txt", "est31.txt",
         "harvsents.txt", "james_fortune.txt", "jf99.txt", "mlennox.txt", "pro.gadget.txt", "reinhart1010.txt",
         "thehowl.txt", "tlcoles.txt", "bavencope.txt", "kieran_drew.txt", "RLarissa.txt"]
SOURCE = "commonvoice"
OUT_FILE = "listen-repeat-commonvoice.json"
TARGET = 300
MIN_REGISTER = 1.6  # below 2.0 a polite/pragmatic phrase is also required (workplace word alone lets literary lines in)

# Offensive, violent, sexual, drug, religious/political-charged or childish vocabulary: any hit rejects.
BLOCK = set("""
fuck fucking shit shitty bitch bastard asshole ass arse damn damned hell crap piss dick cock pussy slut whore
sex sexy sexual naked nude porn rape raped rapist kill killed killing murder murdered murderer suicide dead death
die died dies dying corpse blood bloody bleed gun guns shoot shot shooting rifle bomb bombs terror terrorist
war wars army soldier soldiers weapon weapons stab knife drunk drug drugs cocaine heroin marijuana weed beer wine
whisky vodka alcohol cigarette cigarettes smoke smoking nazi hitler jew jews jewish muslim islam christian christ
jesus god gods lord church priest pope bible devil satan demon demons ghost ghosts witch witches wizard magic
magical fairy fairies princess prince queen king kingdom dragon dragons monster monsters elf elves
mommy mummy daddy mama papa baby babies toy toys doll dolls puppy kitten bunny pony teddy candy cookie cookies
nursery kindergarten cartoon santa christmas easter halloween trump obama brexit republican democrat
idiot stupid dumb fat ugly gay lesbian negro nigger retard slave slaves slavery
hath doth thou thee thy thine ye shalt wilt art whom whose unto hither thither wherefore
""".split())
# Narrative/fiction cues: third person actors + literary connectors. Common Voice's sentence-collector text is
# largely public-domain novels, which is the wrong register for "natural, adult, workplace-capable" English.
FICTION = set("""
he she his her him hers himself herself said asked replied cried exclaimed whispered muttered shouted
dare dear fellow fellows contemplate precious remedy quarter prisoners prisoner punishment corporal moral lay lest nay yea aye wish shall oh
felicity smash sacrifice babysitting
madam sir mr mrs miss gentleman gentlemen lady ladies maiden thither perhaps whilst amongst upon thus whence
""".split())
SECOND_OR_FIRST = re.compile(r"\b(i|i'm|i'll|i've|i'd|we|we're|we'll|we've|you|you're|you'll|you've|let's|our|my|your)\b", re.I)
QUESTION_STARTERS = ("can ", "could ", "would ", "will ", "do ", "does ", "did ", "is ", "are ", "have ", "has ",
                     "what ", "when ", "where ", "who ", "why ", "how ", "which ", "should ")
WEAK_HITS = {"up", "follow", "time", "process", "issue", "issues", "stock", "report", "cost", "costs", "order", "team", "quality",
             "demand", "supply", "review", "update", "request", "risk", "payment", "process", "planning", "schedule"}
WORD = re.compile(r"[A-Za-z]+(?:'[A-Za-z]+)?")


def _wf(w: str) -> float:
    from wordfreq import zipf_frequency
    return zipf_frequency(w.lower(), "en")


def fetch(raw: Path) -> None:
    if raw.exists() and any(raw.iterdir()):
        sys.exit(f"{raw} is not empty; each source downloads into its own new empty dir")
    raw.mkdir(parents=True, exist_ok=True)
    for f in FILES:
        with urllib.request.urlopen(BASE + f, timeout=60) as r:
            (raw / f).write_bytes(r.read())
        print("fetched", f)


def reject_reason(s: str) -> str | None:
    """Return a reject reason or None. `s` is already unicode-normalized and stripped."""
    n = textnorm.word_count(s)
    if not 8 <= n <= 18:
        return "length"
    if not s[0].isupper() or s[-1] not in ".?!":
        return "form"
    if re.search(r"[\d\"“”()\[\]{}<>;:/\\@#%&*_=+~|^]|\.\.|--| - |http|www\.", s):
        return "chars"
    if re.search(r"[^\x20-\x7e]", s):
        return "non-ascii"
    if s.count("!") > 1 or s.count("?") > 1 or s.count(",") > 2:
        return "punct"
    toks = WORD.findall(s)
    low = [t.lower() for t in toks]
    if set(low) & BLOCK:
        return "blocklist"
    if re.search(r"^(strong enough|i wonder can)", s, re.I):
        return "awkward"
    base = {t.split("'")[0] for t in low}
    if base & FICTION:
        return "fiction"
    # proper nouns: a capitalized word anywhere except sentence start and "I"
    for t in toks[1:]:
        if t[0].isupper() and t != "I" and not t.startswith("I'"):
            return "proper-noun"
    if re.match(r"^[A-Za-z]+,", s) and low[0] not in ("so", "well", "also", "however", "yes", "no", "sure", "okay", "thanks", "first", "then", "actually", "please", "finally", "meanwhile", "unfortunately", "again", "now"):
        return "vocative"
    rare = [t for t in low if _wf(t) < 3.2]
    if rare:
        return "rare-word"
    if sum(1 for t in low if _wf(t) < 3.5) > 2:
        return "rare-words"
    return None


POLITE = re.compile(r"\b(please|thank you|thanks|sorry|could you|would you|can you|let me|let's|i think|i need|i'd like|we need|we should|i was wondering|do you mind)\b", re.I)


def register_score(s: str) -> float:
    """Higher = more modern/pragmatic. Needs a workplace hit or a polite/pragmatic phrase to count at all."""
    hits = [h for h in workplace.hits(s) if h not in WEAK_HITS]
    polite = bool(POLITE.search(s))
    if not hits and not polite:
        return 0.0
    sc = min(3.0, len(hits) * 1.2) + (0.8 if polite else 0.0)
    if SECOND_OR_FIRST.search(s):
        sc += 0.5
    if s.endswith("?") or s.lower().startswith(QUESTION_STARTERS):
        sc += 0.3
    return sc


def extract(raw: Path, stage: Path, report: Path) -> None:
    stage.mkdir(parents=True, exist_ok=True)
    report.parent.mkdir(parents=True, exist_ok=True)
    reasons: Counter = Counter()
    seen: set[str] = set()
    kept: list[dict] = []
    total = 0
    for f in FILES:
        if f == "LICENSE":
            continue
        p = raw / f
        if not p.exists():
            continue
        for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
            total += 1
            s = textnorm.fix_unicode(line).strip()
            s = re.sub(r"\s+", " ", s)
            r = reject_reason(s) if s else "empty"
            if r:
                reasons[r] += 1
                continue
            h = textnorm.text_hash(s)
            if h in seen:
                reasons["dup-in-source"] += 1
                continue
            seen.add(h)
            reg = register_score(s)
            kept.append({"sentence": s, "file": f, "sha": hashlib.sha256(s.encode()).hexdigest()[:8],
                         "workplace": round(workplace.score(s), 3), "register": round(reg, 3),
                         "cefr": cefr.estimate(s), "words": textnorm.word_count(s)})
    with (stage / "candidates.jsonl").open("w", encoding="utf-8") as fh:
        for r in kept:
            fh.write(json.dumps(r, ensure_ascii=False) + "\n")
    lines = ["# Common Voice (CC0) listenRepeat: extract report", "", f"- raw lines read: {total}",
             f"- candidates after hard filters: {len(kept)}", "", "## Reject reasons", ""]
    lines += [f"- {k}: {v}" for k, v in reasons.most_common()]
    report.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"read {total}, kept {len(kept)}; report {report}")


def emit(stage: Path, content: Path, report: Path) -> None:
    rows = [json.loads(l) for l in (stage / "candidates.jsonl").read_text(encoding="utf-8").splitlines()]
    # Rank: register score first (modern/pragmatic/workplace), small stable hash tiebreak.
    rows.sort(key=lambda r: (-r["register"], r["sha"]))
    # Idempotent reruns: our own previous output must not count as an existing duplicate.
    own = content / "items" / OUT_FILE
    own.unlink(missing_ok=True)
    idx = dedupe.DedupeIndex.from_content(content)
    drop: Counter = Counter()
    picked: list[dict] = []
    for r in rows:
        if r["register"] < MIN_REGISTER or (r["register"] < 2.0 and not POLITE.search(r["sentence"])):
            drop["low-register"] += 1
            continue
        iid = ids.hashed_id("listenRepeat", SOURCE, textnorm.normalize_for_hash(r["sentence"]))
        reason = idx.check_and_add(iid, r["sentence"])
        if reason:
            drop[reason.split(" of ")[0]] += 1
            continue
        picked.append({"r": r, "id": iid})
        if len(picked) >= TARGET:
            break
    out = []
    for p in sorted(picked, key=lambda p: p["id"]):
        r = p["r"]
        voice = "female" if int(hashlib.sha256(p["id"].encode()).hexdigest(), 16) % 2 == 0 else "male"
        out.append({"id": p["id"], "type": "listenRepeat", "cefr": r["cefr"], "skill": "speaking",
                    "sentence": r["sentence"], "voice": voice, "source": "Mozilla Common Voice",
                    "sourceId": f"{r['file']}#{r['sha']}", "license": "CC0-1.0", "origin": "verbatim"})
    entry = emit_mod.emit(content, "items", OUT_FILE, out, source="Mozilla Common Voice English sentences",
                          url="https://github.com/common-voice/common-voice/tree/main/server/data/en",
                          license="CC0 1.0", tier="permissive",
                          attribution="Mozilla Common Voice sentence collection (public domain, CC0; no attribution required)")
    print("emitted", len(out), entry["file"], dict(drop))
    random.seed(7)
    sample = random.sample(out, min(30, len(out)))
    lv = Counter(o["cefr"] for o in out)
    txt = report.read_text(encoding="utf-8").split("\n## Emit")[0].rstrip("\n")
    txt += "\n\n## Emit\n\n" + f"- emitted: {len(out)} -> Content/items/{OUT_FILE}\n- cefr: {dict(sorted(lv.items()))}\n"
    txt += f"- dropped at emit: {dict(drop)}\n\n## Random sample (30)\n\n"
    txt += "\n".join(f"- [{o['cefr']}] {o['sentence']}" for o in sample) + "\n"
    report.write_text(txt, encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["fetch", "extract", "emit"])
    ap.add_argument("--raw", default=str(ROOT / ".ingest/raw/commonvoice"))
    ap.add_argument("--stage", default=str(ROOT / ".ingest/stage/commonvoice"))
    ap.add_argument("--report", default=str(ROOT / ".ingest/reports/commonvoice.md"))
    ap.add_argument("--content", default=str(ROOT / "Content"))
    a = ap.parse_args()
    if a.cmd == "fetch":
        fetch(Path(a.raw))
    elif a.cmd == "extract":
        extract(Path(a.raw), Path(a.stage), Path(a.report))
    else:
        emit(Path(a.stage), Path(a.content), Path(a.report))


if __name__ == "__main__":
    main()
