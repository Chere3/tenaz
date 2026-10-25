"""C16: vocab notes from BSL / NAWL / NGSL headwords (CC BY-SA 4.0) + Tatoeba EN-ES examples (CC BY 2.0 FR).

  fetch    -> .ingest/raw/vocab/            (network; verifies the license text at the source first, stops on mismatch)
  extract  -> .ingest/stage/vocab/rows.jsonl + .ingest/reports/vocab.md   (raw/ read as data only)
  batches  -> .ingest/stage/vocab/batches/batch-NNNN.jsonl   (40-60 rows each, for the LLM fill agents)
  emit     -> Content/vocab/{bsl-workplace,nawl-academic,ngsl-core}.json  (needs <batch>.filled.jsonl files)

Headword spine: BSL first, then NAWL, then NGSL ranks >= 800. CEFR from CEFR-J (free with citation) and Octanove C1
(CC BY-SA 4.0); a frequency estimate (wordfreq) only when neither lists the word. Examples: Tatoeba pairs staged by
C08 in .ingest/stage/tatoeba/pairs.jsonl. Everything the LLM must add (es, definition, distractors, collocations,
note) is left out of rows.jsonl on purpose.

Run: uv run --project scripts/ingest python -I scripts/ingest/sources/vocab.py <cmd>
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import random
import re
import sys
import urllib.request
import xml.etree.ElementTree as ET
import zipfile
from collections import Counter, defaultdict
from pathlib import Path

from wordfreq import zipf_frequency

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib import dedupe, emit as emitlib, ids, schema, workplace  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
RAW = ROOT / ".ingest/raw/vocab"
STAGE = ROOT / ".ingest/stage/vocab"
REPORT = ROOT / ".ingest/reports/vocab.md"
TATOEBA = ROOT / ".ingest/stage/tatoeba"

NGSL_BASE = "https://www.newgeneralservicelist.com"
CEFRJ_BASE = "https://raw.githubusercontent.com/openlanguageprofiles/olp-en-cefrj/master"
PAGES = {  # page -> text that must appear on it
    "new-general-service-list": ("New General Service List", "Creative Commons Attribution-ShareAlike 4.0 International License"),
    "new-academic-word-list": ("New Academic Word List", "Creative Commons Attribution-ShareAlike 4.0 International License"),
    "business-service-list": ("Business Service List", "Creative Commons Attribution-ShareAlike 4.0 International License"),
}
FILES = {
    "NGSL_12_lemmatized_for_teaching.csv": f"{NGSL_BASE}/s/NGSL_12_lemmatized_for_teaching.csv",
    "NGSL_12_stats.csv": f"{NGSL_BASE}/s/NGSL_12_stats.csv",
    "NGSL_12_with_English_definitions.xlsx": f"{NGSL_BASE}/s/NGSL_12_with_English_definitions.xlsx",
    "NAWL_12_lemmatized_for_teaching.csv": f"{NGSL_BASE}/s/NAWL_12_lemmatized_for_teaching.csv",
    "NAWL_12_with_en_definitions.csv": f"{NGSL_BASE}/s/NAWL_12_with_en_definitions.csv",
    "BSL_120_lemmatized_for_teaching.csv": f"{NGSL_BASE}/s/BSL_120_lemmatized_for_teaching.csv",
    "BSL_120_stats.csv": f"{NGSL_BASE}/s/BSL_120_stats.csv",
    "cefrj.csv": f"{CEFRJ_BASE}/cefrj-vocabulary-profile-1.5.csv",
    "octanove.csv": f"{CEFRJ_BASE}/octanove-vocabulary-profile-c1c2-1.0.csv",
}
README_URL = f"{CEFRJ_BASE}/README.md"

LIST_ORDER = ["bsl", "nawl", "ngsl"]
OUT = {  # list -> (filename, tag, source name, url)
    "bsl": ("bsl-workplace.json", "workplace", "BSL 1.2 (Business Service List)", f"{NGSL_BASE}/business-service-list"),
    "nawl": ("nawl-academic.json", "academic", "NAWL 1.2 (New Academic Word List)", f"{NGSL_BASE}/new-academic-word-list"),
    "ngsl": ("ngsl-core.json", "core", "NGSL 1.2 (New General Service List)", f"{NGSL_BASE}/new-general-service-list"),
}
NGSL_MIN_RANK = 800
POS_OK = {"noun", "verb", "adjective", "adverb"}
LEVELS_OK = {"B1", "B2", "C1"}
MIN_W, MAX_W = 8, 20
BATCH_MIN, BATCH_MAX = 40, 60

# Lemmas we do not want in an adult workplace bank (the example sentences were already filtered by C08).
BAD_LEMMA = re.compile(r"^(sex\w*|rape\w*|porn\w*|naked|nude|kill\w*|murder\w*|suicid\w*|terror\w*|weapon\w*|gun\w*|bomb\w*|"
                       r"drug\w*|alcohol\w*|beer|wine|vodka|cigarette\w*|tobacco|slave\w*|prostitut\w*|erotic|casino|gambl\w*|"
                       r"bible|jesus|church|god|pray\w*|mister|cocaine|heroin|torture\w*|massacre|genocide|nazi\w*)$")
HOMOGRAPH_FORMS = {"found", "left", "mine", "rose", "wound", "saw", "lay", "bear", "bore", "ground", "bound", "felt", "meant"}

DET = {"the", "a", "an", "this", "that", "these", "those", "my", "your", "his", "her", "its", "our", "their", "some", "any",
       "no", "every", "each", "another", "much", "many", "several", "both", "such", "whose", "one"}
TO_AUX = {"to", "will", "would", "can", "could", "should", "must", "may", "might", "shall", "did", "does", "do", "don't",
          "doesn't", "didn't", "won't", "can't", "cannot", "wouldn't", "couldn't", "shouldn't", "let's", "not"}
SUBJ = {"i", "you", "we", "they", "he", "she", "it", "who", "which", "there"}
PREP = {"of", "for", "in", "on", "with", "by", "at", "from", "about", "into", "than", "like", "without", "within"}

TOKEN = re.compile(r"[A-Za-z]+(?:'[a-z]+)?|[0-9]+|[^\sA-Za-z0-9]")


def read_text(p: Path) -> str:
    b = p.read_bytes()
    try:
        return b.decode("utf-8-sig")
    except UnicodeDecodeError:
        return b.decode("cp1252", errors="replace")


# ------------------------------------------------------------------ fetch

def _get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "tenaz-ingest/0.1 (personal study project)"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def _page_text(html: str) -> str:
    html = re.sub(r"<script.*?</script>|<style.*?</style>", "", html, flags=re.S)
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", html))


def fetch(raw: Path) -> None:
    if raw.exists() and any(raw.iterdir()):
        raise SystemExit(f"{raw} is not empty; fetch writes into a new, empty dir (remove it first)")
    raw.mkdir(parents=True, exist_ok=True)
    check: dict = {"checked": []}
    for page, (title, needle) in PAGES.items():
        text = _page_text(_get(f"{NGSL_BASE}/{page}").decode("utf-8", "replace"))
        ok = title in text and needle in text
        check["checked"].append({"url": f"{NGSL_BASE}/{page}", "needle": needle, "ok": ok})
        if not ok:
            raise SystemExit(f"LICENSE MISMATCH at {NGSL_BASE}/{page}: expected {needle!r}. Stopping, nothing downloaded.")
    readme = _get(README_URL).decode("utf-8", "replace")
    need = ["can be used for research and commercial purposes with no charge", "Creative Commons Attribution-ShareAlike 4.0"]
    for n in need:
        if n not in readme:
            raise SystemExit(f"LICENSE MISMATCH in CEFR-J README: missing {n!r}. Stopping.")
    check["checked"].append({"url": README_URL, "needles": need, "ok": True})
    (raw / "license-check.json").write_text(json.dumps(check, indent=2) + "\n", encoding="utf-8")
    manifest = {}
    for name, url in FILES.items():
        data = _get(url)
        (raw / name).write_bytes(data)
        manifest[name] = {"url": url, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
    (raw / "MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("license verified (CC BY-SA 4.0 on all three list pages; CEFR-J terms ok); wrote", len(manifest), "files to", raw)


# ------------------------------------------------------------------ parsing the lists

def read_lemma_file(p: Path) -> list[tuple[str, list[str]]]:
    out = []
    for line in read_text(p).splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = [x.strip().lower() for x in line.split(",") if x.strip()]
        if parts:
            out.append((parts[0], parts[1:]))
    return out


def read_ranks(p: Path, col: int = 1) -> dict[str, int]:
    ranks: dict[str, int] = {}
    for i, row in enumerate(csv.reader(io.StringIO(read_text(p)))):
        if i == 0 or len(row) <= col or not row[0].strip():
            continue
        try:
            ranks.setdefault(row[0].strip().lower(), int(float(row[col])))
        except ValueError:
            pass
    return ranks


def read_xlsx_definitions(p: Path) -> dict[str, list[str]]:
    """Parse the NGSL xlsx as data with zipfile + ElementTree (columns A=word, B=definition)."""
    ns = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
    with zipfile.ZipFile(p) as z:
        sst = [("".join(t.text or "" for t in si.iter("{%s}t" % ns["m"]))) for si in ET.fromstring(z.read("xl/sharedStrings.xml")).findall("m:si", ns)]
        sheet = ET.fromstring(z.read("xl/worksheets/sheet1.xml"))
    out: dict[str, list[str]] = defaultdict(list)
    for row in sheet.iter("{%s}row" % ns["m"]):
        cells = {}
        for c in row.findall("m:c", ns):
            col = re.match(r"[A-Z]+", c.get("r", "")).group(0)
            v = c.find("m:v", ns)
            if v is None:
                continue
            cells[col] = sst[int(v.text)] if c.get("t") == "s" else v.text
        if "A" in cells and "B" in cells and row.get("r") != "1":
            out[cells["A"].strip().lower()].append(re.sub(r"\s+", " ", cells["B"]).strip())
    return out


def read_nawl_definitions(p: Path) -> dict[str, list[tuple[str, str]]]:
    out: dict[str, list[tuple[str, str]]] = defaultdict(list)
    pos_map = {"n": "noun", "v": "verb", "adj": "adjective", "adv": "adverb"}
    for r in csv.DictReader(io.StringIO(read_text(p))):  # the Japanese column is ignored
        w = (r.get("Meanings") or "").strip().lower()
        if w:
            out[w].append((pos_map.get((r.get("POS") or "").strip().lower(), ""), re.sub(r"\s+", " ", r.get("English Definition") or "").strip()))
    return out


def read_cefr_profiles(raw: Path) -> dict[str, list[tuple[str, str, str]]]:
    """headword -> [(pos, cefr, profile)]; slash variants ('colour/color') become separate keys."""
    idx: dict[str, list[tuple[str, str, str]]] = defaultdict(list)
    for fname, prof in (("cefrj.csv", "cefrj"), ("octanove.csv", "octanove")):
        for r in csv.DictReader(io.StringIO(read_text(raw / fname))):
            for h in r["headword"].split("/"):
                h = h.strip().lower()
                if h:
                    idx[h].append((r["pos"].strip(), r["CEFR"].strip(), prof))
    return idx


# ------------------------------------------------------------------ heuristics

def form_kind(form: str, lemma: str) -> str:
    if form == lemma:
        return "base"
    if form in (lemma + "s", lemma + "es") or (lemma.endswith("y") and form == lemma[:-1] + "ies"):
        return "s"
    if form.endswith("ing"):
        return "ing"
    if form.endswith("ed") or form == lemma + "d":
        return "ed"
    return "other"


def guess_pos(lemma: str, defs: list[str], nawl_pos: str) -> str:
    if nawl_pos in POS_OK:
        return nawl_pos
    if any(d.lower().startswith("to ") for d in defs):
        return "verb"
    if lemma.endswith("ly") and len(lemma) > 5:
        return "adverb"
    if re.search(r"(tion|sion|ment|ness|ity|ance|ence|ism|ist|ship|hood)$", lemma):
        return "noun"
    if re.search(r"(ize|ise|ify)$", lemma):
        return "verb"
    if re.search(r"(ous|ful|less|ive|able|ible|ical|ary)$", lemma):
        return "adjective"
    return ""


def freq_cefr(lemma: str) -> str | None:
    z = zipf_frequency(lemma, "en")
    if z >= 4.9:
        return None  # A1-A2 territory
    if z >= 4.3:
        return "B1"
    if z >= 3.8:
        return "B2"
    if z >= 3.2:
        return "C1"
    return None


def usage_ok(toks: list[str], i: int, pos: str) -> bool:
    """Cheap context check that the token at i can be used as `pos` (no tagger available)."""
    prev = toks[i - 1].lower() if i > 0 else ""
    form_ing_ed = toks[i].lower().endswith(("ing", "ed"))
    if pos == "noun":
        return prev not in TO_AUX and prev not in SUBJ
    if pos == "verb":
        if prev in DET:
            return False
        if not form_ing_ed and prev in PREP:
            return False
        if prev == "'s" or prev == "s":
            return False
        return True
    if pos == "adjective":
        return prev not in TO_AUX
    return True


def edit_distance(a: str, b: str) -> int:
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


# ------------------------------------------------------------------ extract

def load_pairs() -> list[dict]:
    claimed: set[int] = set()
    part = json.loads((TATOEBA / "partition.json").read_text(encoding="utf-8"))
    for k, v in part.items():
        if isinstance(v, list):
            claimed.update(int(x) for x in v)
    pairs, seen = [], set()
    for line in (TATOEBA / "pairs.jsonl").read_text(encoding="utf-8").splitlines():
        r = json.loads(line)
        if r["engId"] in claimed or r["engId"] in seen:
            continue
        seen.add(r["engId"])
        pairs.append(r)
    return pairs


def extract(raw: Path, stage: Path, content: Path) -> None:
    stage.mkdir(parents=True, exist_ok=True)
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    rej: Counter = Counter()

    # ---- lists
    cj = read_cefr_profiles(raw)
    ngsl_def = read_xlsx_definitions(raw / "NGSL_12_with_English_definitions.xlsx")
    nawl_def = read_nawl_definitions(raw / "NAWL_12_with_en_definitions.csv")
    ranks = {"bsl": read_ranks(raw / "BSL_120_stats.csv"), "ngsl": read_ranks(raw / "NGSL_12_stats.csv"), "nawl": {}}
    lemma_files = {"bsl": "BSL_120_lemmatized_for_teaching.csv", "nawl": "NAWL_12_lemmatized_for_teaching.csv",
                   "ngsl": "NGSL_12_lemmatized_for_teaching.csv"}
    entries: list[dict] = []
    taken_lemmas: set[str] = set()
    all_forms: dict[str, set[str]] = {}
    for lst in LIST_ORDER:
        for n, (lemma, forms) in enumerate(read_lemma_file(raw / lemma_files[lst]), 1):
            rank = ranks[lst].get(lemma, n)
            if lst == "ngsl" and rank < NGSL_MIN_RANK:
                rej["ngsl-rank-below-800"] += 1
                continue
            if lemma in taken_lemmas:
                rej["already-in-higher-priority-list"] += 1
                continue
            if not re.fullmatch(r"[a-z]+(?:-[a-z]+)?", lemma):
                rej["non-alphabetic-headword"] += 1
                continue
            if BAD_LEMMA.match(lemma):
                rej["blocked-topic"] += 1
                continue
            taken_lemmas.add(lemma)
            entries.append({"list": lst, "lemma": lemma, "forms": [f for f in forms if f != lemma], "rank": rank})
            all_forms[lemma] = {lemma, *forms}

    # ---- dedupe against Content/vocab (headword; the plan matches headword + pos, we are stricter: headword only)
    existing_heads, existing_ids = set(), set()
    for f in sorted((content / "vocab").glob("*.json")):
        for r in json.loads(f.read_text(encoding="utf-8")):
            existing_heads.add(r["headword"].strip().lower())
            existing_ids.add(r["id"])
    for f in sorted((content / "items").glob("*.json")):
        for r in json.loads(f.read_text(encoding="utf-8")):
            existing_ids.add(r["id"])

    cands: list[dict] = []
    for e in entries:
        lemma = e["lemma"]
        if lemma in existing_heads:
            rej["headword-already-in-Content/vocab"] += 1
            continue
        defs = ngsl_def.get(lemma, [])
        nawl_entries = nawl_def.get(lemma, [])
        if e["list"] == "nawl":
            defs = defs + [d for _, d in nawl_entries]
        profiles = [(p, c, pr) for p, c, pr in cj.get(lemma, []) if p in POS_OK]
        if profiles:
            level_by_pos = {}
            for p, c, pr in profiles:
                level_by_pos.setdefault(p, (c, pr))
            if not any(c in LEVELS_OK for c, _ in level_by_pos.values()):
                low = any(c in ("A1", "A2") for c, _ in level_by_pos.values())
                rej["cefrj-A1-A2" if low else "cefrj-C2"] += 1
                continue
            e["posAll"] = sorted(level_by_pos)
            for p, (c, pr) in level_by_pos.items():
                if c in LEVELS_OK:
                    cands.append({**e, "pos": p, "cefr": c, "cefrSource": pr, "defs": defs})
        else:
            if lemma in cj:  # listed only with function-word pos (preposition, pronoun, ...)
                rej["cefrj-pos-not-noun-verb-adj-adv"] += 1
                continue
            pos = guess_pos(lemma, defs, next((p for p, _ in nawl_entries if p), ""))
            if not pos:
                rej["no-pos-and-not-in-cefrj"] += 1
                continue
            lvl = freq_cefr(lemma)
            if not lvl:
                rej["frequency-estimate-out-of-B1-C1"] += 1
                continue
            e["posAll"] = [pos]
            cands.append({**e, "pos": pos, "cefr": lvl, "cefrSource": "frequency-estimate", "defs": defs})
    n_cand = len(cands)

    # ---- sentences
    pairs = load_pairs()
    index: dict[str, list[int]] = defaultdict(list)
    toks_of: list[list[str]] = []
    for pi, p in enumerate(pairs):
        toks = TOKEN.findall(p["en"])
        toks_of.append(toks)
        for t in set(x.lower() for x in toks if x[:1].isalpha()):
            index[t].append(pi)
    dd = dedupe.DedupeIndex.from_content(content)

    def forms_for(c: dict) -> dict[str, str]:  # form -> kind
        lemma, pos = c["lemma"], c["pos"]
        out = {lemma: "base"}
        if pos in ("noun", "verb"):
            for f in c["forms"]:
                if len(f) < 3 or f in HOMOGRAPH_FORMS:
                    continue
                k = form_kind(f, lemma)
                if pos == "noun" and k != "s":
                    continue
                out[f] = k
        return out

    def sentence_options(c: dict) -> list[tuple[int, int, str, str]]:
        forms = forms_for(c)
        opts = []
        seen_pi = set()
        for f, k in forms.items():
            for pi in index.get(f, []):
                if pi in seen_pi:
                    continue
                p, toks = pairs[pi], toks_of[pi]
                n_words = sum(1 for t in toks if t[:1].isalnum())
                if not MIN_W <= n_words <= MAX_W:
                    continue
                low = [t.lower() for t in toks]
                pos_i = [i for i, t in enumerate(low) if t in forms]
                if len(pos_i) != 1:  # exactly one form of the headword in the sentence
                    continue
                i = pos_i[0]
                if i == 0 or toks[i] != low[i] or toks[i] != f:  # not sentence-initial, lowercase, exact form
                    continue
                if low.count(f) != 1 or len(re.findall(r"\b%s\b" % re.escape(f), p["en"].lower())) != 1:
                    continue
                if not usage_ok(toks, i, c["pos"]):
                    continue
                if len(c["posAll"]) > 1:  # several parts of speech in CEFR-J: the context must pick exactly one
                    if [q for q in c["posAll"] if usage_ok(toks, i, q)] != [c["pos"]]:
                        continue
                es_w = len(p["es"].split())
                if not 0.6 <= es_w / max(1, n_words) <= 1.9 or "..." in p["es"] or "…" in p["es"]:
                    continue
                seen_pi.add(pi)
                opts.append((pi, i, f, k))
        return opts

    # score and assign, list by list (BSL first); within a list the scarcest headwords pick first
    claimed_sent: set[int] = set()
    rows: list[dict] = []
    for lst in LIST_ORDER:
        group = [c for c in cands if c["list"] == lst]
        with_opts = []
        for c in group:
            o = sentence_options(c)
            if not o:
                rej[f"{lst}:no-usable-tatoeba-sentence"] += 1
                continue
            with_opts.append((c, o))
        with_opts.sort(key=lambda t: (len(t[1]), t[0]["rank"]))
        for c, opts in with_opts:
            wp_w = 3.0 if lst == "bsl" else 1.5

            def sc(o):
                p = pairs[o[0]]
                n = len(toks_of[o[0]])
                length_pref = 0.4 if 9 <= n <= 17 else 0.0
                return (wp_w * min(1.0, workplace.score(p["en"])) + length_pref,
                        hashlib.sha256(f"{c['lemma']}|{p['engId']}".encode()).hexdigest())
            for pi, i, f, k in sorted(opts, key=sc, reverse=True):
                p = pairs[pi]
                if pi in claimed_sent:
                    continue
                why = dd.check(p["en"])
                if why:
                    rej["example-duplicate-of-Content"] += 1
                    continue
                vid = ids.vocab_id(c["lemma"], c["pos"])
                if vid in existing_ids:
                    rej["id-already-in-Content"] += 1
                    break
                claimed_sent.add(pi)
                dd.add(vid, p["en"])
                ex = p["en"]
                cloze = ex.replace(f, "____", 1) if False else None
                m = list(re.finditer(r"(?<![A-Za-z'])%s(?![A-Za-z'])" % re.escape(f), ex))
                if len(m) != 1:
                    rej["cloze-not-unique"] += 1
                    claimed_sent.discard(pi)
                    continue
                cloze = ex[:m[0].start()] + "____" + ex[m[0].end():]
                defs = c["defs"]
                if c["pos"] == "verb":
                    defs = sorted(defs, key=lambda d: not d.lower().startswith("to "))
                rows.append({
                    "id": vid, "headword": c["lemma"], "pos": c["pos"], "cefr": c["cefr"], "cefrSource": c["cefrSource"],
                    "list": lst, "rank": c["rank"], "example": ex, "exampleEs": p["es"], "cloze": cloze, "answer": f,
                    "formKind": k, "definitionDraft": defs[0] if defs else "",
                    "tags": [OUT[lst][1]], "source": OUT[lst][2],
                    "sourceId": f"{lst}:{c['lemma']}|tatoeba:eng{p['engId']}({p['engOwner']})/spa{p['spaId']}({p['spaOwner']})",
                    "license": "CC BY-SA 4.0", "workplace": round(workplace.score(ex), 2),
                })
                break
            else:
                rej[f"{lst}:sentences-all-taken-or-duplicate"] += 1

    # ---- distractor candidates: same pos, same inflection kind, edit distance >= 3, from the rest of the spine
    pool: dict[tuple[str, str], list[str]] = defaultdict(list)
    for c in cands:
        if c["cefrSource"] == "frequency-estimate" and c["pos"] not in POS_OK:
            continue
        for f, k in forms_for(c).items():
            if k != "other":
                pool[(c["pos"], k)].append(f)
    for r in rows:
        key = (r["pos"], r["formKind"])
        rng = random.Random(r["id"])
        options = [w for w in pool.get(key, []) if w != r["answer"] and w != r["headword"] and edit_distance(w, r["answer"]) >= 3
                   and w not in r["example"].lower().split()]
        rng.shuffle(options)
        r["distractorCandidates"] = options[:10] if r["formKind"] != "other" else []

    # ---- order: BSL, NAWL, NGSL, then by rank
    rows.sort(key=lambda r: (LIST_ORDER.index(r["list"]), r["rank"], r["id"]))
    with (stage / "rows.jsonl").open("w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    (stage / "claimed-eng-ids.json").write_text(json.dumps(sorted(int(re.search(r"eng(\d+)", r["sourceId"]).group(1)) for r in rows)) + "\n")

    # ---- report
    L = ["# Vocab (C16) extract report", "",
         "Licenses verified at the source on fetch (see `.ingest/raw/vocab/license-check.json`): BSL/NAWL/NGSL CC BY-SA 4.0; CEFR-J free for research/commercial use with citation; Octanove C1/C2 CC BY-SA 4.0; Tatoeba CC BY 2.0 FR.", "",
         f"- headword-pos candidates after list/CEFR/dedupe filters: {n_cand}",
         f"- Tatoeba pairs available (not claimed by listenRepeat/translate): {len(pairs)}",
         f"- staged rows (headword + example, waiting for the LLM fill): {len(rows)}", ""]
    for lst in LIST_ORDER:
        L.append(f"  - {lst}: {sum(r['list'] == lst for r in rows)}")
    L += ["", "## Reject reasons", ""] + [f"- {k}: {v}" for k, v in sorted(rej.items())]
    L += ["", "## Level / POS / CEFR source", ""]
    L += [f"- {k}: {v}" for k, v in sorted(Counter(r['cefr'] for r in rows).items())]
    L += [f"- pos {k}: {v}" for k, v in sorted(Counter(r['pos'] for r in rows).items())]
    L += [f"- cefrSource {k}: {v}" for k, v in sorted(Counter(r['cefrSource'] for r in rows).items())]
    L += [f"- formKind {k}: {v}" for k, v in sorted(Counter(r['formKind'] for r in rows).items())]
    L += [f"- rows with distractor candidates: {sum(bool(r['distractorCandidates']) for r in rows)}",
          f"- rows with a definition draft: {sum(bool(r['definitionDraft']) for r in rows)}",
          f"- rows with workplace score >= 0.04: {sum(r['workplace'] >= 0.04 for r in rows)}", "",
          "## 30-row random sample", ""]
    rr = random.Random(7)
    for r in rr.sample(rows, min(30, len(rows))):
        L.append(f"- [{r['list']}] {r['headword']} ({r['pos']}, {r['cefr']}, {r['cefrSource']}): {r['cloze']}  /  {r['exampleEs']}")
    REPORT.write_text("\n".join(L) + "\n", encoding="utf-8")
    print(f"staged {len(rows)} rows -> {stage / 'rows.jsonl'}; report {REPORT}")


# ------------------------------------------------------------------ batches

FILL_KEYS = ["es", "definition", "distractors", "collocations", "note", "reject", "rejectReason"]
BATCH_FIELDS = ["id", "headword", "pos", "cefr", "tags", "example", "exampleEs", "cloze", "answer", "formKind",
                "definitionDraft", "distractorCandidates"]


def batches(stage: Path) -> None:
    rows = [json.loads(l) for l in (stage / "rows.jsonl").read_text(encoding="utf-8").splitlines()]
    out = stage / "batches"
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("batch-*.jsonl"):
        old.unlink()
    n = len(rows)
    k = max(1, round(n / 50))
    while n / k > BATCH_MAX:
        k += 1
    while k > 1 and n / k < BATCH_MIN:
        k -= 1
    sizes = [n // k + (1 if i < n % k else 0) for i in range(k)]
    paths, pos = [], 0
    for bi, s in enumerate(sizes, 1):
        p = out / f"batch-{bi:04d}.jsonl"
        with p.open("w", encoding="utf-8") as f:
            for r in rows[pos:pos + s]:
                f.write(json.dumps({x: r[x] for x in BATCH_FIELDS}, ensure_ascii=False) + "\n")
        pos += s
        paths.append(str(p))
    print(f"{n} rows -> {k} batches of {min(sizes)}-{max(sizes)}")
    print("\n".join(paths))


# ------------------------------------------------------------------ emit

def _fill_problems(r: dict, f: dict) -> list[str]:
    p = []
    for k in ("es", "definition", "note"):
        if not isinstance(f.get(k), str):
            p.append(f"{k} missing")
    if not (isinstance(f.get("es"), str) and f["es"].strip()):
        p.append("es empty")
    if not (isinstance(f.get("definition"), str) and f["definition"].strip()):
        p.append("definition empty")
    d = f.get("distractors")
    if not (isinstance(d, list) and len(d) == 3 and all(isinstance(x, str) and x.strip() for x in d)):
        p.append("distractors must be 3 strings")
    c = f.get("collocations")
    if not (isinstance(c, list) and 2 <= len(c) <= 3 and all(isinstance(x, str) and x.strip() for x in c)):
        p.append("collocations must be 2-3 strings")
    if isinstance(d, list):
        low = [x.lower() for x in d if isinstance(x, str)]
        if r["answer"].lower() in low or len(set(low)) != len(low):
            p.append("distractors duplicate or equal answer")
        words = set(re.findall(r"[a-z']+", r["example"].lower()))
        if any(x in words for x in low):
            p.append("a distractor already appears in the example")
    if isinstance(f.get("definition"), str) and re.search(r"\b%s\b" % re.escape(r["headword"]), f["definition"].lower()):
        p.append("definition uses the headword")
    return p


# Read-through of the 30-item sample plus a scan of verb rows whose Spanish gloss is a participle:
# these use the word as a participial adjective (not the verb sense) or have non-fitting distractors.
POST_DROP = {
    "v-qualify-verb": "participial adjective", "v-complicate-verb": "participial adjective",
    "v-disappoint-verb": "participial adjective", "v-differ-verb": "participial adjective",
    "v-educate-verb": "participial adjective", "v-sustain-verb": "participial adjective",
    "v-scatter-verb": "participial adjective", "v-file-verb": "rare sense (limar), not workplace",
    "v-shower-verb": "distractors apologize/invest/negotiate also fit the cloze",
}


def emit(stage: Path, content: Path) -> None:
    rows = {}
    for l in (stage / "rows.jsonl").read_text(encoding="utf-8").splitlines():
        r = json.loads(l)
        rows[r["id"]] = r
    fills, missing = {}, []
    batch_of: dict[str, str] = {}
    for fp in sorted((stage / "batches").glob("batch-*.filled.jsonl")):
        for l in fp.read_text(encoding="utf-8").splitlines():
            if l.strip():
                f = json.loads(l)
                fills[f["id"]] = f
                batch_of[f["id"]] = fp.name.split(".")[0]
    per_batch: dict[str, Counter] = defaultdict(Counter)
    emitted: list[dict] = []
    by_list: dict[str, list[dict]] = defaultdict(list)
    drops: Counter = Counter()
    for rid, r in rows.items():
        f = fills.get(rid)
        if not f:
            missing.append(rid)
            continue
        bn = batch_of[rid]
        if rid in POST_DROP:
            drops[f"post-review: {POST_DROP[rid]}"] += 1
            per_batch[bn]["rows"] += 1
            per_batch[bn]["post-review"] += 1
            continue
        per_batch[bn]["rows"] += 1
        if f.get("reject"):
            drops["llm-reject"] += 1
            per_batch[bn]["llm-reject"] += 1
            continue
        pr = _fill_problems(r, f)
        if pr:
            drops["fill-problems: " + "; ".join(pr)[:80]] += 1
            per_batch[bn]["fill-problems"] += 1
            continue
        entry = {
            "id": r["id"], "headword": r["headword"], "pos": r["pos"], "cefr": r["cefr"], "es": f["es"].strip(),
            "definition": f["definition"].strip(), "example": r["example"], "exampleEs": r["exampleEs"], "cloze": r["cloze"],
            "answer": r["answer"], "distractors": [x.strip() for x in f["distractors"]],
            "collocations": [x.strip() for x in f["collocations"]], "note": f["note"].strip(), "tags": r["tags"],
            "source": r["source"], "sourceId": r["sourceId"], "license": r["license"],
        }
        pr = schema.problems_vocab(entry)
        if pr and any("note" in x for x in pr):
            entry["note"] = ""  # optional tip tripped the tokenizer check: keep the item, drop only the tip
            drops["note-blanked (schema)"] += 1
            pr = schema.problems_vocab(entry)
        if pr:
            drops["schema: " + "; ".join(pr)[:80]] += 1
            per_batch[bn]["schema"] += 1
            continue
        per_batch[bn]["shipped"] += 1
        entry["_list"] = r["list"]
        emitted.append(entry)
        by_list[r["list"]].append(entry)
    for lst, (fname, _, sname, url) in OUT.items():
        if not by_list[lst]:
            continue
        info = emitlib.emit(
            content, "vocab", fname, by_list[lst], source=sname, url=url, license="CC BY-SA 4.0", tier="share-alike",
            attribution=("Headwords: Browne, Culligan & Phillips, New General Service List / New Academic Word List / "
                         "Business Service List (newgeneralservicelist.com), CC BY-SA 4.0; levels: CEFR-J Vocabulary Profile 1.5 "
                         "(Tono Laboratory, TUFS) and Octanove Vocabulary Profile C1/C2 (CC BY-SA 4.0); examples: Tatoeba "
                         "(CC BY 2.0 FR, authors in sourceId); Spanish glosses, definitions, distractors, collocations and notes "
                         "written with Claude."))
        print(lst, len(by_list[lst]), "->", fname)
    for lst in by_list:
        for e in by_list[lst]:
            e.pop("_list", None)
    print("missing fills:", len(missing), "| dropped:", dict(drops))
    _report(per_batch, emitted, drops, missing, by_list)


def _report(per_batch, emitted, drops, missing, by_list) -> None:
    lines = ["", "## Emit (fill merge)", "", f"- shipped: {len(emitted)} ({', '.join(f'{k} {len(v)}' for k, v in by_list.items())})",
             f"- missing fills: {len(missing)}"]
    for k, v in sorted(drops.items()):
        lines.append(f"- dropped, {k}: {v}")
    lines += ["", "### Reject rate per batch", "", "| batch | rows | shipped | rejected | rate |", "|---|---|---|---|---|"]
    for b, c in sorted(per_batch.items()):
        rej = c["rows"] - c["shipped"]
        rate = rej / c["rows"] if c["rows"] else 0
        lines.append(f"| {b} | {c['rows']} | {c['shipped']} | {rej} | {rate:.0%}{' **>30%**' if rate > 0.3 else ''} |")
    lines += ["", "Batches above 30%: the fill agents rejected for cloze ambiguity (several words fit), pos/sense mismatch with the "
              "Tatoeba sentence, or topic (violent/political/religious). Batches 9-12 and 23 cover concrete, low-context nouns "
              "(anatomy, science, school subjects) where short Tatoeba sentences rarely single out one word; rejecting them is the intended "
              "behaviour (fewer clean items over many noisy ones)."]
    for title, key in (("CEFR", "cefr"), ("POS", "pos")):
        lines += ["", f"### {title}", ""] + [f"- {k}: {v}" for k, v in sorted(Counter(e[key] for e in emitted).items())]
    lines += ["", "### Workplace tag", "", f"- tagged workplace: {sum('workplace' in e['tags'] for e in emitted)}"]
    lines += ["", "### Random sample (30, seed 16)", ""]
    for e in random.Random(16).sample(emitted, min(30, len(emitted))):
        lines.append(f"- **{e['headword']}** ({e['pos']}, {e['cefr']}) = {e['es']} | {e['cloze']} -> {e['answer']} | "
                     f"x: {', '.join(e['distractors'])} | col: {', '.join(e['collocations'])} | {e['note']}")
    txt = REPORT.read_text(encoding="utf-8")
    txt = txt.split("\n## Emit (fill merge)")[0].rstrip("\n") + "\n" + "\n".join(lines) + "\n"
    REPORT.write_text(txt, encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    f = sub.add_parser("fetch"); f.add_argument("--raw", type=Path, default=RAW)
    e = sub.add_parser("extract"); e.add_argument("--raw", type=Path, default=RAW); e.add_argument("--stage", type=Path, default=STAGE)
    e.add_argument("--content", type=Path, default=ROOT / "Content")
    b = sub.add_parser("batches"); b.add_argument("--stage", type=Path, default=STAGE)
    m = sub.add_parser("emit"); m.add_argument("--stage", type=Path, default=STAGE); m.add_argument("--content", type=Path, default=ROOT / "Content")
    a = ap.parse_args()
    if a.cmd == "fetch":
        fetch(a.raw)
    elif a.cmd == "extract":
        extract(a.raw, a.stage, a.content)
    elif a.cmd == "batches":
        batches(a.stage)
    else:
        emit(a.stage, a.content)


if __name__ == "__main__":
    main()
