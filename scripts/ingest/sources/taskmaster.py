"""C06 + C07 converter: Taskmaster-1/2 (Google, CC BY 4.0) and MultiWOZ 2.2 (pfb30/multi_woz_v22, Apache-2.0).

Produces three item types from task-oriented dialogues:
  * listenResponse     prompt = a spoken question/request, correct reply = the real next turn.
                       STAGED INCOMPLETE: 3 wrong replies + explanation are still to be written by an LLM.
  * listenConversation 8-14 line excerpts (A/B). STAGED INCOMPLETE: title, questions, explanations by an LLM.
                       MultiWOZ rows already carry 0-2 detail questions whose distractors are built from other
                       dialogues' slot values (the LLM only writes their explanations).
  * buildSentence      context = previous turn, answer = a 6-14 word reply, 5-8 chunks cut by rule. Complete.

  fetch    verifies the license at the source (stops on mismatch), then downloads into .ingest/raw/taskmaster/
  extract  filters, normalizes, dedupes against Content/, selects, writes .ingest/stage/taskmaster/*.jsonl,
           .ingest/reports/taskmaster.md and the LLM batches under .ingest/stage/taskmaster/batches/
  emit     merges the *.filled.jsonl batches (verdict ok only), re-checks, dedupes, writes Content/items/<type>-<source>.json
           (+ licenses.json entries) and appends the emit section to the report

Run: uv run --project scripts/ingest python -I scripts/ingest/sources/taskmaster.py <cmd>
"""
from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import random
import re
import sys
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lib import cefr, ids, textnorm, workplace  # noqa: E402
from lib.dedupe import DedupeIndex, item_text  # noqa: E402

GH = "https://raw.githubusercontent.com/google-research-datasets/Taskmaster/master"
HF = "https://huggingface.co"
PQ = f"{HF}/datasets/pfb30/multi_woz_v22/resolve/refs%2Fconvert%2Fparquet/v2.2"
TM1_FILES = {"tm1/self-dialogs.json": f"{GH}/TM-1-2019/self-dialogs.json",
             "tm1/woz-dialogs.json": f"{GH}/TM-1-2019/woz-dialogs.json"}
TM2_DOMAINS = ["flights", "food-ordering", "hotels", "movies", "music", "restaurant-search", "sports"]
TM2_FILES = {f"tm2/{d}.json": f"{GH}/TM-2-2020/data/{d}.json" for d in TM2_DOMAINS}
MW_FILES = {"mw/train.parquet": f"{PQ}/train/0000.parquet", "mw/validation.parquet": f"{PQ}/validation/0000.parquet"}

SRC_TM, SRC_MW = "taskmaster", "multiwoz"
LIC = {SRC_TM: "CC BY 4.0", SRC_MW: "Apache-2.0"}
TARGETS = {"lr": 600, "lc": 200, "bs": 600}
# soft per-source split (the other source fills what one cannot supply)
SPLIT_MW = {"lr": 0.30, "lc": 0.30, "bs": 0.30}
LEISURE_CAP = 0.30
RESERVE = 1.2  # stage 20% extra rows, flagged reserve=true (lowest ranked), to absorb LLM rejects

# domain -> (workplace-ish weight, topic label, leisure?)
DOMAINS = {
    "auto-repair": (1.0, "appointments", False), "auto-repair-appt": (1.0, "appointments", False),
    "hotels": (0.9, "travel", False), "flights": (0.9, "travel", False),
    "uber-lyft": (0.6, "transport", False), "coffee-ordering": (0.6, "orders", False),
    "pizza-ordering": (0.6, "orders", False), "food-ordering": (0.7, "orders", False),
    "restaurant-table": (0.3, "dining", True), "restaurant-search": (0.3, "dining", True),
    "movie-tickets": (0.1, "entertainment", True), "movie-ticket": (0.1, "entertainment", True),
    "movie": (0.1, "entertainment", True), "movies": (0.1, "entertainment", True),
    "music": (0.1, "entertainment", True), "sports": (0.1, "entertainment", True),
    "train": (0.8, "travel", False), "taxi": (0.7, "transport", False), "hotel": (0.8, "travel", False),
    "hospital": (0.6, "appointments", False), "police": (0.3, "services", False),
    "bus": (0.7, "transport", False), "attraction": (0.2, "entertainment", True),
    "restaurant": (0.3, "dining", True),
}

# --- blocklists / regexes ---------------------------------------------------------------------
OFFENSIVE = set("""sex sexy sexual naked nude porn rape kill kills killed killing murder suicide die dies died dying dead
death drunk drug drugs cocaine heroin weed gun guns shoot shooting bomb terror terrorist war fuck fucking fuck shit
damn bitch bastard ass asshole crap hell idiot stupid dumb ugly fat hate sucks suck god jesus pregnant hooker whore
cancer racist nazi crazy insane""".split())
CHILDISH = set("""mommy daddy toy toys kid kids baby babies puppy kitten cartoon cartoons disney pokemon santa teddy doll
candy balloon crayon toilet pee poop diaper naughty princess unicorn dragon monster fairy""".split())
NO_APOS = set("""im dont cant thats wont didnt doesnt isnt youre theres ive ill id hes shes wasnt couldnt wouldnt shouldnt
havent arent werent hasnt theyre whats wheres hows hadnt lets thatll itll youll youd youve weve wed""".split())
SLANG = set("pls plz thx thanx thnx ty ur u r k kk ya lol haha omg btw tbh idk imo tho cuz coz".split())
FILLERS = {"um", "uh", "umm", "uhm", "erm", "er", "uhh", "hmm", "hm", "mmm", "mm", "huh"}
DAYS_MONTHS = set("""Monday Tuesday Wednesday Thursday Friday Saturday Sunday January February March April May June July
August September October November December OK I""".split())
PRIVACY = re.compile(r"\b(my name|name is|named|under the name|last name|first name|phone number|phone|email|e-mail|"
                     r"zip|password|credit card|card number|account number|social security|address is)\b|@|https?:|www\.",
                     re.I)
BAD_CHARS = re.compile(r"[^A-Za-z0-9',.?!:$%&/ -]")
LONG_DIGITS = re.compile(r"\d{4,}")
PROMPT_ANAPH = re.compile(r"\b(it|they|them|those|these|that one|this one|the same|the first|the second|the last|"
                          r"the other|which one|he|she|his|her)\b", re.I)
REPLY_ANAPH = re.compile(r"\b(they|them|those|these|the same|the first|the second|the last|the other|that one|"
                         r"this one|he|she|his|her)\b", re.I)
OPEN_PROMPT = re.compile(r"(how are you|how can i help|what can i (do|help)|anything else|is there anything|"
                         r"how may i|can i help you|help you today)", re.I)
LEAD_CONJ = re.compile(r"^(and|so|also|but|then|or|because|well|anyway|ok so|okay so)\b", re.I)
ASSISTANT_STILT = re.compile(r"\b(reference|booking (was|is) successful|i have (booked|found|made)|i was able to|"
                             r"i've (booked|found|made)|there are \w+ (options|results|restaurants|hotels|trains)|"
                             r"i'm sorry,? but there|your order has been)\b", re.I)
QSTART = re.compile(r"^(can|could|would|do|does|did|will|what|when|where|which|who|whom|whose|why|how|is|are|was|were|"
                    r"have|has|should|shall|may|might|please|let me know)\b", re.I)
