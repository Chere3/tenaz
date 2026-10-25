"""P4 TOEFL-QA (github iamyuanchung/TOEFL-QA; NO LICENSE, research release) -> listenTalk + listenConversation, STAGE ONLY.

  python -I scripts/ingest/sources/toeflqa.py fetch   --raw .ingest/raw/toeflqa
  python -I scripts/ingest/sources/toeflqa.py extract --raw .ingest/raw/toeflqa --stage .ingest/stage/toeflqa
  python -I scripts/ingest/sources/toeflqa.py emit    --stage .ingest/stage/toeflqa     (after the fill agents ran)

License (verified at the source 2026-10-24): the repo has no LICENSE file (GitHub license API: 404) and the README states none; it only
says the data is released "to encourage more research" and asks to cite Tseng et al. 2016 and Chung et al. 2018. Tier `unclear`,
files `*.nc.json`. Personal study only, never redistribute. Transcripts are condensed/rewritten by the fill agents (origin adapted).

Data facts: data/{train,dev,test}/tpo_<N>-<conversation|lecture>_<story>_<q> ; one file per QUESTION, the story transcript repeats in
every file of a story. Lines: SENTENCE <lowercase ASR-ish tokens, no punctuation fixes, "um"/"er"> | QUESTION <lowercase, no ?> |
OPTION <text> <0|1>. 198 stories (132 lectures 575-1072 words, 66 conversations 461-706 words), 963 questions.
Some questions have several correct options (skipped).

extract writes
  .ingest/stage/toeflqa/items.jsonl           full drafts (answer keys included)
  .ingest/stage/toeflqa/batches/*.jsonl       rows for the fill agents WITHOUT the key (blind verification)
  .ingest/reports/toeflqa.md
"""
from __future__ import annotations

import argparse
import json
import random
import re
import sys
import tarfile
import urllib.error
import urllib.request
from collections import Counter
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib import cefr, dedupe, ids, schema, textnorm  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
SOURCE = "toeflqa"
URL = "https://github.com/iamyuanchung/TOEFL-QA"
TARBALL = "https://codeload.github.com/iamyuanchung/TOEFL-QA/tar.gz/refs/heads/master"
LICENSE_API = "https://api.github.com/repos/iamyuanchung/TOEFL-QA/license"
LICENSE = "No license stated (research release, cite Tseng et al. 2016); treated as unclear, personal study only"
TIER = "unclear"
FILES = {"listenTalk": "listen-talk-toeflqa.nc.json", "listenConversation": "listen-conversation-toeflqa.nc.json"}
BATCH = {"listenTalk": (25, "talk"), "listenConversation": (33, "conv")}
FNAME = re.compile(r"^tpo_(\d+)-(conversation|lecture)_(\d+)_(\d+)$")

# only what would make an item inappropriate or unanswerable; academic content is otherwise fine
BAD = re.compile(r"\b(sex|sexual|rape[ds]?|porn\w*|suicid\w*|genocide|massacre\w*|fuck\w*|shit|bastard|nude|naked|cocaine|heroin|prostitut\w*)\b", re.I)
OPT_BAD = re.compile(r"(all of the above|none of the above|\bboth (?:a|b)\b|\bof the above\b)", re.I)
Q_BAD = re.compile(r"\b(listen again|replay|picture|diagram|slide|chart|graph shows)\b", re.I)


def _get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "tenaz-ingest"})
    with urllib.request.urlopen(req, timeout=180) as r:
        return r.read()


def fetch(raw: Path) -> None:
    try:
        _get(LICENSE_API)
        sys.exit("GitHub reports a license for TOEFL-QA now; re-verify by hand and update this script")
    except urllib.error.HTTPError as e:
        if e.code != 404:
            raise
    readme = _get("https://raw.githubusercontent.com/iamyuanchung/TOEFL-QA/master/README.md").decode("utf-8", "replace")
    if re.search(r"\blicen[sc]e\b", readme, re.I):
        sys.exit("README mentions a license; re-verify by hand")
    print("license: none (GitHub license API 404, README states none; 'publicly available to encourage more research')")
    if raw.exists() and any(raw.iterdir()):
        print("raw dir not empty; leaving as is"); return
    raw.mkdir(parents=True, exist_ok=True)
    (raw / "repo.tgz").write_bytes(_get(TARBALL))
    with tarfile.open(raw / "repo.tgz") as tf:
        tf.extractall(raw, filter="data")   # data only; nothing from here is ever executed
    (raw / "LICENSE-CHECK").write_text(f"GitHub license API: 404 Not Found\nREADME: no license, 'publicly available to encourage more research'\nchecked: {date.today()}\n")


