"""P4 converter: MuTual (Nealcly/MuTual, license unclear -> tier "unclear", *.nc.json) -> listenResponse.

  prompt = last speaker line of the (detokenized, recapitalized) dialogue, options = MuTual's 4 replies, key = answers.
  STAGED INCOMPLETE: a fill agent writes the explanation, restores capitalization of names/places, and blind-verifies
  that exactly one option is a natural reply to the prompt alone.

  fetch    checks the repo still has no license (stops if one appears), downloads data/mutual/{train,dev} into .ingest/raw/mutual/
  extract  filters, normalizes, dedupes against Content/, caps, writes .ingest/stage/mutual/listen-response.jsonl,
           the report and batches under .ingest/stage/mutual/batches/lr-NN.jsonl
  emit     merges lr-NN.filled.jsonl (verdict ok only) into Content/items/listen-response-mutual.nc.json

Run: uv run --project scripts/ingest python -I scripts/ingest/sources/mutual.py <cmd>
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
from concurrent.futures import ThreadPoolExecutor
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lib import cefr, emit as emitlib, ids, textnorm, workplace  # noqa: E402
from lib.dedupe import DedupeIndex  # noqa: E402

REPO = "Nealcly/MuTual"
API = f"https://api.github.com/repos/{REPO}"
RAW = f"https://raw.githubusercontent.com/{REPO}/master"
SPLITS = ("train", "dev")  # test has no public answers
SRC = "mutual"
CAP = 600
RESERVE = 1.6  # 60% extra rows flagged reserve=true: MuTual distractors are tricky, expect heavy fill-agent rejects
BATCH = 40

OFFENSIVE = set("""sex sexy sexual naked nude porn rape kill kills killed killing murder suicide die dies died dying dead
death drunk drug drugs cocaine heroin gun guns shoot shooting bomb terror terrorist war fuck shit damn bitch bastard ass
asshole crap hell idiot stupid dumb ugly fat hate sucks god jesus pregnant whore cancer racist nazi crazy insane
divorce divorced girlfriend boyfriend dating kiss kissed""".split())
CHILDISH = set("""mommy daddy toy toys kid kids baby babies puppy kitten cartoon cartoons disney santa teddy doll candy
balloon crayon toilet pee poop diaper naughty princess unicorn dragon monster fairy""".split())
BAD_CHARS = re.compile(r"[^A-Za-z0-9',.?!:$%&/ -]")
TURN = re.compile(r"(?:^|\s)([mf]) : ")
_W = re.compile(r"[a-z']+")


def _get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "tenaz-ingest"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def verify_license() -> dict:
    """MuTual has no LICENSE file and the GitHub API reports no license. Stop if that changed (the tier must be re-judged)."""
    meta = json.loads(_get(API))
    tree = json.loads(_get(f"{API}/git/trees/master?recursive=1"))
    lic_files = [t["path"] for t in tree["tree"] if re.search(r"(^|/)(licen[sc]e|copying)", t["path"], re.I)]
    out = {"api_license": meta.get("license"), "license_files": lic_files, "checked": str(date.today())}
    if meta.get("license") or lic_files:
        raise SystemExit(f"LICENSE CHANGED for {REPO}: {out}. Re-judge the tier before continuing.")
    return out


def fetch(raw: Path) -> None:
    lic = verify_license()
    print("no license at source (tier: unclear):", json.dumps(lic))
    raw.mkdir(parents=True, exist_ok=True)
    (raw / "LICENSE-CHECK.json").write_text(json.dumps(lic, indent=1) + "\n", encoding="utf-8")
    tree = json.loads(_get(f"{API}/git/trees/master?recursive=1"))
    paths = [t["path"] for t in tree["tree"] if t["type"] == "blob"
             and any(t["path"].startswith(f"data/mutual/{s}/") for s in SPLITS)]

    def one(p: str) -> None:
        dest = raw / p
        if dest.exists() and dest.stat().st_size > 0:
            return
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(_get(f"{RAW}/{p}"))

    with ThreadPoolExecutor(16) as ex:
        list(ex.map(one, paths))
    print("downloaded", len(paths), "files")


# --- normalization -------------------------------------------------------------------------------
def parse_article(article: str) -> list[tuple[str, str]]:
    """'m : hi . f : hello' -> [('m','hi .'), ('f','hello')]"""
    parts = TURN.split(" " + article.strip())
    # parts: ['', 'm', 'text', 'f', 'text', ...]
    return [(parts[i], parts[i + 1].strip()) for i in range(1, len(parts) - 1, 2)]


PROPER = re.compile(r"\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday|january|february|april|june|july|"
                    r"august|september|october|november|december|english|chinese|french|german|japanese|spanish|"
                    r"american|british|australian|canadian|european|china|america|australia|canada|london|beijing|"
                    r"england|france|germany|japan|paris|new york|christmas|internet)\b")
SCHOOLISH = re.compile(r"\b(homework|teacher|teachers|classmates?|senior|junior|grade|exam|exams|school|schoolbag|"
                       r"headmaster|principal|dormitory|students?|midterm|semester|campus|mum|mummy)\b", re.I)
BROKEN = re.compile(r"\b(gon na|wan na|got ta|mr\.|mrs\.|ms\.|mr |mrs |miss |o'clock o)", re.I)


def norm(s: str) -> str:
    s = textnorm.fix_unicode(s)
    s = textnorm.detokenize(s)
    s = re.sub(r"\bi\b", "I", s)
    s = PROPER.sub(lambda m: m.group(0).title(), s)  # standalone pronoun, incl. i'm / i'll after detokenize (apostrophe is a boundary)
    s = textnorm.recapitalize(s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def wc(s: str) -> int:
    return len(s.split())


def reject_text(*texts: str) -> str | None:
    for t in texts:
        low = set(_W.findall(t.lower()))
        if low & OFFENSIVE:
            return "offensive/sensitive word"
        if low & CHILDISH:
            return "childish word"
        if BAD_CHARS.search(t):
            return "odd characters"
        if re.search(r"\d{4,}", t):
            return "long digits"
    return None


def load_rows(raw: Path):
    for split in SPLITS:
        d = raw / "data" / "mutual" / split
        for fp in sorted(d.glob("*.txt")):
            try:
                yield split, json.loads(fp.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                continue


def candidate(split: str, o: dict, rej: Counter):
    key = o["id"]
    turns = parse_article(o["article"])
    ans = o.get("answers")
    if len(turns) < 2:
        rej["too few turns"] += 1
        return None
    if len(turns) > 4:
        rej["context > 4 turns (answer may need earlier context)"] += 1
        return None
    if ans not in "ABCD" or len(ans) != 1 or len(o["options"]) != 4:
        rej["no key / not 4 options"] += 1
        return None
    spk, last = turns[-1]
    opts = []
    for t in o["options"]:
        m = TURN.match(" " + t.strip())
        if not m:
            rej["option without speaker tag"] += 1
            return None
        if m.group(1) == spk:
            rej["option speaker = prompt speaker"] += 1
            return None
        opts.append(TURN.split(" " + t.strip(), 1)[2].strip())
    prompt = norm(last)
    options = [norm(t) for t in opts]
    if not 4 <= wc(prompt) <= 28:
        rej["prompt length"] += 1
        return None
    if any(not 3 <= wc(t) <= 24 for t in options):
        rej["option length"] += 1
        return None
    if len({textnorm.text_hash(t) for t in options}) != 4:
        rej["duplicate options"] += 1
        return None
    if BROKEN.search(" ".join([prompt] + options)):
        rej["tokenization/title artifact (gon na, mr.)"] += 1
        return None
    if SCHOOLISH.search(" ".join([prompt] + options)):
        rej["school-flavoured (not adult)"] += 1
        return None
    why = reject_text(prompt, *options)
    if why:
        rej[why] += 1
        return None
    if not prompt.rstrip().endswith(("?", ".", "!")):
        rej["prompt not a clean sentence"] += 1
        return None
    return {"key": key, "split": split, "turns": len(turns), "speaker": spk, "prompt": prompt,
            "options": options, "answer": "ABCD".index(ans), "context": [norm(t) for _, t in turns[:-1]]}


def score(c: dict) -> float:
    allt = " ".join([c["prompt"]] + c["options"])
    s = 2.0 * workplace.score(allt)
    s += {2: 1.0, 3: 0.5, 4: 0.0}[c["turns"]]  # fewer turns: the last line carries more of the meaning
    s += 0.5 if c["prompt"].endswith("?") else 0.0  # a question has a clearer set of fitting replies
    s += 0.1 * (int(hashlib.sha256(c["key"].encode()).hexdigest(), 16) % 10) / 10  # stable tie-break
    return s


def extract(raw: Path, stage: Path, report: Path, content: Path) -> None:
    rej: Counter = Counter()
    idx = DedupeIndex.from_content(content)
    cands = []
    total = 0
    for split, o in load_rows(raw):
        total += 1
        c = candidate(split, o, rej)
        if c:
            cands.append(c)
    cands.sort(key=lambda c: -score(c))
    target = int(CAP * RESERVE)
    rows = []
    for c in cands:
        if len(rows) >= target:
            break
        iid = ids.item_id("listenResponse", SRC, c["key"])
        if idx.check_and_add(iid, c["prompt"]):
            rej["dedupe vs Content/ or earlier pick"] += 1
            continue
        txt = " ".join([c["prompt"]] + c["options"])
        rows.append({
            "id": iid, "type": "listenResponse", "cefr": cefr.estimate(txt, "B1+"), "skill": "listening",
            "voice": "male" if c["speaker"] == "m" else "female",
            "prompt": c["prompt"], "options": c["options"], "answer": c["answer"],
            "context": c["context"],  # fill-agent aid only; dropped at emit
            "topics": ["workplace"] if workplace.score(txt) > 0.15 else ["daily-life"],
            "group": f"mutual:{c['key']}", "source": SRC, "sourceId": c["key"],
            "license": "No license stated (unclear)", "tier": "unclear", "origin": "adapted",
            "reserve": len(rows) >= CAP,
        })
    stage.mkdir(parents=True, exist_ok=True)
    (stage / "listen-response.jsonl").write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows), encoding="utf-8")
    bdir = stage / "batches"
    bdir.mkdir(exist_ok=True)
    for old in bdir.glob("lr-*.jsonl"):
        if ".filled." not in old.name:
            old.unlink()
    random.Random(7).shuffle(rows)
    nb = max(1, round(len(rows) / BATCH))
    size = -(-len(rows) // nb)
    batches = []
    for i in range(nb):
        chunk = rows[i * size:(i + 1) * size]
        if chunk:
            p = bdir / f"lr-{i + 1:02d}.jsonl"
            p.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in chunk), encoding="utf-8")
            batches.append(p)
    L = ["# mutual extract report", "", f"- dialogues read (train+dev): {total}", f"- candidates after filters: {len(cands)}",
         f"- staged rows: {len(rows)} (cap {CAP} + reserve)", f"- cefr: {dict(Counter(r['cefr'] for r in rows))}",
         f"- topics: {dict(Counter(r['topics'][0] for r in rows))}", "", "## Reject reasons", ""]
    L += [f"- {k}: {v}" for k, v in rej.most_common()]
    L += ["", "## Batches", ""] + [f"- {b}" for b in batches] + ["", "## Sample (30)", ""]
    for r in random.Random(1).sample(rows, min(30, len(rows))):
        L.append(f"- [{r['cefr']}] {r['prompt']} -> {r['options'][r['answer']]}")
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text("\n".join(L) + "\n", encoding="utf-8")
    print(f"staged {len(rows)} rows, {len(batches)} batches")


# --- emit ----------------------------------------------------------------------------------------
EMIT_DROP = {"context", "reserve", "verdict", "rejectReason", "fixed"}


MANUAL_DROP = {"lr-mutual-train-6580"}
NAME_FIX = re.compile(r"\b(tom|mary|david|sam|lily|jack|jane)\b")


def fix_names(t: str) -> str:
    return NAME_FIX.sub(lambda m: m.group(1).title(), t)


def emit_cmd(stage: Path, report: Path, content: Path) -> None:
    from lib import schema  # noqa: E402
    rej: Counter = Counter()
    per_batch = []
    staged = {}
    for line in (stage / "listen-response.jsonl").read_text(encoding="utf-8").splitlines():
        if line.strip():
            r = json.loads(line)
            staged[r["id"]] = r
    out_name = "listen-response-mutual.nc.json"
    cand = []
    for fp in sorted((stage / "batches").glob("lr-*.filled.jsonl")):
        n = ok = 0
        for line in fp.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            n += 1
            r = json.loads(line)
            if r.get("verdict") != "ok":
                rej["verdict " + str(r.get("verdict"))] += 1
                continue
            st = staged.get(r.get("id"))
            if st is None:
                rej["id not staged"] += 1
                continue
            if st["answer"] != r.get("answer"):
                rej["answer key changed by fill agent"] += 1
                continue
            if not (r.get("explanation") or "").strip():
                rej["no explanation"] += 1
                continue
            o = r.get("options") or []
            if len(o) != 4 or len({textnorm.text_hash(x) for x in o}) != 4:
                rej["options not 4 distinct"] += 1
                continue
            if r["id"] in MANUAL_DROP:
                rej["manual drop after sample read (confusing explanation)"] += 1
                continue
            ok += 1
            it = {k: v for k, v in r.items() if k not in EMIT_DROP}
            it["prompt"] = fix_names(it["prompt"])
            it["options"] = [fix_names(x) for x in it["options"]]
            it["origin"] = "adapted"
            it["tier"] = "unclear"
            cand.append(it)
        per_batch.append((fp.name, n, ok))
    # dedupe against everything else in Content/ (own file excluded) and within this batch
    import tempfile, shutil
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td) / "Content"
        shutil.copytree(content, tmp, ignore=shutil.ignore_patterns(out_name))
        idx = DedupeIndex.from_content(tmp)
    items = []
    for it in cand:
        why = idx.check_and_add(it["id"], it["prompt"])
        if why:
            rej["dedupe: " + why] += 1
            continue
        bad = schema.problems_item(it)
        if bad:
            rej["schema: " + bad[0]] += 1
            continue
        items.append(it)
    if len(items) > CAP:
        rej[f"over cap {CAP}"] += len(items) - CAP
        items = items[:CAP]
    emitlib.emit(content, "items", out_name, items, source="MuTual",
                 url="https://github.com/Nealcly/MuTual", license="No license stated (unclear); treated as research-only",
                 tier="unclear", attribution="Cui et al. 2020, MuTual: A Dataset for Multi-Turn Dialogue Reasoning (ACL), "
                 "Nealcly/MuTual; explanations written with Claude")
    L = ["", "## Emit", "", f"- items emitted: {len(items)} -> Content/items/{out_name}", "",
         "### Reject rate per batch (ok / total)", ""]
    L += [f"- {n}: {ok}/{t} ok ({100 * (t - ok) // max(t, 1)}% reject)" for n, t, ok in per_batch]
    L += ["", "### Filter counts", ""] + [f"- {k}: {v}" for k, v in rej.most_common()]
    L += ["", f"- cefr: {dict(Counter(i['cefr'] for i in items))}",
          f"- topics: {dict(Counter(i['topics'][0] for i in items))}",
          f"- voice: {dict(Counter(i['voice'] for i in items))}",
          f"- answer position: {dict(sorted(Counter(i['answer'] for i in items).items()))}", "",
          "### Random sample (30)", ""]
    for i in random.Random(3).sample(items, min(30, len(items))):
        L.append(f"- [{i['cefr']}] {i['prompt']} -> {i['options'][i['answer']]}  (expl: {i['explanation']})")
    prev = report.read_text(encoding="utf-8") if report.exists() else ""
    prev = prev.split("\n## Emit")[0].rstrip("\n")
    report.write_text(prev + "\n" + "\n".join(L) + "\n", encoding="utf-8")
    print("emitted", len(items), dict(rej))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["fetch", "extract", "emit"])
    ap.add_argument("--raw", default=".ingest/raw/mutual")
    ap.add_argument("--stage", default=".ingest/stage/mutual")
    ap.add_argument("--report", default=".ingest/reports/mutual.md")
    ap.add_argument("--content", default="Content")
    a = ap.parse_args()
    if a.cmd == "fetch":
        fetch(Path(a.raw))
    elif a.cmd == "extract":
        extract(Path(a.raw), Path(a.stage), Path(a.report), Path(a.content))
    else:
        emit_cmd(Path(a.stage), Path(a.report), Path(a.content))


if __name__ == "__main__":
    main()