WH_OR_AUX = re.compile(r"^(can|could|would|do|does|did|will|what|when|where|which|who|why|how|is|are|was|were|have|"
                       r"has|should|shall|may)\b", re.I)
_TOK = re.compile(r"[A-Za-z]+(?:'[A-Za-z]+)?")
SCHEDULING = re.compile(r"\b(appointment|schedule|reschedule|book|booking|reservation|reserve|available|availability|"
                        r"time|when|date|delivery|deliver|pick ?up|arrive|leave|order)\b", re.I)

AUX = set("""am is are was were be been being have has had do does did will would can could should shall may might must
'm 's 're 've 'll 'd""".split())
VERBISH = AUX | set("""want need like book send check let make get find see know think help go take give tell call order
schedule confirm pick come look try start leave arrive prefer love work use change cancel move pay add show bring
appreciate recommend suggest mean wait hope feel say ask meet join stay reserve ship deliver sound sounds works
happen happens seem seems please thanks thank fine good great perfect sure ready""".split())


def _hash_int(s: str) -> int:
    return int(hashlib.sha256(s.encode()).hexdigest(), 16)


def pick_voice(key: str) -> str:
    return "female" if _hash_int(key) % 2 == 0 else "male"


def _zipf(w: str) -> float:
    from wordfreq import zipf_frequency
    return max(zipf_frequency(w, "en"), zipf_frequency(w.split("'")[0], "en") if "'" in w else 0.0)


# --- fetch ------------------------------------------------------------------------------------
def _get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "tenaz-ingest"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def verify_licenses() -> dict:
    """Stop (SystemExit) unless the source still says CC BY 4.0 (Taskmaster) and Apache-2.0 (MultiWOZ)."""
    out = {}
    for repo, want in (("google-research-datasets/taskmaster1", "license:cc-by-4.0"),
                       ("google-research-datasets/taskmaster2", "license:cc-by-4.0"),
                       ("pfb30/multi_woz_v22", "license:apache-2.0")):
        tags = json.loads(_get(f"{HF}/api/datasets/{repo}"))["tags"]
        out[repo] = [t for t in tags if t.startswith("license:")]
        if want not in tags:
            raise SystemExit(f"LICENSE MISMATCH for {repo}: expected {want}, HF tags {out[repo]}. Stopping.")
    for name in ("TM-1-2019", "TM-2-2020"):
        readme = _get(f"{GH}/{name}/README.md").decode("utf-8", "replace")
        if "Creative Commons Attribution 4.0" not in readme:
            raise SystemExit(f"LICENSE MISMATCH: {name}/README.md does not state CC BY 4.0. Stopping.")
        out[name + "/README.md"] = "Creative Commons Attribution 4.0 License"
    return out


def fetch(raw: Path) -> None:
    lic = verify_licenses()
    print("licenses verified:", json.dumps(lic))
    raw.mkdir(parents=True, exist_ok=True)
    (raw / "LICENSE-CHECK.json").write_text(json.dumps(lic, indent=1) + "\n", encoding="utf-8")
    for rel, url in {**TM1_FILES, **TM2_FILES, **MW_FILES}.items():
        dest = raw / rel
        if dest.exists() and dest.stat().st_size > 0:
            continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        print("downloading", url)
        tmp = dest.with_suffix(dest.suffix + ".part")
        with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "tenaz-ingest"}), timeout=300) as r, \
                open(tmp, "wb") as f:
            while chunk := r.read(1 << 20):
                f.write(chunk)
        tmp.rename(dest)


# --- text normalization -----------------------------------------------------------------------
class Reject(Exception):
    pass


def norm_turn(raw: str, *, digits: str = "none", strict_case: bool = True, caps_ok: bool = False) -> tuple[str, bool]:
    """Clean one turn. Returns (text, changed) where `changed` means capitalisation/punctuation had to be repaired.

    digits: none | few (<=3 digit numbers, times, prices). Raises Reject(reason).
    strict_case=False lets chat-style lowercase/unpunctuated turns be repaired instead of rejected.
    caps_ok: capitalised words mid-sentence (names, brands) are allowed (conversation lines).
    """
    s = textnorm.fix_unicode(raw).strip()
    s = re.sub(r"\s+", " ", s)
    s = re.sub(r"\s+([,.?!:])", r"\1", s)
    if not s:
        raise Reject("empty")
    if BAD_CHARS.search(s):
        raise Reject("chars")
    if ".." in s or "--" in s or re.search(r"(.)\1{3,}", s):
        raise Reject("ellipsis-or-repeat")
    toks = _TOK.findall(s)
    low = [t.lower() for t in toks]
    if any(t in FILLERS for t in low):
        raise Reject("disfluency")
    if any(t in NO_APOS for t in low) or any(t in SLANG for t in low):
        raise Reject("typo-slang")
    if any(a == b and len(a) > 1 for a, b in zip(low, low[1:])):
        raise Reject("repeated-word")
    if any(t in OFFENSIVE for t in low):
        raise Reject("offensive")
    if any(t in CHILDISH for t in low):
        raise Reject("childish")
    if LONG_DIGITS.search(s):
        raise Reject("long-digits")
    if digits == "none" and re.search(r"\d", s):
        raise Reject("digits")
    if re.search(r"\d", s) and not re.fullmatch(r"[^\d]*(?:(?:\$?\d{1,3}(?:[:.]\d{2})?|\d{1,2}(?:st|nd|rd|th)?)[^\d]*)*", s):
        raise Reject("digits")
    for t in toks:
        if t.isupper() and len(t) > 1 and t not in ("OK", "TV", "US", "UK", "AM", "PM"):
            raise Reject("allcaps")
    changed = False
    letters = [c for c in s if c.isalpha()]
    if not letters:
        raise Reject("no-letters")
    if s[0].islower() or re.search(r"\bi\b", s):
        if strict_case:
            raise Reject("case")
        changed = True
    if s[-1] not in ".?!":
        if strict_case:
            raise Reject("no-terminal-punct")
        changed = True
    s2 = textnorm.recapitalize(s)
    if s2 != s:
        if strict_case and re.search(r"[.!?]\s+[a-z]", s):
            changed = True  # inner sentence started lowercase: repaired, flagged
        changed = True
        s = s2
    if s[-1] not in ".?!":
        s += "?" if WH_OR_AUX.match(s) else "."
    toks_sp = s.split()
    for i, t in enumerate(toks_sp):
        core = re.sub(r"[^A-Za-z']", "", t)
        if not core:
            continue
        cap_mid = i > 0 and core[0].isupper() and toks_sp[i - 1][-1] not in ".?!" and core not in DAYS_MONTHS \
            and core not in ("I", "OK") and not core.startswith("I'")
        if cap_mid and not caps_ok:
            raise Reject("proper-noun")
        zl = _zipf(core.lower())
        if zl < (2.0 if not cap_mid else 2.4):
            raise Reject("rare-or-typo")
    return s, changed


def wc(s: str) -> int:
    return len(s.split())


# --- chunker (rule-based; spaCy is not in the project deps) -----------------------------------
DET = set("a an the my your his her our their this that these those some any no every each another many much few".split())
PREP = set("to in on at for with from by of about after before until around into over under between through during "
           "without within near across".split())
