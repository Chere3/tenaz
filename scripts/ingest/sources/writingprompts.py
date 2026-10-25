"""C13: euclaise/writingprompts (MIT tag) -> Content/items/life-story-wp.json (lifeParagraph kind "story").

Prompts only; stories are never kept. Commands: fetch | extract | emit  (run with python -I).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import time
import urllib.request
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib import cefr, dedupe, emit as emitlib, ids, textnorm, workplace  # noqa: E402

SOURCE = "wp"
ROWS_API = ("https://datasets-server.huggingface.co/rows?dataset=euclaise/writingprompts"
            "&config=default&split=train&offset={off}&length=100")
TRAIN_ROWS = 272600
N_PAGES = 100            # 100 pages x 100 rows, spread evenly over train
MIN_W, MAX_W = 12, 45
TARGET = 150
LEAD = "Continue this story in 40-60 words: "

# Hard blocklist (substring match on lowercase word stems): sexual, violence/gore, self-harm, politics, hate, drugs.
BLOCK = re.compile(r"""\b(
 sex\w*|nude|naked|porn\w*|erotic\w*|rape\w*|molest\w*|incest\w*|fetish\w*|horny|orgasm\w*|penis|vagina|boob\w*|breast\w*|
 kill\w*|murder\w*|massacre\w*|slaughter\w*|gore|gory|blood\w*|bleed\w*|corpse\w*|dead|death|die|dies|died|dying|
 suicid\w*|hang\w*|stab\w*|shoot\w*|shot|gun\w*|rifle|bomb\w*|terror\w*|war|wars|soldier\w*|battle\w*|weapon\w*|knife|
 torture\w*|tortur\w*|abus\w*|assault\w*|kidnap\w*|hostage\w*|victim\w*|serial|cannibal\w*|decapitat\w*|mutilat\w*|dismember\w*|
 genocide|holocaust|nazi\w*|hitler|slave\w*|racis\w*|racial|
 trump|obama|clinton|biden|president\w*|politic\w*|election\w*|democrat\w*|republican\w*|liberal\w*|conservative\w*|
 communis\w*|fascis\w*|government\w*|congress|senat\w*|vote|voted|voting|religio\w*|jesus|christ|god|gods|allah|satan\w*|
 demon\w*|devil\w*|hell|heaven|angel\w*|priest\w*|church|bible|
 drug\w*|cocaine|heroin|meth|addict\w*|drunk|alcohol\w*|suffer\w*|zombie\w*|apocalyp\w*|pregnan\w*|baby|babies|child|children|
 kid|kids|boy|girl|boys|girls|son|daughter|mommy|mom|dad|daddy|school\w*|teen\w*|virgin\w*|fuck\w*|shit\w*|damn|bitch\w*|
 masturbat\w*|nuke\w*|mug\w*|thie\w*|steal\w*|stole\w*|psych\w*|loincloth|humane\w*|mute|blind|crim\w*|police|cop|cops|prison\w*|jail\w*|insan\w*|torment\w*|smok\w*|cigarette\w*|sacrific\w*|cult|ritual\w*|lust\w*|lover\w*|ex|stalk\w*|creep\w*|naked|strip\w*|nuclear|arms|euthan\w*|hung|handicap\w*|assassin\w*|mental\w*|gentile|purgatory|underworld|styx|charon|disabled|disorder\w*|cancer|illness|suicide|ass|asshole|dick|cock|pussy|cunt|slut|whore|retard\w*|fag\w*|nigg\w*|r/\w+|reddit|edit|upvote\w*|op
)\b""", re.I | re.X)
# Meta-instructions, fandom/trademarks, and obvious typos/informal spelling.
META = re.compile(r"\b(write|writes|writing|written|story|stories|prompt|prompts|post|text field|fanfic\w*|sequel|chapter|"
                  r"hogwarts|harry|potter|skynet|pokemon|star wars|ww1|ww2|wwii|minecraft|disney|marvel|batman|superman|"
                  r"describe|explain|what happens|what do you do|cant|dont|wont|didnt|doesnt|isnt|im|ive|youre|thats|alot|wouldnt|couldnt|its a|u|ur|lol)\b", re.I)
# Fantasy / childish / sci-fi flavour: not forbidden, but ranked down hard (we want grounded, adult prompts).
FANTASY = re.compile(r"\b(dragon\w*|wizard\w*|witch\w*|magic\w*|elf|elves|orc\w*|fairy|fairies|unicorn\w*|goblin\w*|vampire\w*|"
                     r"werewol\w*|ghost\w*|alien\w*|superhero\w*|villain\w*|hero\w*|prince\w*|princess\w*|king|queen|kingdom|"
                     r"sword\w*|curse\w*|spell\w*|monster\w*|robot\w*|galaxy|planet\w*|spaceship\w*|supernatural|"
                     r"immortal\w*|reincarnat\w*|afterlife|grim|reaper)\b", re.I)
REALISTIC = re.compile(r"\b(office|boss|coworker\w*|colleague\w*|job|work|works|worked|working|interview\w*|meeting\w*|"
                       r"company|manager|customer\w*|client\w*|email\w*|phone|call|called|train|bus|airport|flight|"
                       r"restaurant|cafe|coffee|neighbou?r\w*|roommate\w*|landlord|apartment|house|home|city|town|street|"
                       r"friend\w*|wife|husband|date|dinner|lunch|birthday|wedding|trip|hotel|store|shop|bank|"
                       r"business|salary|promotion|retire\w*|resign\w*|fired|hired|deadline|project|team)\b", re.I)


def _get(url: str) -> bytes:
    for attempt in range(6):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "tenaz-ingest"}), timeout=60) as r:
                return r.read()
        except Exception as e:  # noqa: BLE001 - network retry
            print(f"retry {attempt}: {e}", file=sys.stderr)
            time.sleep(2 + 3 * attempt)
    raise SystemExit(f"failed: {url}")


def fetch(raw: Path) -> None:
    raw.mkdir(parents=True, exist_ok=True)
    out = raw / "prompts.jsonl"
    step = TRAIN_ROWS // N_PAGES
    n = 0
    with out.open("w", encoding="utf-8") as f:
        for i in range(N_PAGES):
            off = min(i * step, TRAIN_ROWS - 100)
            data = json.loads(_get(ROWS_API.format(off=off)))
            for r in data["rows"]:
                f.write(json.dumps({"row_idx": r["row_idx"], "prompt": r["row"]["prompt"]}, ensure_ascii=False) + "\n")
                n += 1
            time.sleep(0.3)
    print(f"fetched {n} prompts -> {out}")


def clean_opener(raw_prompt: str) -> str | None:
    p = raw_prompt.strip()
    p = re.sub(r"^\s*\[\s*[A-Za-z]{2}\s*\]\s*", "", p)  # [ WP ], [ TT ] ...
    if "[" in p or "]" in p:
        return None
    p = textnorm.detokenize(p)
    p = p.replace("`", "'")
    p = re.sub(r'(^|\s)\'\'', r'\1"', p)
    p = re.sub(r"\s+", " ", p).strip()
    p = textnorm.recapitalize(p)
    return p


def reject_reason(o: str | None) -> str | None:
    if o is None:
        return "brackets/tags"
    wc = textnorm.word_count(o)
    if wc < MIN_W or wc > MAX_W:
        return "length"
    if not re.match(r"[A-Z\"']", o):
        return "bad start"
    if not re.search(r"[.!?\"')]$", o):
        return "no end punctuation"
    if re.search(r"https?:|www\.|\*|_|\n|\d{4,}", o):
        return "url/markup/number"
    if re.search(r"[^\x20-\x7e]", o):
        return "non-ascii"
    if o.count('"') % 2:
        return "unbalanced quotes"
    if " ' " in o or re.search(r"\b\w+ ' \w+", o):
        return "tokenization leftover"
    if ".." in o.replace("...", "") or "(s)" in o:
        return "odd punctuation"
    if _typo(o):
        return "typo/unknown word"
    if META.search(o):
        return "meta/fandom/typo"
    m = BLOCK.search(o)
    if m:
        return f"blocklist:{m.group(1).lower()}"
    if re.search(r"\b(i|my|me)\b", o, re.I) and not re.search(r"\byou\b", o, re.I) and textnorm.word_count(o) < 14:
        return "too short first-person"
    return None


def _typo(o: str) -> bool:
    from wordfreq import zipf_frequency
    for i, w in enumerate(re.findall(r"[A-Za-z']+", o)):
        w = w.strip("'")
        if len(w) > 2 and (w.islower() or i == 0) and zipf_frequency(w.lower(), "en") < 1.8:
            return True
    return False


def appeal(o: str) -> float:
    s = workplace.score(o) * 3 + 0.6 * len(REALISTIC.findall(o))
    s -= 1.5 * len(FANTASY.findall(o))
    if re.search(r"\byou\b", o, re.I):
        s += 0.3
    if re.search(r"time[- ]travel|time machine", o, re.I):
        s -= 1.0
    wc = textnorm.word_count(o)
    if 18 <= wc <= 35:
        s += 0.4
    return s


def extract(raw: Path, stage: Path, report: Path) -> None:
    stage.mkdir(parents=True, exist_ok=True)
    report.parent.mkdir(parents=True, exist_ok=True)
    rows = [json.loads(l) for l in (raw / "prompts.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()]
    reasons: Counter = Counter()
    kept = []
    for r in rows:
        o = clean_opener(r["prompt"])
        why = reject_reason(o)
        if why:
            reasons[why.split(":")[0]] += 1
            reasons_detail[why] += 1
            continue
        kept.append({"sourceId": f"train-{r['row_idx']}", "opener": o, "appeal": round(appeal(o), 3)})
    with (stage / "candidates.jsonl").open("w", encoding="utf-8") as f:
        for k in kept:
            f.write(json.dumps(k, ensure_ascii=False) + "\n")
    stats = {"fetched": len(rows), "passed_hard_filters": len(kept), "rejects": dict(reasons)}
    (stage / "extract-stats.json").write_text(json.dumps(stats, indent=1))
    print(json.dumps(stats))


reasons_detail: Counter = Counter()

# Row indices (train split) kept after reading the top ~200 ranked candidates by hand: grounded or lightly
# speculative, adult, no crude humour, no typos, no fandom, no distressing themes. The automatic filters above
# are necessary but not sufficient (keyword blocklists leak), so emit only emits these.
CURATED = {f"train-{n}" for n in """19149 60052 43622 70908 30038 21906 54521 38221 24542 68202 46379 40897 43642 16444 40902 76392 81875 49114 62769 79127 43634 79144 84545 8214 19175 13716 35454 39 21893 27321 65462 54568 5491 40989 30071 84604 57301 76403 90053 13634 49106 65482 10925 73622 62782 30000 16373 19119 21880 30035 30082 32716 35462 46345 5488 59982 65516 76404 84518 84600 87 87311 89962 92728 92740 90029 59999 8222 51873 62774 73670 76369 32763 73698 81797 19104 24624 32771 62771 43632 84575 87257 27271 46355 84507 60019 13647 32734 24551 70951 73634 76373 84601 87250 35484 5459 57270 81785 70886 62713 16421 5485 57287 57328 54522 10975 89995 10940 76413 57283 8196 84542 40971 57343 62785""".split()}

MUSTUSE = [["as soon as"], ["even though"], ["by the time"], ["instead of"], ["in the end"], ["all of a sudden"],
           ["at first"], ["as if"], ["no matter what"], ["sooner or later"]]


def build_rows(stage: Path) -> tuple[list[dict], Counter]:
    cands = [json.loads(l) for l in (stage / "candidates.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()]
    cands.sort(key=lambda c: (-c["appeal"], c["sourceId"]))
    idx = dedupe.DedupeIndex.from_content(Path("Content"))
    rej: Counter = Counter()
    out: list[dict] = []
    for c in cands:
        if len(out) >= TARGET:
            break
        if c["sourceId"] not in CURATED:
            rej["not hand-curated"] += 1
            continue
        o = c["opener"]
        iid = ids.item_id("lifeParagraph", SOURCE, c["sourceId"])
        why = idx.check_and_add(iid, o)
        if why:
            rej["dedupe"] += 1
            continue
        h = int(hashlib.sha256(c["sourceId"].encode()).hexdigest(), 16)
        out.append({
            "id": iid, "type": "lifeParagraph", "cefr": cefr.estimate(o), "skill": "writing",
            "prompt": LEAD + o, "mustUse": MUSTUSE[h % len(MUSTUSE)], "minWords": 40,
            "source": SOURCE, "sourceId": c["sourceId"], "license": "MIT", "tier": "permissive",
            "kind": "story", "origin": "verbatim", "topics": ["story"],
        })
    out.sort(key=lambda r: r["id"])
    return out, rej


def emit(stage: Path, report: Path) -> None:
    # Other converters write into Content/ in parallel: lib globs can hit a file mid-delete/rewrite, so retry.
    for attempt in range(8):
        try:
            rows, rej = build_rows(stage)
            entry = _emit_rows(rows)
            break
        except (FileNotFoundError, json.JSONDecodeError) as e:
            print(f"retry after concurrent write: {e}", file=sys.stderr)
            time.sleep(1.5)
    else:
        raise SystemExit("emit kept racing with other writers")
    _report(stage, report, rows, rej, entry)


def _emit_rows(rows: list[dict]) -> dict:
    return emitlib.emit(Path("Content"), "items", "life-story-wp.json", rows, source="WritingPrompts (euclaise/writingprompts)",
                         url="https://huggingface.co/datasets/euclaise/writingprompts", license="MIT (HF dataset card; underlying text is Reddit r/WritingPrompts user content, so the MIT tag is the mirror's claim)",
                         tier="permissive", attribution="Fan et al. 2018, Hierarchical Neural Story Generation; euclaise/writingprompts (prompts only)")


def _report(stage: Path, report: Path, rows: list[dict], rej: Counter, entry: dict) -> None:
    import random
    ex = json.loads((stage / "extract-stats.json").read_text())
    rnd = random.Random(7)
    sample = rnd.sample(rows, min(30, len(rows)))
    lv = Counter(r["cefr"] for r in rows)
    lines = ["# writingprompts (C13) report", "",
             "License checked at https://huggingface.co/api/datasets/euclaise/writingprompts: tag `license:mit`, cardData license `mit`.", "",
             "## Counts", f"- rows fetched (35 of 100 planned pages, evenly spaced over train; the rows API returned HTTP 429 after that, which was enough): {ex['fetched']}",
             f"- passed hard filters (tags, 12-45 words, blocklist, hygiene): {ex['passed_hard_filters']}",
             f"- hard-filter rejects: {ex['rejects']}",
             f"- rejected after ranking: {dict(rej)}",
             f"- emitted: {len(rows)} (hand-curated from the top ~200 ranked candidates; see CURATED in the converter; dedupe rejects are repeated posts)", f"- CEFR distribution (weak lexical estimate): {dict(lv)}", "",
             "## 30 random emitted items", ""]
    for r in sample:
        lines.append(f"- `{r['id']}` [{r['cefr']}] {r['prompt']}")
    report.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"emitted {entry['items']}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["fetch", "extract", "emit"])
    ap.add_argument("--raw", default=".ingest/raw/writingprompts")
    ap.add_argument("--stage", default=".ingest/stage/writingprompts")
    ap.add_argument("--report", default=".ingest/reports/writingprompts.md")
    a = ap.parse_args()
    if a.cmd == "fetch":
        fetch(Path(a.raw))
    elif a.cmd == "extract":
        extract(Path(a.raw), Path(a.stage), Path(a.report))
    else:
        emit(Path(a.stage), Path(a.report))


if __name__ == "__main__":
    main()
