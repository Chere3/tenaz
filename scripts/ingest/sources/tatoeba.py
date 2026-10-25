"""C08 Tatoeba converter (CC BY 2.0 FR): listenRepeat + lifeParagraph kind "translate" + staged EN-ES pairs.

  fetch    downloads the per-language exports into .ingest/raw/tatoeba/ (data only, never executed)
  extract  filters, dedupes, selects -> .ingest/stage/tatoeba/*.jsonl + .ingest/reports/tatoeba.md
  emit     stage -> Content/items/listen-repeat-tatoeba.json, life-translate-tatoeba.json

Run: uv run --project scripts/ingest python -I scripts/ingest/sources/tatoeba.py <cmd>
"""
from __future__ import annotations

import argparse
import bz2
import hashlib
import json
import random
import re
import sys
import tarfile
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lib import cefr, ids, textnorm, workplace  # noqa: E402
from lib.dedupe import DedupeIndex  # noqa: E402

BASE = "https://downloads.tatoeba.org/exports"
FILES = {
    "eng_sentences_detailed.tsv.bz2": f"{BASE}/per_language/eng/eng_sentences_detailed.tsv.bz2",
    "spa_sentences_detailed.tsv.bz2": f"{BASE}/per_language/spa/spa_sentences_detailed.tsv.bz2",
    "eng-spa_links.tsv.bz2": f"{BASE}/per_language/eng/eng-spa_links.tsv.bz2",
    "user_languages.tar.bz2": f"{BASE}/user_languages.tar.bz2",
}
SOURCE = "Tatoeba"
URL = "https://tatoeba.org/en/downloads"
LICENSE = "CC BY 2.0 FR"

TARGET_LR = 700
TARGET_TR = 150

# --- blocklists (whole-word, lowercase) -------------------------------------------------------
OFFENSIVE = set("""
kidnap kidnapped kidnapper kidnappers hostage humiliation communism communist socialism capitalism campaign immigrant immigrants refugee refugees
sex sexy sexual sexually naked nude porn rape raped rapist kill kills killed killing murder murdered murderer
suicide suicidal die dies died dying dead death corpse funeral drunk drunken drug drugs cocaine heroin marijuana
weed gun guns shoot shot shooting bomb bombs terror terrorist terrorists war wars army soldier soldiers weapon
weapons fuck fucking shit damn bitch bastard ass asshole crap hell idiot idiots stupid fool dumb ugly fat hate
hated hates kiss kissed kisses boyfriend girlfriend pregnant pregnancy abortion boobs breast breasts penis
vagina gay lesbian racist racism nazi hitler slave slaves jail prison arrested criminal thief steal stole
stolen cheat cheating affair divorce divorced widow cancer disease sick cry cried crying tears tear blood
bleeding ghost ghosts witch devil satan hell god gods jesus allah church mosque jewish muslim muslims
christian christians islam bible pray prayer religion religious trump obama politician politicians
vote election elections president
""".split())
CHILDISH = set("""
mommy daddy mum toy toys kid kids child children baby babies puppy puppies kitten kittens cartoon cartoons
santa teddy doll dolls candy candies pajamas bedtime homework playground nursery kindergarten lollipop
bunny bunnies fairy fairies princess prince magic magical unicorn dragon dragons monster monsters
ice-cream icecream lego cookie cookies cake birthday balloon balloons crayon crayons toilet pee poop
fart farts diaper naughty spank spanked grandma grandpa grandmother grandfather boys girls boy girl
sweetie honey darling dear sweetheart tomorrow's
""".split())
# lib.workplace.LEXICON is built with str.split(), so "lead time" / "follow up" leak the generic words below.
GENERIC = set("""time up lead follow order orders process issue issues review report reports update request requests
schedule cost costs supply demand quality risk risks team minutes stock hire project projects feedback
payment payments delivery deliveries contract contracts client clients customer customers manager""".split()) - set(
    "contract contracts client clients customer customers manager delivery deliveries payment payments report reports project projects team".split())