WH = set("what when where which who whom whose why how".split())
CONJ = set("and but so because if while although since unless".split())
MOVABLE = set("please actually probably tomorrow today tonight now then also just still really maybe sometimes "
              "usually again".split())
SUBJ = set("i you we they he she it there".split())
FUNC = DET | PREP | WH | CONJ | SUBJ | AUX | MOVABLE | set("not n't too very as than".split())


def _core(t: str) -> str:
    return re.sub(r"[^a-z']", "", t.lower())


def glue(a: str, b: str, i: int) -> int:
    """Strength of keeping tokens a|b together (0 = cut here, 3 = never cut). i = index of a."""
    ac, bc = _core(a), _core(b)
    if a[-1] in ",;":
        return 0
    if bc in ("not", "n't") or bc.startswith("n't"):
        return 3
    if bc in MOVABLE and i + 1 > 0:
        return 3
    if ac in MOVABLE and i == 0:
        return 3
    if ac in DET or ac in PREP or ac in WH:
        return 3
    if ac in CONJ:
        return 3
    is_aux = ac in AUX or ("'" in ac and ac.split("'")[-1] in ("m", "s", "re", "ve", "ll", "d"))
    if is_aux:
        return 2 if bc not in SUBJ and bc not in DET else 1
    if ac in SUBJ and (bc in AUX or bc not in FUNC):
        return 2
    if ac not in FUNC and bc not in FUNC:
        return 2
    if ac not in FUNC and (bc in PREP or bc in CONJ or bc in DET or bc in SUBJ):
        return 0
    return 1