# ----------------------------------------------------------------------------- helpers

def clean_line(s: str) -> str:
    s = re.sub(r"\s{2,}", " ", s)   # a double space marks a pause in the ASR transcript
    return textnorm.clean_sentence(s)


def clean_question(s: str) -> str:
    s = textnorm.detokenize(re.sub(r"\s{2,}", " ", s)).strip()
    s = re.sub(r"\bi\b(?=(\s|'|,|$))", "I", s)
    s = s[:1].upper() + s[1:]
    return s if s.endswith("?") else s + "?"


def clean_option(s: str) -> str:
    s = textnorm.detokenize(re.sub(r"\s{2,}", " ", s)).strip().rstrip(".")
    s = re.sub(r"\bi\b(?=(\s|'|,|$))", "I", s)
    return s[:1].upper() + s[1:]


def parse(path: Path) -> dict:
    sents, q, opts = [], None, []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("SENTENCE "):
            sents.append(line[9:])
        elif line.startswith("QUESTION "):
            q = line[9:]
        elif line.startswith("OPTION "):
            body, _, flag = line[7:].rpartition(" ")
            opts.append((body, flag))
    return {"sents": sents, "q": q, "opts": opts}


def existing_index():
    index = dedupe.DedupeIndex()
    for sub in ("items", "vocab"):
        for f in sorted((ROOT / "Content" / sub).glob("*.json")):
            if "toeflqa" in f.name:
                continue
            for row in json.loads(f.read_text(encoding="utf-8")):
                index.add(row["id"], dedupe.item_text(row))
    return index


# ----------------------------------------------------------------------------- extract