# proper-noun-ish words that are fine capitalised mid-sentence are NOT allowed except these.
CAP_OK = {"I"}
_WORD = re.compile(r"[A-Za-z]+(?:'[a-z]+)?")
_OK_CHARS = re.compile(r"^[A-Za-z',.?! -]+$")
_ES_OK_CHARS = re.compile(r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ¿¡',.?! -]+$")
_ELL = re.compile(r"\.\.|--")


def _w(s: str) -> list[str]:
    return [t.lower() for t in re.findall(r"[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+(?:-[A-Za-z]+)*", s)]


# --- fetch -----------------------------------------------------------------------------------
def fetch(raw: Path) -> None:
    raw.mkdir(parents=True, exist_ok=True)
    for name, url in FILES.items():
        dest = raw / name
        if dest.exists():
            continue
        print("downloading", url)
        with urllib.request.urlopen(url) as r, open(dest, "wb") as f:
            while chunk := r.read(1 << 20):
                f.write(chunk)
    csv = raw / "user_languages.csv"
    if not csv.exists():
        with tarfile.open(raw / "user_languages.tar.bz2", "r:bz2") as t:
            m = next(x for x in t.getmembers() if x.name.endswith("user_languages.csv"))
            data = t.extractfile(m).read()  # data only: read bytes, write one known filename
        csv.write_bytes(data)


# --- loaders (data only) ---------------------------------------------------------------------
def load_native(raw: Path, lang: str, min_level: int) -> set[str]:
    out = set()
    with open(raw / "user_languages.csv", encoding="utf-8") as f:
        for line in f:
            p = line.rstrip("\n").split("\t")
            if len(p) >= 3 and p[0] == lang and p[1].isdigit() and int(p[1]) >= min_level and p[2]:
                out.add(p[2])
    return out


def load_sentences(path: Path, native: set[str]) -> dict[int, tuple[str, str]]:
    """id -> (text, owner) for sentences whose owner is a native speaker."""
    out = {}
    with bz2.open(path, "rt", encoding="utf-8") as f:
        for line in f:
            p = line.rstrip("\n").split("\t")
            if len(p) >= 4 and p[3] in native:
                out[int(p[0])] = (p[2], p[3])
    return out


def load_all_text(path: Path) -> dict[int, str]:
    out = {}
    with bz2.open(path, "rt", encoding="utf-8") as f:
        for line in f:
            p = line.rstrip("\n").split("\t")
            if len(p) >= 3:
                out[int(p[0])] = p[2]
    return out


# --- filters ---------------------------------------------------------------------------------
def reject_reason(text: str, lang: str, lo: int, hi: int) -> str | None:
    """None if the sentence is clean enough for a learner (adult, natural, no names/digits/quotes)."""
    n = len(text.split())
    if not lo <= n <= hi:
        return "length"
    if not (_OK_CHARS if lang == "en" else _ES_OK_CHARS).match(text):
        return "chars"  # digits, quotes, parentheses, colons, semicolons, symbols
    if _ELL.search(text):
        return "ellipsis"
    if text[-1] not in ".?!":
        return "no-terminal-punct"
    if text.count("?") + text.count("!") + text.count(".") > (2 if lang == "es" else 1):
        return "multi-sentence" if lang == "en" else "too-many-sentences"
    toks = text.split()
    if lang == "en":
        if not toks[0][0].isupper():
            return "lowercase-start"
        for i, t in enumerate(toks[1:], 1):
            core = re.sub(r"[^A-Za-z']", "", t)
            if core and core[0].isupper() and core not in CAP_OK and not core.startswith("I'"):
                prev = toks[i - 1]
                if prev[-1] not in ".?!":
                    return "proper-noun"
        if toks[0].strip(",.?!") in {"Tom", "Mary", "John", "Ann", "Bob", "Alice", "Mr", "Mrs", "Ms", "Dr"}:
            return "proper-noun"
        low = _w(text)
        if any(t in OFFENSIVE for t in low):
            return "offensive"
        if any(t in CHILDISH for t in low):
            return "childish"
        from wordfreq import zipf_frequency
        for t in low:
            base = t.split("'")[0] or t
            if len(base) > 1 and zipf_frequency(base, "en") < 1.8 and not t.endswith("n't"):
                return "rare-or-typo"
        if re.search(r"\b(?:Tom|Mary|Tatoeba)\b", text):
            return "proper-noun"
    else:
        low = _w(text)
        if any(t in {"sexo", "sexual", "matar", "muerte", "muerto", "violación", "droga", "drogas", "desnudo",
                     "puta", "mierda", "joder", "coño", "culo", "pene", "guerra", "terrorista", "suicidio",
                     "asesinato", "asesinar", "mamá", "papá", "juguete", "juguetes", "niñito", "cuento"} for t in low):
            return "offensive-es"
        for i, t in enumerate(toks[1:], 1):
            core = re.sub(r"[^A-Za-zÁÉÍÓÚÜÑáéíóúüñ]", "", t)
            if core and core[0].isupper() and not toks[i - 1].endswith(("¿", "¡", ".", "?", "!")):
                return "proper-noun"
        if re.match(r"^(Tom|María|Mary|Juan|Ben|Ana|Pedro|Carlos|Luis|Jack|John|Pablo|Marta|Sara|Laura|Paco|Bob|Alice|Ann|Jim|Tim)\b", text):
            return "proper-noun"
    return None


def clean_en(text: str) -> str:
    return textnorm.clean_sentence(text)


def wp_score(text: str) -> float:
    toks = _w(text)
    if not toks:
        return 0.0
    hits = sum(1 for t in toks if t in workplace.LEXICON and t not in GENERIC)
    return min(1.0, hits / len(toks) * 5)


def pick_voice(key: str) -> str:
    return "female" if int(hashlib.sha256(key.encode()).hexdigest(), 16) % 2 == 0 else "male"


# --- extract ---------------------------------------------------------------------------------
def extract(raw: Path, stage: Path, report: Path, content: Path) -> None:
    stage.mkdir(parents=True, exist_ok=True)
    report.parent.mkdir(parents=True, exist_ok=True)
    en_native = load_native(raw, "eng", 5)
    es_native = load_native(raw, "spa", 5)
    en = load_sentences(raw / "eng_sentences_detailed.tsv.bz2", en_native)
    es = load_sentences(raw / "spa_sentences_detailed.tsv.bz2", es_native)
    en_all = load_all_text(raw / "eng_sentences_detailed.tsv.bz2")
    links: dict[int, list[int]] = defaultdict(list)  # eng id -> spa ids
    es_links: dict[int, list[int]] = defaultdict(list)  # spa id -> eng ids
    with bz2.open(raw / "eng-spa_links.tsv.bz2", "rt", encoding="utf-8") as f:
        for line in f:
            a, b = line.split()[:2]
            links[int(a)].append(int(b))
            es_links[int(b)].append(int(a))
    rej: Counter = Counter()
    rej["native-owner-sentences-en"] = len(en)
    rej["native-owner-sentences-es"] = len(es)

    idx = DedupeIndex.from_content(content)
    # ---- English candidates (listenRepeat + pairs) ----
    cands = []
    for eid, (text, owner) in sorted(en.items()):
        r = reject_reason(text, "en", 8, 18)
        if r:
            rej["en:" + r] += 1
            continue
        if eid not in links:
            rej["en:no-spanish-link"] += 1
            continue
        t = clean_en(text)
        wp = wp_score(t)
        lvl = cefr.estimate(t)
        cands.append({"engId": eid, "owner": owner, "text": t, "workplace": round(wp, 3), "cefr": lvl,
                      "spaIds": links[eid], "words": len(t.split())})
    rej["en:candidates-after-filters"] = len(cands)

    # ---- staged EN-ES pairs for vocab examples (every clean native EN with native ES) ----
    pairs = []
    for c in cands:
        for sid in c["spaIds"]:
            if sid in es and not reject_reason(es[sid][0], "es", 4, 30):
                pairs.append({"engId": c["engId"], "engOwner": c["owner"], "en": c["text"], "spaId": sid,
                              "spaOwner": es[sid][1], "es": es[sid][0], "cefr": c["cefr"],
                              "workplace": c["workplace"]})
    with open(stage / "pairs.jsonl", "w", encoding="utf-8") as f:
        for p in pairs:
            f.write(json.dumps(p, ensure_ascii=False) + "\n")

    # ---- listenRepeat selection ----
    # Rank: workplace relevance first, then richer sentences (B1+..C1, 10-16 words), then a stable hash.
    def lr_rank(c):
        lvl_bonus = {"B1": 0, "B1+": 1, "B2": 2, "B2+": 2, "C1": 1}[c["cefr"]]
        len_ok = 1 if 9 <= c["words"] <= 16 else 0
        return (-(c["workplace"] >= 0.2), -c["workplace"], -lvl_bonus, -len_ok,
                hashlib.sha256(str(c["engId"]).encode()).hexdigest())
    lr_rows, used_eng = [], set()
    reasons_dd = Counter()
    for c in sorted(cands, key=lr_rank):
        if len(lr_rows) >= TARGET_LR:
            break
        if c["workplace"] < 0.2 and c["cefr"] == "B1" and c["words"] < 10:
            reasons_dd["too-plain"] += 1
            continue
        iid = ids.item_id("listenRepeat", "tatoeba", str(c["engId"]))
        d = idx.check_and_add(iid, c["text"])
        if d:
            reasons_dd["dedupe"] += 1
            continue
        used_eng.add(c["engId"])
        lr_rows.append({"id": iid, "type": "listenRepeat", "cefr": c["cefr"], "skill": "speaking",
                        "sentence": c["text"], "voice": pick_voice(str(c["engId"])), "source": "tatoeba",
                        "sourceId": f"{c['engId']}/{c['owner']}", "license": LICENSE, "origin": "verbatim",
                        "tier": "permissive", "group": f"tatoeba-{c['engId']}"})
    rej.update({"lr:" + k: v for k, v in reasons_dd.items()})
    with open(stage / "listen-repeat.jsonl", "w", encoding="utf-8") as f:
        for r in lr_rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    # ---- translate selection ----
    tr_cands = []
    for sid, (text, owner) in sorted(es.items()):
        if sid not in es_links:
            continue
        r = reject_reason(text, "es", 9, 25)
        if r:
            rej["tr:" + r] += 1
            continue
        refs = []
        for eid in es_links[sid]:
            if eid in used_eng:
                continue  # partition: an English sentence id is used by exactly one type
            raw_en = en_all.get(eid)
            if not raw_en or reject_reason(raw_en, "en", 5, 30):
                continue
            refs.append((eid, clean_en(raw_en), eid in en))
        if not refs or not any(native for _, _, native in refs):
            rej["tr:no-clean-native-english-ref"] += 1
            continue
        best = max(refs, key=lambda x: (x[2], -abs(len(x[1].split()) - 14)))[1]
        wp = max(wp_score(t) for _, t, _ in refs)
        tr_cands.append({"spaId": sid, "owner": owner, "es": textnorm.fix_unicode(text).strip(),
                         "refs": refs, "best": best, "workplace": wp, "cefr": cefr.estimate(best)})
    rej["tr:candidates-after-filters"] = len(tr_cands)

    def tr_rank(c):
        lvl_bonus = {"B1": 0, "B1+": 1, "B2": 2, "B2+": 2, "C1": 1}[c["cefr"]]
        return (-(c["workplace"] >= 0.2), -min(len(c["refs"]), 3), -lvl_bonus, -c["workplace"],
                hashlib.sha256(str(c["spaId"]).encode()).hexdigest())
    tr_rows, used_in_tr = [], set()
    for c in sorted(tr_cands, key=tr_rank):
        if len(tr_rows) >= TARGET_TR:
            break
        if any(e in used_in_tr for e, _, _ in c["refs"]):
            rej["tr:shared-english-ref"] += 1
            continue
        iid = ids.item_id("lifeParagraph", "tatoeba", f"tr-{c['spaId']}")
        d = idx.check_and_add(iid, c["best"])
        if d:
            rej["tr:dedupe"] += 1
            continue
        refs_text = [t for _, t, _ in sorted(c["refs"], key=lambda x: (not x[2], x[0]))]
        refs_text = list(dict.fromkeys(refs_text))
        used_in_tr.update(e for e, _, _ in c["refs"])
        must = pick_must_use(refs_text)
        tr_rows.append({"id": iid, "type": "lifeParagraph", "cefr": c["cefr"], "skill": "writing",
                        "kind": "translate", "prompt": "Translate into natural English.", "text": c["es"],
                        "reference": refs_text, "mustUse": must,
                        "minWords": max(40, min(80, round(1.2 * len(c["best"].split())))),
                        "source": "tatoeba",
                        "sourceId": f"{c['spaId']}/{c['owner']}", "license": LICENSE, "origin": "verbatim",
                        "tier": "permissive", "group": f"tatoeba-es-{c['spaId']}"})
    with open(stage / "translate.jsonl", "w", encoding="utf-8") as f:
        for r in tr_rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    with open(stage / "partition.json", "w", encoding="utf-8") as f:
        json.dump({"listenRepeat_eng_ids": sorted(used_eng),
                   "translate_eng_ids": sorted(used_in_tr)}, f)

    write_report(report, rej, lr_rows, tr_rows, len(pairs))
    print(f"listenRepeat {len(lr_rows)}  translate {len(tr_rows)}  pairs {len(pairs)}")


_STOP = set("""a an the and or but of to in on at for with from by is are was were be been am i you he she it we they
my your his her our their this that these those not no do does did have has had will would can could should
there here as if so than then too very just""".split())


def pick_must_use(refs: list[str]) -> list[str]:
    """lib.schema rejects mustUse == [] for lifeParagraph, so pick one content word that every reference
    shares (else the longest content word of the first reference). Grading treats it as a soft target."""
    sets = [set(w for w in _w(r) if w not in _STOP and len(w) > 3) for r in refs]
    common = set.intersection(*sets) if sets else set()
    from wordfreq import zipf_frequency
    def ok(w):
        return zipf_frequency(w, "en") < 5.2 and w not in {"something", "going", "together", "nothing", "because", "always", "never", "every", "about", "would", "could", "there", "their", "which", "other"}
    pool = [w for w in sorted(common or sets[0], key=lambda w: (-len(w), w)) if ok(w)] or sorted(common or sets[0])
    return [pool[0]] if pool else [refs[0].split()[1] if len(refs[0].split()) > 1 else refs[0].split()[0]]


def write_report(path: Path, rej: Counter, lr: list[dict], tr: list[dict], npairs: int) -> None:
    rng = random.Random(7)
    lines = ["# Tatoeba (C08) extract report", "",
             f"License: {LICENSE} (verified at https://tatoeba.org/en/terms_of_use section 6.2 and /en/downloads, 2026-10-23).",
             "Only sentences owned by self-declared native speakers (user_languages level 5) are used.", "",
             f"- listenRepeat selected: {len(lr)}", f"- translate selected: {len(tr)}",
             f"- staged EN-ES pairs (vocab examples): {npairs}", "", "## Counts / reject reasons", ""]
    lines += [f"- {k}: {v}" for k, v in sorted(rej.items())]
    for title, rows, fmt in (("listenRepeat", lr, lambda r: f"{r['cefr']} | {r['sentence']}"),
                             ("translate", tr, lambda r: f"{r['cefr']} | {r['text']}  =>  {'  //  '.join(r['reference'])}  [mustUse={r['mustUse']}]")):
        lines += ["", f"## Level distribution: {title}", ""]
        lines += [f"- {k}: {v}" for k, v in sorted(Counter(r['cefr'] for r in rows).items())]
        lines += ["", f"## 30-item random sample: {title}", ""]
        lines += [f"{i}. {fmt(r)}" for i, r in enumerate(rng.sample(rows, min(30, len(rows))), 1)]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


# --- emit ------------------------------------------------------------------------------------
def emit_cmd(stage: Path, content: Path) -> None:
    from lib.emit import emit
    attribution = ("Sentences from Tatoeba (tatoeba.org), CC BY 2.0 FR; each sentence's contributor is recorded in "
                   "sourceId as <sentenceId>/<username>.")
    for fname, stagefile in (("listen-repeat-tatoeba.json", "listen-repeat.jsonl"),
                             ("life-translate-tatoeba.json", "translate.jsonl")):
        rows = [json.loads(l) for l in (stage / stagefile).read_text(encoding="utf-8").splitlines() if l.strip()]
        e = emit(content, "items", fname, rows, source=SOURCE, url=URL, license=LICENSE, tier="permissive",
                 attribution=attribution)
        print("emitted", fname, e["items"])


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["fetch", "extract", "emit"])
    ap.add_argument("--raw", default=".ingest/raw/tatoeba")
    ap.add_argument("--stage", default=".ingest/stage/tatoeba")
    ap.add_argument("--report", default=".ingest/reports/tatoeba.md")
    ap.add_argument("--content", default="Content")
    a = ap.parse_args()
    if a.cmd == "fetch":
        fetch(Path(a.raw))
    elif a.cmd == "extract":
        extract(Path(a.raw), Path(a.stage), Path(a.report), Path(a.content))
    else:
        emit_cmd(Path(a.stage), Path(a.content))


if __name__ == "__main__":
    main()