def make_chunks(answer: str, seed: str) -> list[str] | None:
    toks = answer.split()
    n = len(toks)
    k = min(8, max(5, -(-n // 2)))
    if n < k:
        return None
    g = [glue(toks[i], toks[i + 1], i) for i in range(n - 1)]
    best, best_cost = None, 1e9
    target = n / k
    for cuts in itertools.combinations(range(n - 1), k - 1):
        bounds = (-1, *cuts, n - 1)
        lens = [bounds[j + 1] - bounds[j] for j in range(k)]
        if max(lens) > 5:
            continue
        cost = 3 * sum(g[c] for c in cuts) + sum((l - target) ** 2 for l in lens)
        if cost < best_cost:
            best, best_cost = lens, cost
    if best is None:
        return None
    chunks, p = [], 0
    for l in best:
        chunks.append(" ".join(toks[p:p + l]))
        p += l
    rng = random.Random(seed)
    for _ in range(30):
        sh = chunks[:]
        rng.shuffle(sh)
        if sh != chunks:
            return sh
    return None


# --- loading ----------------------------------------------------------------------------------
def domain_info(key: str) -> tuple[float, str, bool]:
    return DOMAINS.get(key, (0.3, "services", False))


def load_tm(raw: Path):
    """yield dict(tag, convId, domain, turns=[(speaker 0/1, text)], ver)."""
    specs = [("tm1s", raw / "tm1/self-dialogs.json", None), ("tm1w", raw / "tm1/woz-dialogs.json", None)]
    specs += [("tm2", raw / f"tm2/{d}.json", d) for d in TM2_DOMAINS]
    for tag, path, dom in specs:
        if not path.exists():
            continue
        for d in json.loads(path.read_text(encoding="utf-8")):
            domain = dom or d["instruction_id"].rsplit("-", 1)[0]
            turns = [(0 if u["speaker"] == "USER" else 1, u["text"]) for u in d["utterances"]]
            yield {"src": SRC_TM, "tag": tag, "convId": d["conversation_id"], "domain": domain, "turns": turns}


BOOK_SLOTS = {
    "restaurant-booktime": "At what time does the customer want the table?",
    "restaurant-food": "What kind of food does the customer ask for?",
    "train-leaveat": "What time does the customer want the train to leave?",
    "train-arriveby": "By what time does the customer want to arrive?",
    "taxi-leaveat": "What time does the customer want the taxi to leave?",
    "taxi-arriveby": "By what time does the customer want to arrive?",
    "taxi-destination": "Where does the customer want to go?",
    "taxi-departure": "Where does the customer want to be picked up?",
}
STATE_SLOTS = {
    "restaurant-bookday": "On which day is the table booked?",
    "restaurant-bookpeople": "For how many people is the table booked?",
    "hotel-bookday": "On which day does the hotel stay start?",
    "hotel-bookpeople": "For how many people is the hotel booked?",
    "hotel-bookstay": "For how many nights is the hotel booked?",
}
TIME_RE = re.compile(r"^\d{2}:\d{2}$")


def load_mw(raw: Path):
    import pyarrow.parquet as pq
    for split in ("train", "validation"):
        path = raw / f"mw/{split}.parquet"
        if not path.exists():
            continue
        for r in pq.read_table(path).to_pylist():
            tu = r["turns"]
            turns, spans = [], []
            for i, u in enumerate(tu["utterance"]):
                spk = int(tu["speaker"][i])
                fr = tu["frames"][i]
                sp = []
                for s in fr["slots"]:
                    if s["slot"] and s["value"]:
                        sp.append((s["slot"][0], s["value"][0]))
                turns.append((spk, u))
                spans.append(sp)
            # cumulative state at each turn: {slot: value}
            states = []
            for i in range(len(turns)):
                st = {}
                for f in tu["frames"][i]["state"]:
                    sv = f.get("slots_values") or {}
                    for nm, vals in zip(sv.get("slots_values_name", []), sv.get("slots_values_list", [])):
                        if vals:
                            st[nm] = vals[0]
                states.append(st)
            svc = [s for s in r["services"] if s]
            yield {"src": SRC_MW, "tag": "mw", "convId": r["dialogue_id"].replace(".json", ""), "domain": svc[0] if svc else "",
                   "services": svc, "turns": turns, "spans": spans, "states": states}


# --- candidate builders -----------------------------------------------------------------------
def dlg_short(d: dict) -> str:
    if d["src"] == SRC_TM:
        return d["convId"].replace("dlg-", "")[:8]
    return d["convId"].lower()


def dlg_weight(d: dict) -> tuple[float, str, bool]:
    if d["src"] == SRC_MW:
        infos = [domain_info(s) for s in d["services"]] or [domain_info("")]
        return max(i[0] for i in infos), infos[0][1], all(i[2] for i in infos)
    return domain_info(d["domain"])


def reply_cefr(text: str) -> str:
    return cefr.estimate(text)


LVL_BONUS = {"B1": 0.0, "B1+": 0.3, "B2": 0.6, "B2+": 0.6, "C1": 0.4}


def base_score(d: dict, text: str, lvl: str, changed: bool, extra: float = 0.0, key: str = "") -> float:
    w, _, _ = dlg_weight(d)
    return (2.0 * w + 3.0 * workplace.score(text) + LVL_BONUS[lvl] + (0.0 if changed else 0.3) + extra
            + (_hash_int(key) % 1000) / 1e5)


def topics_for(d: dict, text: str) -> list[str]:
    _, label, _ = dlg_weight(d)
    t = [label]
    if SCHEDULING.search(text):
        t.append("scheduling")
    if workplace.score(text) >= 0.08:
        t.append("workplace")
    return t


def pair_candidates(d: dict, rej: Counter):
    """Yield (kind, row, score) for lr and bs candidates of one dialogue (one best of each kind is kept by the caller)."""
    turns = d["turns"]
    cleaned: list[tuple[str, bool] | None] = []
    for _, t in turns:
        try:
            cleaned.append(norm_turn(t, digits="few", strict_case=(d["src"] == SRC_TM), caps_ok=True))
        except Reject as e:
            cleaned.append(None)
            rej["turn:" + str(e)] += 1
    mw_names = set()
    if d["src"] == SRC_MW:
        for i, sp in enumerate(d["spans"]):
            if any(s.endswith("-name") for s, _ in sp):
                mw_names.add(i)
    out = []
    short = dlg_short(d)
    for i in range(len(turns) - 1):
        a, b = cleaned[i], cleaned[i + 1]
        if a is None or b is None or turns[i][0] == turns[i + 1][0]:
            continue
        if i in mw_names or i + 1 in mw_names:
            rej["pair:contains-name-slot"] += 1
            continue
        pa, ca = a
        pb, cb = b
        # ---- listenResponse ----
        # the prompt must be a question/request; spoken, 4-25 words; reply 4-20 words, no digits in the reply
        ok = True
        if not (4 <= wc(pa) <= 25 and 4 <= wc(pb) <= 20):
            ok = False
        elif not (pa.endswith("?") or QSTART.match(pa)):
            ok = False
        elif PROMPT_ANAPH.search(pa) or REPLY_ANAPH.search(pb) or LEAD_CONJ.match(pa) or LEAD_CONJ.match(pb):
            ok = False
        elif OPEN_PROMPT.search(pa):
            ok = False
        elif re.search(r"\d", pb) or PRIVACY.search(pa) or PRIVACY.search(pb):
            ok = False
        elif re.search(r"[A-Z]{2}\d", pa + pb):
            ok = False
        elif d["src"] == SRC_MW and (ASSISTANT_STILT.search(pb) or ASSISTANT_STILT.search(pa)):
            ok = False
        elif cb and d["src"] == SRC_MW and not pb[0].isupper():
            ok = False
        elif d["src"] == SRC_MW and turns[i + 1][0] == 1 and wc(pb) > 14:
            ok = False  # prefer short system replies
        if ok and _only_names(pa + " " + pb):
            ok = False
        if ok:
            txt = pa + " " + pb
            lvl = reply_cefr(txt)
            score = base_score(d, txt, lvl, ca or cb, 0.2 if turns[i][0] == 0 else 0.0, f"{short}-{i}")
            row = {
                "id": ids.item_id("listenResponse", d["src"], f"{d['tag']}-{short}-t{i}"),
                "type": "listenResponse", "cefr": lvl, "skill": "listening",
                "voice": pick_voice(f"{short}-{i}"), "prompt": pa, "correct": pb,
                "domain": d["domain"] if d["src"] == SRC_TM else "+".join(d["services"]),
                "topics": topics_for(d, txt), "group": f"{d['src']}:{short}",
                "source": d["src"], "sourceId": f"{d['tag']}/{d['convId']}#{i + 1}", "license": LIC[d["src"]],
                "tier": "permissive", "origin": "adapted", "normalized": bool(ca or cb)}
            out.append(("lr", row, score, d["src"]))
        # ---- buildSentence: reply 6-14 words, one sentence, no digits/names ----
        if 6 <= wc(pb) <= 14 and 3 <= wc(pa) <= 25 and not cb and not re.search(r"\d", pb) \
                and not LEAD_CONJ.match(pb) and not REPLY_ANAPH.search(pb) and not PRIVACY.search(pa + pb):
            sents = textnorm.split_sentences(pb)
            toks = [_core(t) for t in pb.split()]
            if len(sents) == 1 and pb.count("?") + pb.count("!") + pb.count(".") == 1 \
                    and any(t in VERBISH for t in toks) and not _only_names(pb) \
                    and not (d["src"] == SRC_MW and ASSISTANT_STILT.search(pb)):
                ch = make_chunks(pb, f"{short}-{i}")
                if ch is not None:
                    txt = pa + " " + pb
                    lvl = reply_cefr(pb)
                    score = base_score(d, txt, lvl, ca, 0.5 if wc(pb) >= 9 else 0.0, f"bs-{short}-{i}")
                    row = {
                        "id": ids.item_id("buildSentence", d["src"], f"{d['tag']}-{short}-t{i + 1}"),
                        "type": "buildSentence", "cefr": lvl, "skill": "grammar", "context": pa,
                        "chunks": ch, "answer": pb, "accepted": [],
                        "topics": topics_for(d, txt), "group": f"{d['src']}:{short}",
                        "source": d["src"], "sourceId": f"{d['tag']}/{d['convId']}#{i + 1}", "license": LIC[d["src"]],
                        "tier": "permissive", "origin": "verbatim"}
                    out.append(("bs", row, score, d["src"]))
    return out


def _only_names(s: str) -> bool:
    """True if the text still has a mid-sentence capitalised word that is not a day/month/I/OK (a name or brand)."""
    toks = s.split()
    for i, t in enumerate(toks):
        core = re.sub(r"[^A-Za-z']", "", t)
        if i > 0 and core and core[0].isupper() and toks[i - 1][-1] not in ".?!" and core not in DAYS_MONTHS \
                and not core.startswith("I'"):
            return True
    return False


def merged_lines(d: dict, rej: Counter) -> list[tuple[int, str, bool] | None]:
    """Merge consecutive same-speaker turns. A merged line is None if any raw part is rejected or it is too long."""
    parts: list[tuple[int, list]] = []
    for spk, t in d["turns"]:
        try:
            c = norm_turn(t, digits="few", strict_case=False, caps_ok=True)
        except Reject as e:
            c = None
            rej["line:" + str(e)] += 1
        if parts and parts[-1][0] == spk:
            parts[-1][1].append(c)
        else:
            parts.append((spk, [c]))
    out = []
    for spk, cs in parts:
        if any(c is None for c in cs):
            out.append(None)
            continue
        text = " ".join(c[0] for c in cs)
        if wc(text) > 40:
            rej["line:too-long"] += 1
            out.append(None)
            continue
        out.append((spk, text, any(c[1] for c in cs)))
    return out


def conv_window(d: dict, rej: Counter):
    lines = merged_lines(d, rej)
    # first run of >= 8 valid merged lines
    run, start = [], None
    for i, l in enumerate(lines + [None]):
        if l is not None:
            if start is None:
                start = i
        else:
            if start is not None and i - start >= 8:
                run = lines[start:i]
                break
            start = None
    if len(run) < 8:
        rej["lc:no-8-line-run"] += 1
        return None
    win = run[:14] if len(run) > 14 else run
    if len(run) > 14:
        win = run[:12]
    texts = [t for _, t, _ in win]
    total = sum(wc(t) for t in texts)
    avg = total / len(texts)
    if not 90 <= total <= 330:
        rej["lc:total-words"] += 1
        return None
    if avg < 6.5:
        rej["lc:avg-line-short"] += 1
        return None
    if sum(1 for t in texts if wc(t) <= 2) > 1:
        rej["lc:too-many-tiny-lines"] += 1
        return None
    if sum(1 for t in texts if wc(t) <= 3) > 3:
        rej["lc:too-many-short-lines"] += 1
        return None
    blob = " ".join(texts)
    if PRIVACY.search(blob):
        rej["lc:privacy"] += 1
        return None
    if re.search(r"[A-Z]{2}\d{2,}", blob) or (d["src"] == SRC_MW and re.search(r"\breference\b", blob, re.I)):
        rej["lc:reference-code"] += 1
        return None
    if d["src"] == SRC_MW and ASSISTANT_STILT.search(blob):
        rej["lc:assistant-stilted"] += 1
        return None
    return win


def build_conv(d: dict, win, rej: Counter, slot_pool, byslot_idx) -> tuple[dict, float] | None:
    short = dlg_short(d)
    texts = [t for _, t, _ in win]
    blob = " ".join(texts)
    first = win[0][0]
    va = pick_voice(f"lc-{short}")
    vb = "male" if va == "female" else "female"
    script = [{"speaker": "A" if spk == first else "B", "voice": va if spk == first else vb, "line": t}
              for spk, t, _ in win]
    lvl = cefr.estimate(blob)
    _, _, leisure = dlg_weight(d)
    fixed = []
    if d["src"] == SRC_MW:
        fixed = mw_detail_questions(d, win, slot_pool, short, rej)
        if len(fixed) < 2:
            rej["lc:mw-fewer-than-2-detail-slots"] += 1
            return None
    nfix = len(fixed)
    n_new = (3 if len(win) < 10 else 4) if not nfix else (1 if len(win) < 10 else 2)
    rng = random.Random(f"slots-{short}")
    slots = [rng.randrange(4) for _ in range(n_new)]
    row = {
        "id": ids.item_id("listenConversation", d["src"], f"{d['tag']}-{short}"),
        "type": "listenConversation", "cefr": lvl, "skill": "listening", "title": "",
        "script": script, "domain": d["domain"] if d["src"] == SRC_TM else "+".join(d["services"]),
        "fixedQuestions": fixed, "newQuestionCount": n_new, "answerSlots": slots,
        "topics": topics_for(d, blob), "group": f"{d['src']}:{short}",
        "source": d["src"], "sourceId": f"{d['tag']}/{d['convId']}", "license": LIC[d["src"]], "tier": "permissive",
        "origin": "adapted"}
    score = base_score(d, blob, lvl, any(c for _, _, c in win), 0.05 * min(avg_words(texts), 20), f"lc-{short}") + 0.5 * nfix
    return row, score


def avg_words(texts: list[str]) -> float:
    return sum(wc(t) for t in texts) / len(texts)


def mw_detail_questions(d: dict, win, pool: dict, short: str, rej: Counter) -> list[dict]:
    """Programmatic detail questions from annotated user-stated slots; distractors from other dialogues' values."""
    # window position -> raw turn index: win lines are merged but MW alternates strictly, so lines == turns.
    # find the window start by matching the first line text against normalized turns
    turns = d["turns"]
    norm = []
    for spk, t in turns:
        try:
            norm.append(norm_turn(t, digits="few", strict_case=False, caps_ok=True)[0])
        except Reject:
            norm.append(None)
    texts = [t for _, t, _ in win]
    start = next((i for i in range(len(norm)) if norm[i:i + len(texts)] == texts), None)
    if start is None:
        return []
    end = start + len(texts)
    user_blob = " ".join(texts[j] for j in range(len(texts)) if turns[start + j][0] == 0)
    found: dict[str, set] = defaultdict(set)
    for i in range(start, end):
        if turns[i][0] != 0:
            continue
        for slot, val in d["spans"][i]:
            if slot in BOOK_SLOTS and val.lower() in norm[i].lower():
                found[slot].add(val)
    st = d["states"][end - 1]
    for slot in STATE_SLOTS:
        v = st.get(slot)
        if v:
            pat = r"(?<![\d:])" + re.escape(v) + r"(?![\d:])"
            if re.search(pat, user_blob, re.I):
                found[slot].add(v)
    allblob = " ".join(texts).lower()
    qs = []
    for slot, vals in sorted(found.items()):
        vals = {v for v in vals if v and v.strip()}
        if len(vals) != 1:
            continue
        val = next(iter(vals))
        cands = [v for v in pool.get(slot, []) if v.lower() != val.lower() and v.lower() not in allblob]
        if len(cands) < 3:
            continue
        rng = random.Random(f"{short}-{slot}")
        dis = rng.sample(cands, 3)
        opts = dis + [val]
        rng.shuffle(opts)
        fmt = (lambda x: x[0].upper() + x[1:]) if not TIME_RE.match(val) and not val.isdigit() else (lambda x: x)
        q = (BOOK_SLOTS.get(slot) or STATE_SLOTS[slot])
        qs.append({"slot": slot, "q": q, "options": [fmt(o) for o in opts], "answer": opts.index(val)})
    rng = random.Random(f"fixed-{short}")
    rng.shuffle(qs)
    return qs[:2]


def slot_pools(mw_dialogs: list[dict]) -> dict:
    pool: dict[str, Counter] = defaultdict(Counter)
    for d in mw_dialogs:
        for sp in d["spans"]:
            for slot, val in sp:
                if slot in BOOK_SLOTS:
                    pool[slot][val] += 1
        st = d["states"][-1] if d["states"] else {}
        for slot in STATE_SLOTS:
            if st.get(slot):
                pool[slot][st[slot]] += 1
    out = {}
    for slot, c in pool.items():
        vals = [v for v, n in c.items() if v and v.strip() and (n >= 2 or TIME_RE.match(v) or v.isdigit())]
        if slot.endswith(("booktime", "leaveat", "arriveby")):
            vals = [v for v in vals if TIME_RE.match(v)]
        if slot.endswith(("bookpeople", "bookstay")):
            vals = [v for v in vals if v.isdigit() and 1 <= int(v) <= 8]
        if slot.endswith("bookday"):
            vals = [v for v in vals if v.lower() in ("monday", "tuesday", "wednesday", "thursday", "friday",
                                                    "saturday", "sunday")]
        out[slot] = sorted(vals)
    return out


# --- selection --------------------------------------------------------------------------------
def select(cands: list[tuple[dict, float, str, bool]], base: int, kind: str, idx: DedupeIndex, used_dialogs: set,
           rej: Counter, textkey) -> list[dict]:
    target = int(base * RESERVE)
    """cands: (row, score, src, leisure). Two passes: quota-respecting, then fill from whichever source has more."""
    cands = sorted(cands, key=lambda c: -c[1])
    mw_quota = round(target * SPLIT_MW[kind])
    chosen: list[tuple[dict, float]] = []
    counts = Counter()
    leisure_n = 0
    leisure_cap = int(target * LEISURE_CAP)
    skipped: list = []

    def try_add(c, enforce_quota: bool) -> bool:
        nonlocal leisure_n
        row, sc, src, leisure = c
        if row["group"] in used_dialogs:
            return False
        if enforce_quota:
            if src == SRC_MW and counts[SRC_MW] >= mw_quota:
                return False
            if src == SRC_TM and counts[SRC_TM] >= target - mw_quota:
                return False
        if leisure and leisure_n >= leisure_cap:
            rej[f"{kind}:leisure-cap"] += 1
            return False
        reason = idx.check_and_add(row["id"], textkey(row))
        if reason:
            rej[f"{kind}:dedupe"] += 1
            return False
        used_dialogs.add(row["group"])
        counts[src] += 1
        leisure_n += 1 if leisure else 0
        chosen.append((row, sc))
        return True

    for c in cands:
        if len(chosen) >= target:
            break
        if not try_add(c, True):
            skipped.append(c)
    for c in skipped:
        if len(chosen) >= target:
            break
        try_add(c, False)
    chosen.sort(key=lambda x: -x[1])
    rows = [r for r, _ in chosen]
    for i, r in enumerate(rows):
        if i >= base:
            r["reserve"] = True
    return rows


def lr_key(row: dict) -> str:
    return row["prompt"]


def bs_key(row: dict) -> str:
    return row["context"] + "\n" + row["answer"]


def lc_key(row: dict) -> str:
    return "\n".join(x["line"] for x in row["script"])


# --- extract ----------------------------------------------------------------------------------
def extract(raw: Path, stage: Path, report: Path, content: Path) -> None:
    stage.mkdir(parents=True, exist_ok=True)
    report.parent.mkdir(parents=True, exist_ok=True)
    rej: Counter = Counter()
    idx = DedupeIndex.from_content(content)
    print("loading dialogues ...", flush=True)
    dialogs = list(load_tm(raw)) + list(load_mw(raw))
    mw = [d for d in dialogs if d["src"] == SRC_MW]
    rej["dialogues:taskmaster"] = len(dialogs) - len(mw)
    rej["dialogues:multiwoz"] = len(mw)
    pools = slot_pools(mw)

    # ---- listenConversation windows (first: they need the longest runs) ----
    print("conversation windows ...", flush=True)
    lc_c = []
    for d in dialogs:
        if len(d["turns"]) < 8:
            rej["lc:dialogue-under-8-turns"] += 1
            continue
        win = conv_window(d, rej)
        if win is None:
            continue
        b = build_conv(d, win, rej, pools, None)
        if b:
            row, score = b
            lc_c.append((row, score, d["src"], dlg_weight(d)[2]))
    rej["lc:candidates"] = len(lc_c)
    used: set = set()
    lc_rows = select(lc_c, TARGETS["lc"], "lc", idx, used, rej, lc_key)

    # ---- pair candidates (listenResponse, buildSentence): best per dialogue and kind ----
    print("pair candidates ...", flush=True)
    best: dict[tuple[str, str], tuple] = {}
    n_pairs = Counter()
    for d in dialogs:
        if f"{d['src']}:{dlg_short(d)}" in used:
            continue
        for kind, row, score, src in pair_candidates(d, rej):
            n_pairs[kind] += 1
            k = (kind, row["group"])
            if k not in best or score > best[k][1]:
                best[k] = (row, score, src, dlg_weight(d)[2])
    rej["lr:candidate-pairs"] = n_pairs["lr"]
    rej["bs:candidate-pairs"] = n_pairs["bs"]
    lr_c = [v for (k, _), v in best.items() if k == "lr"]
    bs_c = [v for (k, _), v in best.items() if k == "bs"]
    rej["lr:dialogues-with-a-candidate"] = len(lr_c)
    rej["bs:dialogues-with-a-candidate"] = len(bs_c)
    lr_rows = select(lr_c, TARGETS["lr"], "lr", idx, used, rej, lr_key)
    bs_rows = select(bs_c, TARGETS["bs"], "bs", idx, used, rej, bs_key)
    # the best bs candidate of a dialogue may collide with an lr pick of the same dialogue: bs only from fresh dialogues
    # (select() already skips used groups, so that is guaranteed)

    # final dedupe of the answer text on its own (a reply can recur in different contexts)
    seen_ans: set[str] = set()
    uniq_bs = []
    for r in bs_rows:
        h = textnorm.text_hash(r["answer"])
        if h in seen_ans:
            rej["bs:duplicate-answer"] += 1
            continue
        seen_ans.add(h)
        uniq_bs.append(r)
    bs_rows = uniq_bs

    # ---- write stage ----
    def dump(name: str, rows: list[dict]) -> None:
        with open(stage / name, "w", encoding="utf-8") as f:
            for r in rows:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")

    for r in lr_rows:
        r.pop("normalized", None)
    dump("listen-response.jsonl", lr_rows)
    dump("listen-conversation.jsonl", lc_rows)
    dump("build-sentence.jsonl", bs_rows)
    batches = write_batches(stage, lr_rows, lc_rows, bs_rows)
    write_report(report, rej, lr_rows, lc_rows, bs_rows, batches)
    print(f"listenResponse {len(lr_rows)}  listenConversation {len(lc_rows)}  buildSentence {len(bs_rows)}  "
          f"batches {len(batches)}")


def split_even(rows: list[dict], lo: int, hi: int) -> list[list[dict]]:
    n = len(rows)
    if n == 0:
        return []
    k = max(1, -(-n // hi))
    while n / k < lo and k > 1:
        k -= 1
    size, rem = divmod(n, k)
    out, p = [], 0
    for i in range(k):
        s = size + (1 if i < rem else 0)
        out.append(rows[p:p + s])
        p += s
    return out


def write_batches(stage: Path, lr_rows: list[dict], lc_rows: list[dict], bs_rows: list[dict]) -> list[Path]:
    bdir = stage / "batches"
    bdir.mkdir(parents=True, exist_ok=True)
    for old in bdir.glob("*.jsonl"):
        old.unlink()
    out = []
    # mix sources and domains inside a batch (stable shuffle) so no batch is all restaurants
    for prefix, rows in (("lr", lr_rows), ("lc", lc_rows), ("bs", bs_rows)):
        rows = sorted(rows, key=lambda r: _hash_int(r["id"]))
        for n, chunk in enumerate(split_even(rows, 40, 60), 1):
            p = bdir / f"{prefix}-{n:02d}.jsonl"
            with open(p, "w", encoding="utf-8") as f:
                for r in chunk:
                    f.write(json.dumps(r, ensure_ascii=False) + "\n")
            out.append(p.resolve())
    return out


def write_report(path: Path, rej: Counter, lr, lc, bs, batches) -> None:
    rng = random.Random(11)
    L = ["# Taskmaster + MultiWOZ (C06/C07) extract report", "",
         "Licenses verified at the source on fetch: Taskmaster-1/2 CC BY 4.0 (HF tags on taskmaster1/taskmaster2 and the "
         "TM-1-2019/TM-2-2020 READMEs), MultiWOZ 2.2 Apache-2.0 (HF tag on pfb30/multi_woz_v22).", "",
         "Staged only: listenResponse and listenConversation still need LLM fill; buildSentence is complete.", "",
         "## Selected", ""]
    for name, rows in (("listenResponse", lr), ("listenConversation", lc), ("buildSentence", bs)):
        by = Counter(r["source"] for r in rows)
        L.append(f"- {name}: {len(rows)} (taskmaster {by[SRC_TM]}, multiwoz {by[SRC_MW]})")
    L += ["", "## Counts and reject reasons", ""] + [f"- {k}: {v}" for k, v in sorted(rej.items())]
    for name, rows, fmt in (
            ("listenResponse", lr, lambda r: f"[{r['domain']}] {r['prompt']}  =>  {r['correct']}"),
            ("listenConversation", lc, lambda r: f"[{r['domain']}] {len(r['script'])} lines, fixedQ={len(r['fixedQuestions'])}: "
                                                 + " / ".join(x['line'] for x in r['script'][:3])),
            ("buildSentence", bs, lambda r: f"[{r['topics'][0]}] {r['context']}  =>  {r['answer']}  | {' / '.join(r['chunks'])}")):
        L += ["", f"## {name}: level, topic and domain distribution", ""]
        L += [f"- {k}: {v}" for k, v in sorted(Counter(r['cefr'] for r in rows).items())]
        L += [f"- topic {k}: {v}" for k, v in sorted(Counter(r['topics'][0] for r in rows).items())]
        leis = sum(1 for r in rows if dlg_leisure(r))
        L.append(f"- leisure domains (restaurant/movies/music/sports/attraction): {leis} of {len(rows)}")
        L += ["", f"## {name}: 30-item random sample", ""]
        L += [f"{i}. {r['cefr']} | {fmt(r)}" for i, r in enumerate(rng.sample(rows, min(30, len(rows))), 1)]
    L += ["", "## Batches", ""] + [f"- {b}" for b in batches]
    path.write_text("\n".join(L) + "\n", encoding="utf-8")


def dlg_leisure(r: dict) -> bool:
    doms = r.get("domain", "") or ""
    if not doms:
        return r["topics"][0] in ("dining", "entertainment")
    return all(domain_info(x)[2] for x in doms.split("+"))


def _read_filled(stage: Path, prefix: str):
    """-> [(batch name, [rows])] from <prefix>-NN.filled.jsonl (rows keep file order)."""
    out = []
    for fp in sorted((stage / "batches").glob(f"{prefix}-*.filled.jsonl")):
        rows = [json.loads(l) for l in fp.read_text(encoding="utf-8").splitlines() if l.strip()]
        out.append((fp.name.split(".")[0], rows))
    return out


EMIT_DROP = {"correct", "distractors", "domain", "verdict", "rejectReason", "reserve", "fixedQuestions", "newQuestions",
             "fixedExplanations", "answerSlots", "newQuestionCount", "normalized", "explanation"}
URL_TM = "https://github.com/google-research-datasets/Taskmaster"
URL_MW = "https://huggingface.co/datasets/pfb30/multi_woz_v22"
SRC_NAME = {SRC_TM: "Taskmaster-1/2", SRC_MW: "MultiWOZ 2.2"}
SRC_URL = {SRC_TM: URL_TM, SRC_MW: URL_MW}
SRC_ATTR = {SRC_TM: "Byrne et al. 2019 (Taskmaster-1) and Taskmaster-2 (2020), Google Research, CC BY 4.0; "
                    "distractors, questions and explanations written with Claude",
            SRC_MW: "Zang et al. 2020, MultiWOZ 2.2 (Budzianowski et al. 2018), pfb30/multi_woz_v22, Apache-2.0; "
                    "distractors, questions and explanations written with Claude"}
FILE_STEM = {"listenResponse": "listen-response", "listenConversation": "listen-conversation",
             "buildSentence": "build-sentence"}
EMIT_NAMES = re.compile(r"\b[A-Z][a-z]{2,}\b")


LOWER_PROPER = re.compile(r"\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday|cambridge|london|norwich|ely|"
                          r"stansted|peterborough|leicester|birmingham|stevenage|bishops stortford|kings lynn|kings cross|"
                          r"january|february|march|april|june|july|august|september|october|november|december|i|"
                          r"british|european|italian|chinese|indian|north american|american|mexican|asian|japanese|"
                          r"thai|korean|turkish|african|portuguese|spanish|vietnamese)\b")
CASUAL = re.compile(r"^honey,|, honey\b|\bhey man\b|\bgonna\b|\bwanna\b|\byou guys\b|\blol\b", re.I)
BAD_FMT = re.compile(r"[a-z]\.[A-Z]|[,;][A-Za-z]|\?[a-z]|  ")


def _texts(it: dict) -> list[str]:
    if it["type"] == "listenResponse":
        return [it["prompt"]] + it["options"]
    if it["type"] == "buildSentence":
        return [it["context"], it["answer"]]
    out = [x["line"] for x in it["script"]]
    for q in it["questions"]:
        out += [q["q"]] + q["options"]
    return out


def hygiene_problem(it: dict) -> str | None:
    """Lowercase place/day/cuisine names (MultiWOZ is lowercased in places), chat-speak, spacing slips."""
    for t in _texts(it):
        if LOWER_PROPER.search(t):
            return "lowercase proper noun"
        if CASUAL.search(t):
            return "casual/slangy wording"
        if BAD_FMT.search(t):
            return "punctuation/spacing slip"
    return None


def _wc(s: str) -> int:
    return len(s.split())


def _strip(r: dict) -> dict:
    return {k: v for k, v in r.items() if k not in EMIT_DROP}


def _lr_item(r: dict, rej: Counter):
    ds = [d.strip() for d in r.get("distractors") or []]
    corr = r["correct"].strip()
    expl = (r.get("explanation") or "").strip()
    if len(ds) != 3 or len({x.lower() for x in ds + [corr]}) != 4:
        rej["lr:options not 4 distinct"] += 1
        return None
    if not expl:
        rej["lr:no explanation"] += 1
        return None
    if any(not 4 <= _wc(d) <= 20 for d in ds):
        rej["lr:distractor length"] += 1
        return None
    if len(corr) > 1.6 * sorted(len(x) for x in ds)[1] + 12:
        rej["lr:key much longer than distractors (answer-by-length)"] += 1
        return None
    if any(textnorm.text_hash(d) == textnorm.text_hash(r["prompt"]) for d in ds):
        rej["lr:distractor repeats the prompt"] += 1
        return None
    opts = ds + [corr]
    random.Random(r["id"]).shuffle(opts)
    it = _strip(r)
    it.update({"options": opts, "answer": opts.index(corr), "explanation": expl})
    return it


def _lc_item(r: dict, rej: Counter):
    title = (r.get("title") or "").strip()
    if not title or _wc(title) > 7:
        rej["lc:bad title"] += 1
        return None
    fixed, fexp = r.get("fixedQuestions") or [], r.get("fixedExplanations") or []
    if len(fexp) != len(fixed) or not all(isinstance(e, str) and e.strip() for e in fexp):
        rej["lc:fixed explanations missing"] += 1
        return None
    new = r.get("newQuestions") or []
    qs = []
    for q, e in zip(fixed, fexp):
        qs.append({"q": q["q"].strip(), "options": q["options"], "answer": q["answer"], "explanation": e.strip()})
    for q in new:
        if not str(q.get("explanation", "")).strip():
            rej["lc:new question without explanation"] += 1
            return None
        qs.append({"q": q["q"].strip(), "options": q["options"], "answer": q["answer"], "explanation": q["explanation"].strip()})
    if not 3 <= len(qs) <= 4:
        rej["lc:question count not 3-4"] += 1
        return None
    for q in qs:
        o = q["options"]
        if len(o) != 4 or len({x.lower() for x in o}) != 4 or not isinstance(q["answer"], int) or not 0 <= q["answer"] < 4:
            rej["lc:bad question options"] += 1
            return None
        if len(o[q["answer"]]) > 1.6 * sorted(len(x) for x in o)[2] + 12:
            rej["lc:key much longer than distractors"] += 1
            return None
    if len({q["q"].lower() for q in qs}) != len(qs):
        rej["lc:duplicate question"] += 1
        return None
    it = _strip(r)
    it.update({"title": title, "questions": qs})
    return it


def _bs_item(r: dict, rej: Counter):
    if r.get("accepted") != []:
        rej["bs:accepted not empty"] += 1
        return None
    ch = r["chunks"]
    if not 5 <= len(ch) <= 8 or not 6 <= _wc(r["answer"]) <= 14:
        rej["bs:chunk/word count"] += 1
        return None
    if " ".join(ch) == r["answer"]:
        rej["bs:chunks not shuffled"] += 1
        return None
    return _strip(r)


def emit_cmd(stage: Path, report: Path, content: Path) -> None:
    from lib import emit as emit_lib, schema
    rej: Counter = Counter()
    per_batch = []
    built: dict[str, list[dict]] = {}
    maker = {"listenResponse": ("lr", _lr_item), "listenConversation": ("lc", _lc_item), "buildSentence": ("bs", _bs_item)}
    # dedupe index over Content/ without our own output files (idempotent reruns)
    own = {f"{FILE_STEM[t]}-{s}.json" for t in FILE_STEM for s in (SRC_TM, SRC_MW)}
    idx = DedupeIndex()
    for sub in ("items", "vocab"):
        for f in sorted((content / sub).glob("*.json")):
            if f.name in own:
                continue
            for row in json.loads(f.read_text(encoding="utf-8")):
                idx.add(row["id"], item_text(row))
    for typ, (pre, mk) in maker.items():
        cand = []
        for name, rows in _read_filled(stage, pre):
            nrej = sum(1 for r in rows if r.get("verdict") != "ok")
            per_batch.append((name, len(rows), nrej))
            for r in rows:
                if r.get("verdict") != "ok":
                    rej[f"{pre}:rejected by fill agent"] += 1
                    continue
                it = mk(r, rej)
                if it is not None:
                    cand.append((it, bool(r.get("reserve"))))
        # reserve rows only fill up to the target
        cand.sort(key=lambda x: (x[1], x[0]["id"]))
        out, seen_ids = [], set()
        for it, _res in cand:
            if len(out) >= TARGETS[pre]:
                rej[f"{pre}:over target"] += 1
                continue
            if it["id"] in seen_ids:
                rej[f"{pre}:duplicate id"] += 1
                continue
            hp = hygiene_problem(it)
            if hp:
                rej[f"{pre}:emit hygiene: {hp}"] += 1
                continue
            probs = schema.problems_item(it)
            if probs:
                rej[f"{pre}:schema: {probs[0][:60]}"] += 1
                continue
            dup = idx.check_and_add(it["id"], item_text(it))
            if dup:
                rej[f"{pre}:dedupe: {dup.split(' of ')[0]}"] += 1
                continue
            seen_ids.add(it["id"])
            out.append(it)
        # one item per underlying dialogue and type is already guaranteed by extract(); recheck groups
        gcount = Counter(i["group"] for i in out)
        built[typ] = sorted(out, key=lambda i: i["id"])
        rej[f"{pre}:groups with >1 item"] = sum(1 for v in gcount.values() if v > 1)
    emitted = []
    for typ, items in built.items():
        for src in (SRC_TM, SRC_MW):
            rows = [i for i in items if i["source"] == src]
            if not rows:
                continue
            fn = f"{FILE_STEM[typ]}-{src}.json"
            e = emit_lib.emit(content, "items", fn, rows, source=SRC_NAME[src], url=SRC_URL[src], license=LIC[src],
                              tier="permissive", attribution=SRC_ATTR[src])
            emitted.append((typ, fn, len(rows), e["origin"]))
    # ---- report (keep the extract section, replace any earlier emit section) ----
    old = report.read_text(encoding="utf-8") if report.exists() else ""
    old = old.split("\n# Emit")[0].rstrip() + "\n"
    L = ["", "# Emit (fill agents merged)", "", "## Emitted", ""]
    for typ, fn, n, o in emitted:
        L.append(f"- {typ}: {n} -> Content/items/{fn} (origin {o})")
    L += ["", "## Fill-agent reject rate per batch (flag above 30%)", ""]
    for n, t, r_ in per_batch:
        L.append(f"- {n}: {r_}/{t} rejected ({100 * r_ / t:.0f}%){'  ABOVE 30%' if r_ / t > 0.3 else ''}")
    for pre in ("lr", "lc", "bs"):
        pb = [(t, r_) for n, t, r_ in per_batch if n.startswith(pre)]
        L.append(f"- {pre} total: {sum(r_ for _, r_ in pb)}/{sum(t for t, _ in pb)} rejected")
    L += ["", "Why above 30%: extract() is a loose pre-filter; the fill agents rejected source lines with typos, "
          "ungrammatical or stilted wording, personal names, replies that depend on earlier turns and prompts too open "
          "for one natural reply. lc is the worst (about 70% rejected): Taskmaster self-dialogs are written by crowd "
          "workers and often contain typos, so fewer clean items were kept over reaching the target.", "",
          "## Emit-step filters and counts", ""] + [f"- {k}: {v}" for k, v in sorted(rej.items())]
    for typ, items in built.items():
        L += ["", f"## {typ}: distributions", ""]
        L += [f"- level {k}: {v}" for k, v in sorted(Counter(i["cefr"] for i in items).items())]
        L += [f"- source {k}: {v}" for k, v in sorted(Counter(i["source"] for i in items).items())]
        L += [f"- topic {k}: {v}" for k, v in sorted(Counter(i["topics"][0] for i in items).items())]
        if typ == "listenResponse":
            L += [f"- answer position {k}: {v}" for k, v in sorted(Counter(i["answer"] for i in items).items())]
        if typ == "listenConversation":
            L += [f"- questions per item {k}: {v}" for k, v in sorted(Counter(len(i["questions"]) for i in items).items())]
        if typ == "buildSentence":
            L += [f"- chunks {k}: {v}" for k, v in sorted(Counter(len(i["chunks"]) for i in items).items())]
        L += ["", f"### {typ}: 30-item random sample (seed 5)", ""]
        for n, i in enumerate(random.Random(5).sample(items, min(30, len(items))), 1):
            if typ == "listenResponse":
                L.append(f"{n}. {i['cefr']} | {i['prompt']} => KEY [{i['answer']}] {i['options'][i['answer']]} | " + " / ".join(o for k, o in enumerate(i['options']) if k != i['answer']))
            elif typ == "buildSentence":
                L.append(f"{n}. {i['cefr']} | {i['context']} => {i['answer']}  | {' / '.join(i['chunks'])}")
            else:
                L.append(f"{n}. {i['cefr']} | {i['title']} ({len(i['script'])} lines) " + " ".join(f"Q: {q['q']} => {q['options'][q['answer']]};" for q in i['questions']))
    report.write_text(old + "\n".join(L) + "\n", encoding="utf-8")
    print({t: len(v) for t, v in built.items()})


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["fetch", "extract", "emit"])
    ap.add_argument("--raw", default=".ingest/raw/taskmaster")
    ap.add_argument("--stage", default=".ingest/stage/taskmaster")
    ap.add_argument("--report", default=".ingest/reports/taskmaster.md")
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
