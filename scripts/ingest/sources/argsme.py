"""C12: webis/args_me (CC BY 4.0) -> writeDiscussion (opinion, proscons) and interview rows.

Commands: fetch | extract (writes the LLM batch files) | emit (reads batches/*.filled.jsonl); run with python -I.

args-me.jsonl (886 MB) is read by HTTP Range slices only. One row = one argument: conclusion (a point headline,
or the debate title), premises[0].text, stance (PRO/CON relative to context.discussionTitle, the motion).
Layout of the file: debate.org (0-~831 MB, informal), idebate (~831-848 MB), debatewise (~848-870 MB),
debatepedia (~870-886 MB). Slices below were chosen from that layout.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib import cefr, dedupe, ids, textnorm, workplace  # noqa: E402

SOURCE = "argsme"
URL = "https://huggingface.co/datasets/webis/args_me/resolve/main/args-me.jsonl"
API = "https://huggingface.co/api/datasets/webis/args_me"
README = "https://huggingface.co/datasets/webis/args_me/raw/main/README.md"
LICENSE = "CC BY 4.0"
# (file, first byte, last byte). Slices are read as data; the first and last line of each are partial and dropped.
SLICES = [
    # head.bin (first 4 MB, debate.org) was fetched and inspected: informal, off-topic, typo-ridden; not used.
    ("idebate.bin", 831_000_000, 849_000_000),
    ("debatewise.bin", 849_000_000, 870_000_000),
]
BATCH_SIZE = 48
TARGETS = {"opinion": 220, "proscons": 110, "interview": 110}   # ~20% above the 200/100/100 needed (LLM rejects)
BUCKET_CAP = 40           # max motions per topic bucket, so there are not 30 "school" items
ARG_MIN, ARG_MAX = 28, 72  # words of a kept verbatim argument excerpt

PROF = ["Dr. Rivera", "Prof. Chen", "Dr. Okafor", "Prof. Alvarez", "Dr. Patel", "Prof. Lindqvist", "Dr. Brooks",
        "Prof. Nakamura", "Dr. Flores", "Prof. Murphy", "Dr. Santos", "Prof. Weber", "Dr. Kim", "Prof. Dubois",
        "Dr. Haddad", "Prof. Novak", "Dr. Ferreira", "Prof. Adeyemi", "Dr. Larsen", "Prof. Moreau", "Dr. Singh",
        "Prof. Costa", "Dr. Ivanova", "Prof. Reyes"]
NAMES_A = ["Maya", "Lucia", "Sara", "Nina", "Chloe", "Elena", "Ana", "Hannah", "Isabel", "Paula", "Mia", "Julia",
           "Rosa", "Alicia", "Priya", "Emma", "Laura", "Hana", "Tara", "Sofia", "Grace", "Leila", "Marta", "Iris"]
NAMES_B = ["Tomas", "Ben", "Jake", "Omar", "Ryan", "Marcus", "Leo", "Victor", "Kevin", "Greg", "Sam", "Daniel",
           "Tyler", "Peter", "Ian", "Noah", "Adam", "Kenji", "Hugo", "Raul", "Felix", "Ahmed", "Diego", "Oscar"]

# ---------------------------------------------------------------- filters
# Topics we want (any hit gives the motion a bucket and a score) ...
TOPIC_BUCKETS = {
    "work": r"work\w*|job|jobs|employ\w*|wage\w*|salary|salaries|labou?r|business\w*|compan\w*|corporat\w*|startup\w*|"
            r"unions?|workplace|career\w*|retire\w*|outsourc\w*|boss\w*|manag\w*|entrepreneur\w*|profit\w*",
    "technology": r"technolog\w*|internet|online|social media|facebook|twitter|computer\w*|software|digital|robot\w*|"
                  r"artificial intelligence|automat\w*|smartphone\w*|phone\w*|video games?|gaming|surveillance|data|"
                  r"privacy|cyber\w*|web|piracy|copyright\w*|patent\w*|drones?",
    "education": r"school\w*|student\w*|universit\w*|college\w*|educat\w*|teacher\w*|homework|exams?|curricul\w*|"
                 r"tuition|textbook\w*|learning|degree\w*|academic\w*|uniforms?",
    "cities": r"cit(?:y|ies)|urban|transport\w*|traffic|bicycl\w*|bikes?|cycling|public transit|housing|rent|"
              r"commut\w*|parking|congestion|metro|trains?|airports?|tourism|tourist\w*|olympic\w*|stadium\w*",
    "health": r"health\w*|hospital\w*|doctor\w*|medic\w*|obes\w*|diet\w*|exercise|sleep|fitness|nutrition|vaccin\w*|"
              r"food|junk food|sugar|fast food|sports?|pharmac\w*|drugs? companies",
    "economy": r"econom\w*|trade|tariff\w*|tax(?:es)?|market\w*|inflation|bank\w*|financ\w*|invest\w*|currency|debt|"
               r"austerity|poverty|income|wealth|subsid\w*|minimum wage|consumer\w*|advertis\w*|brand\w*|insurance",
    "environment": r"environment\w*|climate|energy|renewable\w*|solar|recycl\w*|pollut\w*|plastic\w*|carbon|emission\w*|"
                   r"organic|farming|agricultur\w*",
}
BUCKET_RE = {k: re.compile(r"\b(?:%s)\b" % v, re.I) for k, v in TOPIC_BUCKETS.items()}
BUCKET_WEIGHT = {"work": 3, "technology": 3, "education": 2.5, "cities": 2.5, "health": 2.5, "economy": 2.5, "environment": 1.5}

# ... and divisive / sensitive / adult content we never want, in the motion or in either argument.
BLOCK = re.compile(r"""\b(
 abortion\w*|pro-?life|pro-?choice|religio\w*|god|gods|church\w*|christian\w*|islam\w*|muslim\w*|jew\w*|jesus|bible|
 quran|koran|allah|atheis\w*|theis\w*|pray\w*|sin|sins|sinful|hell|heaven|satan\w*|spiritual\w*|creationis\w*|evolution|
 gay|gays|lesbian\w*|homosexual\w*|transgender\w*|lgbt\w*|same-sex|gender\w*|feminis\w*|sexis\w*|sex|sexual\w*|
 prostitut\w*|porn\w*|rape\w*|rapist\w*|erotic\w*|nude|naked|brothel\w*|pedophil\w*|incest\w*|
 racis\w*|racial|racist\w*|slave\w*|nazi\w*|hitler|holocaust|genocide\w*|apartheid|fascis\w*|communis\w*|marxis\w*|
 terror\w*|war|wars|warfare|military|army|armies|soldier\w*|invasion|invade\w*|occupation|nuclear|weapon\w*|bomb\w*|
 guns?|firearm\w*|rifle\w*|torture\w*|kill\w*|murder\w*|death|dead|die|dies|suicid\w*|euthanasia|execut\w*|
 capital punishment|assassinat\w*|violen\w*|assault\w*|abus\w*|victim\w*|crim\w*|prison\w*|jail\w*|police|
 trump|obama|clinton|bush|biden|putin|netanyahu|morsi|assad|gaddafi|castro|chavez|mubarak|erdogan|
 democrat\w*|republican\w*|liberal\w*|conservative\w*|tory|tories|labour party|congress|senate\w*|parliament\w*|
 election\w*|voting|vote|votes|voters?|presidential|referendum|monarch\w*|secession|independence|sovereign\w*|
 israel\w*|palestin\w*|gaza|hamas|iran\w*|iraq\w*|syria\w*|afghan\w*|pakistan\w*|egypt\w*|libya\w*|ukrain\w*|russia\w*|
 korea\w*|kosovo|tibet\w*|taiwan\w*|kashmir|crimea|chechn\w*|sudan|darfur|rwanda|zimbabwe|venezuela\w*|cuba\w*|
 immigra\w*|migrant\w*|refugee\w*|asylum|border\w*|deport\w*|illegal aliens?|burqa|niqab|hijab|veil\w*|circumcis\w*|
 marijuana|cannabis|cocaine|heroin|meth|addict\w*|drunk|alcohol\w*|drugs?|tobacco|smok\w*|cigarette\w*|
 pregnan\w*|contracepti\w*|condom\w*|abort\w*|embryo\w*|stem cell\w*|clon\w*|eugenic\w*|genetic\w*|
 fuck\w*|shit\w*|damn|bitch\w*|ass|asshole|dick|cock|pussy|cunt|slut|whore|retard\w*|fag\w*|nigg\w*|
 lol|lmao|stupid|idiot\w*|moron\w*|dumb|sucks?|crap|hate|hated|hatred|bigot\w*|nuts|insane|sick|disgust\w*|
 wikileaks|snowden|secret\w*|propaganda|dictator\w*|regime\w*|coup|protest\w*|riot\w*|rebel\w*|revolution\w*|
 sanction\w*|nato|united nations|un|eu|brexit|european union|zionis\w*|colonial\w*|empire\w*|
 star wars|batman|pokemon|anime|manga|survivor|justin bieber|ronaldo|messi|lebron|jar jar|lord of the rings|
 mountain dew|coke|pepsi|santa|tooth fairy|zombie\w*|vampire\w*|alien\w*|ghost\w*|magic|unicorn\w*|dragon\w*
)\b""", re.I | re.X)
# Debate-speak and references that only make sense inside the original debate.
DEBATE_SPEAK = re.compile(r"\b(opponent\w*|proposition|opposition|motion|rebuttal\w*|rebut\w*|round|rounds|forfeit\w*|"
                          r"my (?:first|second|third|last) |this debate|the debate|debater\w*|con|pro|vote|"
                          r"readers?|judges?|resolved|resolution|sources?|thanks|thank|hello|hi|welcome|"
                          r"first of all|my argument|our argument|my case|our case|as (?:stated|mentioned|said)|"
                          r"previous\w*|above|below|aforementioned|point (?:one|two|three|\d)|contention\w*|"
                          r"wikipedia|http\w*|www|dot com|\.com|\.org|lol|ok|okay|yeah|yes|nope|btw|imo|etc)\b", re.I)
BAD_START = re.compile(r"^(?:however|but|also|and|so|thus|therefore|furthermore|moreover|in addition|yet|because|"
                       r"this|these|those|that|such|it|its|they|them|their|he|she|his|her|there|then|firstly|secondly|"
                       r"thirdly|finally|next|first|second|third|as a result|in conclusion|in fact|indeed|"
                       r"on the other hand|on the contrary|instead|rather|even|if so|no|yes|well|now|you|your|"
                       r"another|other|one of|some of|many of|both|either|neither|each)\b", re.I)
RE_NOISE = re.compile(r"https?:|www\.|\[|\]|\{|\}|<|>|\||\*|_|\\|/|@|#|&|=|\+|~|\^|\d{5,}|\(\s*\)|\.{3,}|!{2,}|\?{2,}|"
                      r"\b(?:fig|ref|vs|et al|e\.g|i\.e|cf|ibid|ch|sec|pp?|no)\.", re.I)
STOP = set("""a an the of in on at to for and or but is are was were be been being should would could can may might must
will shall do does did have has had not no that this these those it its as by with from into than then so such there
their they them we our us you your i my me he she his her who whom which what when where why how all any some more most
less least very much many few other another own same too also just about over under up down out off again further once
only both each between against during before after above below should""".split())


def content_words(s: str) -> set[str]:
    return {w for w in re.findall(r"[a-z]+", s.lower()) if w not in STOP and len(w) > 2}


# ---------------------------------------------------------------- fetch
def _http(url: str, rng: tuple[int, int] | None = None, timeout: int = 120) -> bytes:
    h = {"User-Agent": "tenaz-ingest"}
    if rng:
        h["Range"] = f"bytes={rng[0]}-{rng[1]}"
    with urllib.request.urlopen(urllib.request.Request(url, headers=h), timeout=timeout) as r:
        return r.read()


def verify_license() -> None:
    api = json.loads(_http(API))
    tags = api.get("tags", [])
    card = (api.get("cardData") or {}).get("license")
    readme = _http(README).decode("utf-8", "replace")
    ok = ("license:cc-by-4.0" in tags or card == ["cc-by-4.0"] or card == "cc-by-4.0") and "CC BY 4.0" in readme
    if not ok:
        raise SystemExit(f"LICENSE MISMATCH, stopping: tags={tags} card={card}")
    print("license verified: cc-by-4.0 tag + README 'Creative Commons Attribution 4.0 International (CC BY 4.0)'")


def fetch(raw: Path) -> None:
    verify_license()
    raw.mkdir(parents=True, exist_ok=True)
    for name, a, b in SLICES:
        out = raw / name
        if out.exists() and out.stat().st_size >= b - a:
            continue
        for attempt in range(5):
            try:
                out.write_bytes(_http(URL, (a, b), timeout=300))
                break
            except Exception as e:  # noqa: BLE001 - network retry
                print(f"retry {name} {attempt}: {e}", file=sys.stderr)
        else:
            raise SystemExit(f"failed {name}")
        print(f"fetched {name} {out.stat().st_size} bytes")


# ---------------------------------------------------------------- extract
def read_slice(path: Path, first: bool) -> list[dict]:
    lines = path.read_bytes().decode("utf-8", "replace").split("\n")
    lines = lines[:-1]                 # last line is cut mid-row
    if not first:
        lines = lines[1:]              # first line starts mid-row
    out = []
    for l in lines:
        try:
            d = json.loads(l)
            out.append({"id": d["id"], "conclusion": d["conclusion"], "stance": d["premises"][0]["stance"],
                        "text": d["premises"][0]["text"], "motion": d["context"]["discussionTitle"],
                        "url": d["context"]["sourceUrl"], "debate": d["context"]["sourceId"].split("-")[0]
                        if "-" in d["context"]["sourceId"] else d["context"]["sourceId"]})
        except (json.JSONDecodeError, KeyError, IndexError):
            continue
    return out


def _unknown_words(s: str) -> int:
    from wordfreq import zipf_frequency
    n = 0
    for i, w in enumerate(re.findall(r"[A-Za-z']+", s)):
        w = w.strip("'")
        if len(w) > 2 and w.islower() and zipf_frequency(w, "en") < 1.8:
            n += 1
    return n


def clean_motion(m: str) -> str | None:
    m = re.sub(r"\s+", " ", textnorm.fix_unicode(m)).strip()
    wc = textnorm.word_count(m)
    if wc < 4 or wc > 22 or RE_NOISE.search(m) or '"' in m or "'" in m.replace("'s", "") and m.count("'") > 1:
        return None
    if re.search(r"[^\x20-\x7e]", m) or m.isupper() or re.search(r"\b(?:debate|vs|versus|resolved|dbate|test)\b", m, re.I):
        return None
    if _unknown_words(m):
        return None
    m = m[0].upper() + m[1:]
    if not re.search(r"[.?!]$", m):
        m += "" if m.endswith("?") else ""
    return m.rstrip(".")


def clean_argument(text: str) -> tuple[str | None, str | None]:
    """-> (excerpt, reject reason). 1-3 whole sentences, verbatim apart from whitespace; tries each sentence as a start."""
    t = textnorm.fix_unicode(text)
    t = re.sub(r"\s+", " ", t).strip()
    sents = textnorm.split_sentences(t)
    why = "too short"
    for i, first in enumerate(sents[:6]):
        if BAD_START.match(first) or textnorm.word_count(first) < 6:
            why = "bad start"
            continue
        out: list[str] = []
        for s in sents[i:]:
            wc = textnorm.word_count(" ".join(out + [s]))
            if wc > ARG_MAX:
                break
            out.append(s)
            if wc >= ARG_MIN + 6:
                break
        ex = " ".join(out)
        wc = textnorm.word_count(ex)
        if wc < ARG_MIN:
            why = "too short"
            continue
        if RE_NOISE.search(ex):
            why = "noise/citation"
            continue
        if not re.search(r"[.!?]$", ex) or not re.match(r"[A-Z]", ex):
            why = "bad sentence shape"
            continue
        if re.search(r"[^\x20-\x7e]", ex):
            why = "non-ascii"
            continue
        if ex.count('"') % 2 or ex.count("(") != ex.count(")"):
            why = "unbalanced quotes/brackets"
            continue
        if re.search(r"\b[A-Z]{4,}\b", ex):
            why = "shouting"
            continue
        if DEBATE_SPEAK.search(ex):
            why = "debate-speak"
            continue
        if re.search(r"\b(?:i|we)\b", ex, re.I) and re.search(r"\b(?:will|shall|am|argue|believe|contend|think)\b", ex[:60], re.I):
            why = "debater voice"
            continue
        if _unknown_words(ex) > 0:
            why = "typo/unknown word"
            continue
        return ex, None
    return None, why


def topic_bucket(motion: str, texts: list[str]) -> tuple[str | None, float]:
    best, score = None, 0.0
    for k, rx in BUCKET_RE.items():
        n = len(rx.findall(motion))
        n2 = sum(len(rx.findall(t)) for t in texts)
        s = (2 * n + 0.5 * min(n2, 3)) * BUCKET_WEIGHT[k]
        if n and s > score:
            best, score = k, s
    return best, score


def existing_signatures(root: Path) -> list[tuple[str, set[str]]]:
    """Content words of every existing prompt-like text (professor, topic, prompt, situation) for topic-level dedupe."""
    sigs = []
    for f in sorted((root / "items").glob("*.json")):
        try:
            rows = json.loads(f.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, FileNotFoundError):
            continue
        for r in rows:
            if r.get("type") in ("writeDiscussion", "interview", "lifeParagraph", "writeEmail"):
                s = " ".join(str(r.get(k, "")) for k in ("professor", "topic", "prompt", "situation"))
                cw = content_words(s)
                if cw:
                    sigs.append((r["id"], cw))
    return sigs


def extract(raw: Path, stage: Path, report: Path) -> None:
    stage.mkdir(parents=True, exist_ok=True)
    (stage / "batches").mkdir(exist_ok=True)
    report.parent.mkdir(parents=True, exist_ok=True)
    rej: Counter = Counter()
    rows: list[dict] = []
    for name, a, _ in SLICES:
        p = raw / name
        if p.exists():
            rows += [dict(r, slice=name) for r in read_slice(p, first=False)]
    n_rows = len(rows)

    # group by (debate, motion)
    groups: dict[tuple[str, str], list[dict]] = defaultdict(list)
    for r in rows:
        groups[(r["debate"], r["motion"])].append(r)
    n_motions = len(groups)

    idx = dedupe.DedupeIndex.from_content(Path("Content"))
    sigs = existing_signatures(Path("Content"))
    cands = []
    for (debate, motion), args in groups.items():
        cm = clean_motion(motion)
        if cm is None:
            rej["motion: shape/length/typo"] += 1
            continue
        if BLOCK.search(cm):
            rej["motion: blocklist (divisive/sensitive/off-topic)"] += 1
            continue
        pools = {"PRO": [], "CON": []}
        for a in args:
            if a["stance"] not in pools:
                continue
            ex, why = clean_argument(a["text"])
            if not ex:
                rej["arg: " + why] += 1
                continue
            if BLOCK.search(ex) or BLOCK.search(a["conclusion"] or ""):
                rej["arg: blocklist"] += 1
                continue
            conc = textnorm.fix_unicode(a["conclusion"] or "").strip()
            pools[a["stance"]].append({"argId": a["id"], "conclusion": conc if conc.lower() != motion.lower() else "",
                                       "text": ex})
        if not pools["PRO"] or not pools["CON"]:
            rej["motion: no clean PRO+CON pair"] += 1
            continue

        def pick(lst):
            return min(lst, key=lambda x: (abs(textnorm.word_count(x["text"]) - 46), x["argId"]))
        pro, con = pick(pools["PRO"]), pick(pools["CON"])
        if len(content_words(pro["text"]) & content_words(con["text"])) / max(1, len(content_words(pro["text"]))) > 0.6:
            rej["motion: PRO and CON excerpts overlap"] += 1
            continue
        bucket, tscore = topic_bucket(cm, [pro["text"], con["text"]])
        if bucket is None:
            rej["motion: off preferred topics"] += 1
            continue
        cw = content_words(cm)
        dup = next((i for i, s in sigs if len(cw & s) / max(1, len(cw)) >= 0.6 and len(cw) >= 2), None)
        if dup:
            rej["dedupe: motion vs existing prompt"] += 1
            continue
        both = pro["text"] + " " + con["text"]
        if idx.check(pro["text"]) or idx.check(con["text"]):
            rej["dedupe: argument text vs Content"] += 1
            continue
        wp = workplace.score(cm + " " + both)
        cands.append({"debate": debate, "motion": cm, "rawMotion": motion, "bucket": bucket,
                      "score": round(tscore + 6 * wp, 3), "workplace": round(wp, 3), "pro": pro, "con": con,
                      "cefr": cefr.estimate(both), "url": args[0]["url"], "slice": args[0]["slice"], "cw": sorted(cw)})
    n_pairs = len(cands)

    # near-duplicate motions within the run, then bucket caps
    cands.sort(key=lambda c: (-c["score"], c["debate"]))
    kept, per_bucket, seen = [], Counter(), []
    for c in cands:
        cw = set(c["cw"])
        if any(len(cw & s) / max(1, min(len(cw), len(s))) >= 0.6 for s in seen):
            rej["dedupe: near-duplicate motion in this run"] += 1
            continue
        if per_bucket[c["bucket"]] >= BUCKET_CAP:
            rej["bucket cap"] += 1
            continue
        per_bucket[c["bucket"]] += 1
        seen.append(cw)
        kept.append(c)

    # Roles: every kept motion gets one writeDiscussion row (opinion or proscons, ~2:1; proscons prefers policy-style
    # motions) and the top-scoring motions also get an interview row. Both rows of a motion share `group`.
    kept = kept[:TARGETS["opinion"] + TARGETS["proscons"]]
    n_pc = min(TARGETS["proscons"], len(kept) // 3)
    policy = [i for i, c in enumerate(kept) if re.search(r"\b(should|ban|banned|allow|allowed|legal|require|required|"
                                                          r"introduce|replace|reduce|increase|encourage|subsidi\w+)\b",
                                                          c["motion"], re.I)]
    proscons_idx = set(policy[:n_pc])
    plan = [(c, "proscons" if i in proscons_idx else "opinion") for i, c in enumerate(kept)]
    plan += [(c, "interview") for c in kept[:TARGETS["interview"]]]
    out_rows = []
    for c, role in plan:
        key = f"{c['debate'][:8]}-{ids.slug(c['motion'])[:40]}"
        h = int(hashlib.sha256(key.encode()).hexdigest(), 16)
        typ = "interview" if role == "interview" else "writeDiscussion"
        iid = ids.item_id(typ, SOURCE, f"{role}-{key}")
        row = {
            "id": iid, "rowType": role, "type": typ, "sourceId": f"{c['debate']}:{ids.slug(c['motion'])[:60]}",
            "group": f"argsme:{ids.sha8(c['debate'] + c['motion'])}",
            "motion": c["motion"], "bucket": c["bucket"], "guessCefr": c["cefr"], "workplace": c["workplace"],
            "pro": {"conclusion": c["pro"]["conclusion"], "text": c["pro"]["text"]},
            "con": {"conclusion": c["con"]["conclusion"], "text": c["con"]["text"]},
            "sourceUrl": c["url"],
            "fixed": {"type": typ, "skill": "writing" if typ == "writeDiscussion" else "speaking",
                      "kind": role if typ == "writeDiscussion" else "interview",
                      "minWords": 100 if typ == "writeDiscussion" else None, "source": SOURCE, "license": LICENSE,
                      "tier": "permissive", "origin": "adapted" if typ == "writeDiscussion" else "generated"},
        }
        if typ == "writeDiscussion":
            row["names"] = {"professor": PROF[h % len(PROF)], "studentA": NAMES_A[(h >> 8) % len(NAMES_A)],
                            "studentB": NAMES_B[(h >> 16) % len(NAMES_B)]}
        else:
            row["fixed"].pop("minWords")
        out_rows.append(row)

    # dedupe ids against all of Content
    existing_ids = set(idx.ids)
    out_rows = [r for r in out_rows if r["id"] not in existing_ids]

    with (stage / "candidates.jsonl").open("w", encoding="utf-8") as f:
        for r in out_rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    # batches of 40-60 rows, shuffled by role so that each batch mixes the three row types evenly
    out_rows.sort(key=lambda r: ids.sha8(r["id"]))
    for old in (stage / "batches").glob("*.jsonl"):
        old.unlink()
    nb = max(1, round(len(out_rows) / BATCH_SIZE))
    paths = []
    for b in range(nb):
        chunk = out_rows[b::nb]
        p = stage / "batches" / f"batch-{b + 1:02d}.jsonl"
        p.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in chunk), encoding="utf-8")
        paths.append(p)
    stats = {"argument_rows": n_rows, "debates": n_motions, "motions_with_clean_pair_and_topic": n_pairs,
             "after_run_dedupe_and_caps": len(kept), "staged": len(out_rows),
             "by_role": dict(Counter(r["rowType"] for r in out_rows)), "by_bucket": dict(Counter(r["bucket"] for r in out_rows)),
             "batches": [str(p) for p in paths], "rejects": dict(rej)}
    (stage / "extract-stats.json").write_text(json.dumps(stats, indent=1))
    _report(report, stats, out_rows)
    print(json.dumps({k: v for k, v in stats.items() if k != "rejects"}, indent=1))


def _assign_roles(kept: list[dict]) -> list[str]:
    """Top motions by score -> spread over the three roles in the target proportions (interleaved, so quality is even).
    proscons prefers 'should ...' / policy motions; interview takes the rest of the interleave."""
    n = len(kept)
    total = sum(TARGETS.values())
    quota = {k: round(n * v / total) for k, v in TARGETS.items()}
    quota["opinion"] += n - sum(quota.values())
    policy = [i for i, c in enumerate(kept) if re.search(r"\b(should|ban|banned|allow|allowed|legal|require|required|"
                                                          r"introduce|replace|reduce|increase|encourage|subsidi\w+)\b",
                                                          c["motion"], re.I)]
    roles = [None] * n
    for i in policy:
        if quota["proscons"] and roles[i] is None and len(policy) > 0:
            roles[i] = "proscons"
            quota["proscons"] -= 1
    for i in range(n):
        if roles[i] is None:
            order = ["interview", "opinion", "opinion"]
            for r in order + ["proscons"]:
                if quota.get(r, 0) > 0:
                    roles[i] = r
                    quota[r] -= 1
                    break
            else:
                roles[i] = "opinion"
    return roles


def _report(report: Path, stats: dict, rows: list[dict]) -> None:
    import random
    rnd = random.Random(12)
    sample = rnd.sample(rows, min(30, len(rows)))
    lines = ["# argsme (C12) report", "",
             f"License checked at {API}: tag `license:cc-by-4.0` and README line 'Creative Commons Attribution 4.0 International (CC BY 4.0)'.",
             "Stage only: LLM fill (professor/student posts, interview questions) pending; no Content/ file written yet.", "",
             "## Counts"]
    for k in ("argument_rows", "debates", "motions_with_clean_pair_and_topic", "after_run_dedupe_and_caps", "staged"):
        lines.append(f"- {k}: {stats[k]}")
    lines += [f"- by role: {stats['by_role']}", f"- by topic bucket: {stats['by_bucket']}", "", "## Reject reasons"]
    lines += [f"- {k}: {v}" for k, v in sorted(stats["rejects"].items(), key=lambda kv: -kv[1])]
    lines += ["", "## 30 random staged rows", ""]
    for r in sample:
        lines.append(f"- `{r['id']}` [{r['rowType']}, {r['bucket']}, {r['guessCefr']}] {r['motion']}")
        lines.append(f"    - PRO: {r['pro']['text']}")
        lines.append(f"    - CON: {r['con']['text']}")
    report.write_text("\n".join(lines) + "\n", encoding="utf-8")


# ---------------------------------------------------------------- emit
TOPIC_MAP = {"work": "workplace", "career": "workplace", "careers": "workplace", "business": "workplace",
             "economics": "economy", "finance": "economy", "tax": "economy", "city": "cities", "urban life": "cities",
             "transport": "cities", "housing": "cities", "sports": "sport", "study": "education", "research": "education",
             "marketing": "economy", "advertising": "economy", "consumers": "economy"}
DROP_TOPICS = {"politics", "law", "ethics", "international", "global"}
LEVELS = {"B1", "B1+", "B2", "B2+", "C1"}
# Dropped after reading the sample: student B drifts off the motion (paperless classroom instead of phones).
MANUAL_DROP = {"wd-argsme-proscons-61e00511-should-the-cell-phones-be-allowed-in-sch"}
WD_LIMITS = {"professor": (25, 75), "studentA": (22, 70), "studentB": (22, 70)}


def _wc(s: str) -> int:
    return len(re.findall(r"[A-Za-z0-9']+", s))


def emit(stage: Path, report: Path) -> None:
    from lib import emit as lib_emit, schema
    batches = sorted(p for p in (stage / "batches").glob("batch-*.jsonl") if not p.name.endswith(".filled.jsonl"))
    cand = {}
    for l in (stage / "candidates.jsonl").read_text(encoding="utf-8").splitlines():
        r = json.loads(l)
        cand[r["id"]] = r
    for name in ("write-discussion-argsme.json", "interview-argsme.json"):   # rewritten below; keep them out of dedupe
        (Path("Content/items") / name).unlink(missing_ok=True)
    idx = dedupe.DedupeIndex.from_content(Path("Content"))
    wd_rows, iv_rows = [], []
    rej: Counter = Counter()
    per_batch = []
    for b in batches:
        fp = b.with_name(b.stem + ".filled.jsonl")
        if not fp.exists():
            raise SystemExit(f"missing {fp}")
        src_ids = [json.loads(l)["id"] for l in b.read_text(encoding="utf-8").splitlines()]
        filled = [json.loads(l) for l in fp.read_text(encoding="utf-8").splitlines()]
        if [f["id"] for f in filled] != src_ids:
            raise SystemExit(f"{fp.name}: ids do not match the input batch")
        n_llm_rej = 0
        for f in filled:
            if f.get("reject"):
                n_llm_rej += 1
                continue
            c = cand[f["id"]]
            fixed = c["fixed"]
            if f["id"] in MANUAL_DROP:
                rej["manual drop after sample read"] += 1
                continue
            topics = []
            for t in f.get("topics", []):
                t = TOPIC_MAP.get(t.lower(), t.lower())
                if t not in topics:
                    topics.append(t)
            if DROP_TOPICS & set(topics):
                rej["topic politics/law/ethics"] += 1
                continue
            if f["cefr"] not in LEVELS:
                rej["bad cefr"] += 1
                continue
            item = {"id": f["id"], "type": c["type"], "cefr": f["cefr"], "skill": fixed["skill"], "kind": fixed["kind"]}
            if c["type"] == "writeDiscussion":
                ok = True
                for k in ("professor", "studentA", "studentB"):
                    t = (f.get(k) or "").strip()
                    name = c["names"][k]
                    if not (t.startswith(name + ":") or t.startswith(name.split()[-1] + ":")
                            or (k != "professor" and t.startswith(name.split()[0] + ":"))):
                        ok = False
                    lo, hi = WD_LIMITS[k]
                    if not lo <= _wc(t) <= hi or BLOCK.search(t) or "\n" in t or RE_NOISE.search(t):
                        ok = False
                    item[k] = t
                if not ok:
                    rej["writeDiscussion: name/length/blocklist"] += 1
                    continue
                item["minWords"] = fixed["minWords"]
            else:
                topic = (f.get("topic") or "").strip()
                qs = [q.strip() for q in f.get("questions", [])]
                if not 2 <= _wc(topic) <= 6 or len(qs) != 4 or any(not 7 <= _wc(q) <= 26 or not q.endswith(("?", ".")) for q in qs):
                    rej["interview: topic/questions shape"] += 1
                    continue
                if BLOCK.search(topic + " " + " ".join(qs)) or len(set(qs)) != 4:
                    rej["interview: blocklist/duplicate question"] += 1
                    continue
                item["topic"], item["questions"] = topic, qs
            item.update({"source": SOURCE, "sourceId": c["sourceId"], "license": LICENSE, "tier": "permissive",
                         "group": c["group"], "origin": fixed["origin"], "topics": topics})
            probs = schema.problems_item(item)
            if probs:
                rej["schema: " + probs[0][:50]] += 1
                continue
            why = idx.check_and_add(item["id"], dedupe.item_text(item))
            if why:
                rej["dedupe: " + why[:30]] += 1
                continue
            (wd_rows if c["type"] == "writeDiscussion" else iv_rows).append(item)
        per_batch.append((b.name, len(filled), n_llm_rej))

    kw = dict(source="args.me (webis/args_me)", url="https://huggingface.co/datasets/webis/args_me", license=LICENSE,
              tier="permissive",
              attribution="Ajjour et al. 2019, webis/args_me (CC BY 4.0); posts and questions adapted/generated from idebate/debatewise arguments")
    lib_emit.emit(Path("Content"), "items", "write-discussion-argsme.json", wd_rows, **kw)
    lib_emit.emit(Path("Content"), "items", "interview-argsme.json", iv_rows, **kw)
    _emit_report(report, per_batch, rej, wd_rows, iv_rows)
    print(json.dumps({"writeDiscussion": len(wd_rows), "interview": len(iv_rows), "rejects": dict(rej)}, indent=1))


def _emit_report(report: Path, per_batch, rej, wd_rows, iv_rows) -> None:
    import random
    txt = report.read_text(encoding="utf-8") if report.exists() else ""
    txt = txt.split("\n\n# argsme emit")[0].rstrip("\n")
    L = ["", "", "# argsme emit", "", "## LLM reject rate per batch (fill step)"]
    tot_n = tot_r = 0
    for name, n, r in per_batch:
        tot_n += n
        tot_r += r
        L.append(f"- {name}: {r}/{n} rejected ({100 * r / n:.0f}%){'  ABOVE 30%' if r / n > 0.3 else ''}")
    L.append(f"- total: {tot_r}/{tot_n} ({100 * tot_r / tot_n:.0f}%). Why: most rejects are rows where the PRO/CON excerpt "
             "argues the opposite side from its label (idebate excerpts drift from the point headline) or the motion is "
             "country-specific/sensitive; the filler rejected instead of inventing.")
    L += ["", "## Emit filters (after the LLM step)"] + [f"- {k}: {v}" for k, v in rej.items()]
    L += ["", "## Written",
          f"- Content/items/write-discussion-argsme.json: {len(wd_rows)} ({dict(Counter(r['kind'] for r in wd_rows))})",
          f"- Content/items/interview-argsme.json: {len(iv_rows)}",
          f"- cefr: {dict(Counter(r['cefr'] for r in wd_rows + iv_rows))}",
          f"- topics: {dict(Counter(t for r in wd_rows + iv_rows for t in r['topics']).most_common(15))}",
          "- origin: writeDiscussion adapted, interview generated"]
    rnd = random.Random(7)
    L += ["", "## 30 random emitted items", ""]
    for r in rnd.sample(wd_rows + iv_rows, min(30, len(wd_rows + iv_rows))):
        if r["type"] == "interview":
            L.append(f"- `{r['id']}` [{r['cefr']}] **{r['topic']}**: " + " / ".join(r["questions"]))
        else:
            L.append(f"- `{r['id']}` [{r['cefr']}, {r['kind']}]\n    - {r['professor']}\n    - {r['studentA']}\n    - {r['studentB']}")
    report.write_text(txt + "\n".join(L) + "\n", encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["fetch", "extract", "emit"])
    ap.add_argument("--raw", default=".ingest/raw/argsme")
    ap.add_argument("--stage", default=".ingest/stage/argsme")
    ap.add_argument("--report", default=".ingest/reports/argsme.md")
    a = ap.parse_args()
    if a.cmd == "fetch":
        fetch(Path(a.raw))
    elif a.cmd == "extract":
        extract(Path(a.raw), Path(a.stage), Path(a.report))
    else:
        emit(Path(a.stage), Path(a.report))


if __name__ == "__main__":
    main()