def extract(raw: Path, stage: Path) -> None:
    data_dirs = list(raw.glob("*/data"))
    if len(data_dirs) != 1:
        sys.exit("expected exactly one */data dir under raw")
    stage.mkdir(parents=True, exist_ok=True)
    stories: dict[tuple, dict] = {}
    rej: Counter = Counter()
    for split in ("train", "dev", "test"):
        for p in sorted((data_dirs[0] / split).iterdir()):
            m = FNAME.match(p.name)
            if not m:
                rej["file: unexpected name"] += 1; continue
            tpo, kind, sno, qno = m.groups()
            d = parse(p)
            st = stories.setdefault((tpo, kind, sno), {"sents": d["sents"], "qs": []})
            if st["sents"] != d["sents"]:
                rej["story: transcript differs between question files"] += 1; continue
            rej["questions seen"] += 1
            if not d["q"] or len(d["opts"]) != 4 or sum(f == "1" for _, f in d["opts"]) != 1:
                rej["question: not 4 options with exactly one key"] += 1; continue
            q = clean_question(d["q"]); opts = [clean_option(o) for o, _ in d["opts"]]
            ans = [f for _, f in d["opts"]].index("1")
            if Q_BAD.search(q): rej["question: refers to audio replay/visual"] += 1; continue
            if any(OPT_BAD.search(o) for o in opts): rej["question: all-of-the-above style option"] += 1; continue
            if len({o.lower() for o in opts}) != 4: rej["question: duplicate options"] += 1; continue
            if any(not o or len(o.split()) > 25 for o in opts): rej["question: empty or long option"] += 1; continue
            st["qs"].append({"split": split, "no": int(qno), "q": q, "options": opts, "answer": ans})

    index = existing_index()
    staged = []
    for (tpo, kind, sno), st in sorted(stories.items(), key=lambda kv: (int(kv[0][0]), kv[0][1], int(kv[0][2]))):
        rej["stories seen"] += 1
        t = "listenTalk" if kind == "lecture" else "listenConversation"
        lines = [clean_line(s) for s in st["sents"] if s.strip()]
        text = " ".join(lines)
        if BAD.search(text): rej["story: sensitive word"] += 1; continue
        qs, seen_q = [], set()
        for q in sorted(st["qs"], key=lambda x: x["no"]):
            if q["q"].lower() in seen_q:
                rej["question: duplicate stem in story"] += 1; continue
            if BAD.search(q["q"] + " " + " ".join(q["options"])): rej["question: sensitive word"] += 1; continue
            seen_q.add(q["q"].lower())
            qs.append({"qid": f"q{len(qs)}", "q": q["q"], "options": q["options"], "answer": q["answer"],
                       "src": f"{q['split']}/tpo_{tpo}-{kind}_{sno}_{q['no']}"})
        if len(qs) < 3:
            rej["story: fewer than 3 clean questions"] += 1; continue
        if (why := index.check(text)):
            rej["story: dedupe " + why.split(" of ")[0]] += 1; continue
        key = f"tpo{tpo}-{kind[:4]}{sno}"
        iid = ids.item_id(t, SOURCE, key)
        item = {"id": iid, "type": t, "skill": "listening", "cefr": cefr.estimate(text, "B2+"),
                "transcript": text, "srcWords": textnorm.word_count(text), "lines": lines if t == "listenConversation" else None,
                "questions": qs, "source": SOURCE, "sourceId": key, "license": LICENSE, "tier": TIER,
                "group": f"toeflqa:{key}", "origin": "adapted", "topics": ["academic"]}
        probe = {"id": iid, "type": t, "skill": "listening", "cefr": item["cefr"], "title": "Placeholder Title",
                 "source": SOURCE, "sourceId": key, "license": LICENSE, "tier": TIER, "group": item["group"], "origin": "adapted",
                 "questions": [{"q": q["q"], "options": q["options"], "answer": q["answer"], "explanation": "Placeholder explanation here."}
                               for q in (qs * 2)[:4 if t == "listenTalk" else 3]]}
        if t == "listenTalk":
            probe["voice"] = "female"; probe["script"] = " ".join(["word"] * 200)
        else:
            probe["script"] = [{"speaker": "AB"[i % 2], "voice": "female" if i % 2 == 0 else "male", "line": "Some line here."} for i in range(10)]
        if (probs := schema.problems_item(probe)):
            rej["schema: " + probs[0][:70]] += 1; continue
        index.add(iid, text)
        staged.append(item)

    (stage / "batches").mkdir(exist_ok=True)
    for old in (stage / "batches").glob("*"):
        old.unlink()
    (stage / "items.jsonl").write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in staged), encoding="utf-8")
    paths = []
    rnd = random.Random(20261024)
    for t, (size, tag) in BATCH.items():
        part = [r for r in staged if r["type"] == t]
        rnd.shuffle(part)   # mix tpo sets across batches
        nb = max(1, -(-len(part) // size)) if part else 0
        per = -(-len(part) // nb) if nb else 0
        for b in range(nb):
            p = stage / "batches" / f"batch-{tag}-{b + 1:02d}.jsonl"
            with p.open("w", encoding="utf-8") as f:
                for r in part[b * per:(b + 1) * per]:
                    row = {"id": r["id"], "type": t, "srcWords": r["srcWords"],
                           "needsExtra": max(0, 4 - len(r["questions"])) if t == "listenTalk" else 0,
                           "questions": [{"qid": q["qid"], "q": q["q"], "options": q["options"]} for q in r["questions"]]}
                    if t == "listenTalk":
                        row["transcript"] = r["transcript"]
                    else:
                        row["lines"] = r["lines"]   # source sentences; speaker turns are NOT marked in the source
                    f.write(json.dumps(row, ensure_ascii=False) + "\n")
            paths.append(p)
    write_report(staged, rej, paths)
    print(f"staged {len(staged)} {dict(Counter(r['type'] for r in staged))}; batches {len(paths)}")
    print("rejects:", json.dumps(dict(rej), indent=1))


def write_report(staged, rej, paths) -> None:
    sample = random.Random(5).sample(staged, min(30, len(staged)))
    out = [f"# toeflqa report ({date.today()})", "",
           "License verified at the source: no LICENSE file (GitHub license API 404), README states none, only 'publicly available to encourage "
           "more research' + citation request. Tier `unclear`, files `*.nc.json`, personal study only.", "",
           "## Counts", f"- staged: {dict(Counter(r['type'] for r in staged))}",
           f"- questions kept per story: {dict(Counter(len(r['questions']) for r in staged))}",
           f"- cefr: {dict(Counter((r['type'], r['cefr']) for r in staged))}",
           f"- batches: {', '.join(p.name for p in paths)}", "", "## Rejects", *(f"- {k}: {v}" for k, v in sorted(rej.items())),
           "", "## 30-item random sample", ""]
    for r in sample:
        out.append(f"### `{r['id']}` [{r['cefr']}] {r['srcWords']} words\n{r['transcript'][:600]}...\n")
        for q in r["questions"]:
            out.append(f"- {q['q']} -> **{q['options'][q['answer']]}**")
        out.append("")
    (ROOT / ".ingest/reports").mkdir(parents=True, exist_ok=True)
    (ROOT / ".ingest/reports/toeflqa.md").write_text("\n".join(out), encoding="utf-8")


# ----------------------------------------------------------------------------- emit (run after the fill)

def emit_step(stage: Path) -> None:
    """Reads batches/*.filled.jsonl, one JSON per line:
      {id, reject?, title, cefr?, script, questions:[{qid, keep, blindAnswer, explanation, unsound}],
       extra:[{q, options, answer, blindAnswer, explanation, unsound}]}
    script = string (listenTalk) or [{speaker:'A'|'B', line}] (listenConversation). A source question is kept only when keep is true,
    not unsound, and blindAnswer equals the source key."""
    from lib import emit as emit_lib   # noqa: PLC0415
    drafts = {json.loads(l)["id"]: json.loads(l) for l in (stage / "items.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()}
    out: dict[str, list[dict]] = {t: [] for t in FILES}
    seen: set[str] = set()
    rej: Counter = Counter()
    per_batch: dict[str, Counter] = {}
    dd = existing_index()
    for fp in sorted((stage / "batches").glob("batch-*.filled.jsonl")):
        bc = per_batch.setdefault(fp.name.replace(".filled.jsonl", ""), Counter())
        for l in fp.read_text(encoding="utf-8").splitlines():
            if not l.strip(): continue
            r = json.loads(l); d = drafts.get(r["id"])
            bc["rows"] += 1
            if d is None or r["id"] in seen or r.get("reject"):
                rej["unknown/duplicate/rejected"] += 1; bc["rejected"] += 1; continue
            seen.add(r["id"])
            fq = {q["qid"]: q for q in r["questions"]}
            qs = []
            _txt = r["script"] if isinstance(r["script"], str) else " ".join(x["line"] for x in r["script"])
            pr = propers_of(_txt); voc = set(re.findall(r"[a-z]+", _txt.lower()))
            for q in d["questions"]:
                f = fq.get(q["qid"])
                if not f or not f.get("keep") or f.get("unsound") or f.get("blindAnswer") != q["answer"]:
                    rej["question: dropped (not kept / key disagrees / unsound)"] += 1; bc["q dropped"] += 1; continue
                qs.append({"q": fix_q(q["q"], pr, voc), "options": [fix_q(o, pr, voc) for o in q["options"]], "answer": q["answer"], "explanation": f["explanation"].strip()})
            for x in r.get("extra") or []:
                if x.get("unsound") or x.get("blindAnswer") != x["answer"]: continue
                qs.append({"q": fix_q(x["q"], pr, voc), "options": [fix_q(o, pr, voc) for o in x["options"]], "answer": x["answer"], "explanation": x["explanation"].strip()})
            t = d["type"]
            if len(qs) < (4 if t == "listenTalk" else 3):
                rej["item: too few sound questions"] += 1; bc["rejected"] += 1; continue
            qs = qs[:4]
            fem_first = int(ids.sha8(d["id"]), 16) % 2 == 0
            if t == "listenTalk":
                script = r["script"].strip(); extra = {"voice": "female" if fem_first else "male"}
            else:
                script = [{"speaker": s["speaker"], "voice": "female" if (s["speaker"] == "A") == fem_first else "male", "line": s["line"].strip()}
                          for s in r["script"]]
                extra = {}
            text = script if isinstance(script, str) else " ".join(x["line"] for x in script)
            if (why := dd.check_and_add(d["id"], text)):
                rej["item: dedupe " + why.split(" of ")[0]] += 1; bc["rejected"] += 1; continue
            bc["emitted"] += 1
            out[t].append({"id": d["id"], "type": t, "cefr": r.get("cefr") or d["cefr"], "skill": "listening", "title": r["title"].strip(),
                           **extra, "script": script, "questions": qs, "topics": d["topics"], "group": d["group"], "source": d["source"],
                           "sourceId": d["sourceId"], "license": d["license"], "tier": d["tier"], "origin": d["origin"]})
    for t, fn in FILES.items():
        if out[t]:
            emit_lib.emit(ROOT / "Content", "items", fn, sorted(out[t], key=lambda x: x["id"]), source="TOEFL-QA", url=URL,
                          license=LICENSE, tier=TIER,
                          attribution="Tseng et al. 2016 (INTERSPEECH), Chung et al. 2018 (NAACL), iamyuanchung/TOEFL-QA; transcripts condensed and "
                                      "questions verified with Claude; personal study only, not redistributed")
    print({t: len(v) for t, v in out.items()}, dict(rej))
    write_emit_report(out, rej, per_batch)


GLUE = re.compile(r"\b(\w+)'([a-z]{4,})\b")


def _unglue(m, vocab):
    head, rest = m.group(1), m.group(2)
    if rest[0] == "s" and rest not in vocab and rest[1:] in vocab:
        rest = rest[1:]
    return f"{head}' {rest}" if head.endswith("s") else f"{head}'s {rest}"


PROPER_EXTRA = "greek roman american european english french japanese spanish egyptian egyptians chinese german italian british indian african asian europe america asia africa egypt".split()


CI_FIX = [(r"\bsopinions\b", "opinions"), (r"\bjean painlev", "Jean Painlev"), (r"\beastern europe\b", "Eastern Europe"),
          (r"\bbartk (original|music)\b", r"Bartók's \1"), (r"\bbart[oó]k (original|music)\b", r"Bartók's \1"), (r"\bintorduction\b", "introduction"), (r"\bacions\b", "actions"),           (r"\bwerecreated\b", "were created"), (r"\btrussing\b", "crossing"), (r"\babservations\b", "observations"), (r"\bconking\b", "cooking"),
          (r"\bcecllia\b", "Cecilia"), (r"\bsurtaces\b", "surfaces"), (r"\bbartk\b", "Bartók"), (r"\bengjneer ng\b", "engineering"),
          (r"\bpainleve\b|\bpianleve\b", "Painlevé"), (r"\bprato indo european\b", "Proto-Indo-European"),
          (r"\bjacques\b", "Jacques"), (r"\bclarke's\b", "Clarke's"), (r"\bgrabell's\b", "Grabell's"), (r"\bpostpo ne\b", "postpone"),
          (r"\bgalilee\b", "Galileo"), (r"\btexta\b", "text A"), (r"\bv5\b", "V5"), (r"\bviolins? makes\b", "violin makers"),
          (r"\bviolins makers\b", "violin makers"), (r"\bsweb site\b", "web site"), (r"\bsmigration\b", "migration")]


_DICT: set[str] | None = None


def _dict() -> set[str]:
    global _DICT
    if _DICT is None:
        try:
            _DICT = {w.strip() for w in open("/usr/share/dict/words", encoding="utf-8", errors="replace") if w.strip().islower()}
        except OSError:
            _DICT = set()
    return _DICT


def _strip_s(m: re.Match) -> str:
    w = m.group(2)
    return f"{m.group(1)} {w[1:]}" if w not in _dict() and w[1:] in _dict() else m.group(0)


def propers_of(script_text: str) -> set[str]:
    caps, low = set(), set()
    for m in re.finditer(r"\b([A-Za-z][A-Za-z]+)\b", script_text):
        w = m.group(1)
        before = script_text[:m.start()].rstrip()
        sent_start = not before or before[-1] in ".?!\"" 
        if w[0].isupper() and not sent_start and w != "I":
            caps.add(w.lower())
        elif w[0].islower():
            low.add(w)
    words = _dict()
    return {w for w in caps if w not in low and w not in words} | set(PROPER_EXTRA)


ASR_FIX = [("emperor s image", "emperor's image"), ("spartina s roots", "spartina's roots"), ("re create", "recreate"), ("re creating", "recreating"),
           ("fa t tissue", "fat tissue"), ("filed research", "field research"), ("What is the professor imply", "What does the professor imply"),
           ("What is professor imply", "What does the professor imply"), ("about incident that", "about the incident that"), ("Method s of", "Methods of"), ("example s of", "examples of")]


def fix_q(t: str, propers: set[str], vocab: set[str] = frozenset()) -> str:
    for a, b in ASR_FIX:
        t = t.replace(a, b)
    for pat, rep in CI_FIX:
        t = re.sub(pat, rep, t, flags=re.I)
    t = re.sub(r"\b(\w+s') ?(s[a-z]{4,})\b", _strip_s, t)
    t = re.sub(r"\bhailey's comet\b", "Halley's comet", t, flags=re.I)
    t = re.sub(r"\b(the|The) (Professor|Registrar|Student|Man|Woman)\b", lambda m: m.group(1) + " " + m.group(2).lower(), t)
    t = GLUE.sub(lambda m: _unglue(m, vocab), t)
    t = re.sub(r"\b(is|does|did|of|about) professor's", r"\1 the professor's", t)
    t = re.sub(r"\bprofessor's", lambda m: m.group(0), t)
    t = re.sub(r"\b([a-z][a-z]+)\b", lambda m: m.group(1).capitalize() if m.group(1) in propers else m.group(1), t)
    return t[:1].upper() + t[1:]


def write_emit_report(out, rej, per_batch) -> None:
    rp = ROOT / ".ingest/reports/toeflqa.md"
    base = rp.read_text(encoding="utf-8").split("\n## Emit")[0] if rp.exists() else ""
    allr = [r for v in out.values() for r in v]
    L = ["", "## Emit", f"- emitted: {({t: len(v) for t, v in out.items()})}", *(f"- {k}: {v}" for k, v in sorted(rej.items())),
         "", "### Per batch (rows / rejected / questions dropped / emitted / reject rate)"]
    for b, c in sorted(per_batch.items()):
        L.append(f"- {b}: {c['rows']} / {c['rejected']} / {c['q dropped']} / {c['emitted']} / {c['rejected'] / max(1, c['rows']):.0%}")
    L += ["", f"- cefr: {dict(Counter((r['type'], r['cefr']) for r in allr))}",
          f"- questions per item: {dict(Counter(len(r['questions']) for r in allr))}",
          f"- answer positions: {dict(Counter(q['answer'] for r in allr for q in r['questions']))}",
          "", "## Emit sample (30, seeded)", ""]
    for r in random.Random(11).sample(allr, min(30, len(allr))):
        sc = r["script"] if isinstance(r["script"], str) else "\n".join(f"{x['speaker']}: {x['line']}" for x in r["script"])
        L += [f"### `{r['id']}` [{r['cefr']}] {r['title']}", sc, ""]
        L += [f"- {q['q']} -> **{q['options'][q['answer']]}** ({q['explanation']})" for q in r["questions"]] + [""]
    rp.write_text(base + "\n".join(L), encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["fetch", "extract", "emit"])
    ap.add_argument("--raw", default=".ingest/raw/toeflqa")
    ap.add_argument("--stage", default=".ingest/stage/toeflqa")
    a = ap.parse_args()
    {"fetch": lambda: fetch(ROOT / a.raw), "extract": lambda: extract(ROOT / a.raw, ROOT / a.stage),
     "emit": lambda: emit_step(ROOT / a.stage)}[a.cmd]()


if __name__ == "__main__":
    main()
