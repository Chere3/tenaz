"""P4 grammarMC from dry-melon Chinese middle-school English exam MCQs (grades 8, 9): fetch / extract / emit.

  fetch    checks the license tag at the source (cc-by-4.0 uploader tag; upstream exam copyright is NOT cleared -> tier "unclear"),
           downloads grade8/grade9 Multiple-Choice-Question.jsonl into .ingest/raw/drymelon/
  extract  parses raw/ as data only -> .ingest/stage/drymelon/{candidates.jsonl, selection.json, batches/batch-NNN.jsonl}
           and .ingest/reports/drymelon.md.  Filters: single <blank>, 4 distinct short ASCII options, grammar/vocab test_points
           only, adult/natural register, dedupe against all of Content/ and within the set, per-key caps for variety.
  emit     (after the fill agents wrote batches/batch-NNN.filled.jsonl) -> Content/items/grammar-drymelon.nc.json

The batch rows do NOT contain the source key: the fill agent solves each item blind (blindAnswer) and writes the explanation
for its own answer; emit keeps a row only when blindAnswer == the source key (stored in candidates.jsonl).
Run:  uv run --project scripts/ingest python -I scripts/ingest/sources/drymelon.py fetch|extract|emit
"""
from __future__ import annotations

import argparse
import hashlib
import json
import random
import re
import sys
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib import cefr, ids, schema, textnorm, workplace  # noqa: E402
from lib.dedupe import DedupeIndex, item_text  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
SRC = "drymelon"
REPO = "dry-melon/Chinese-middle-school-English-exam-questions"
API = f"https://huggingface.co/api/datasets/{REPO}"
FILE_URL = f"https://huggingface.co/datasets/{REPO}/resolve/main/dataset/grade{{g}}/Multiple-Choice-Question.jsonl"
OUT_FILE = "grammar-drymelon.nc.json"
LICENSE = ("CC BY 4.0 as tagged by the uploader (dry-melon). The card says the exam questions were compiled from public "
           "Chinese exam sites and 'assumed' to be educational fair use / public domain, so upstream copyright is not cleared")
NOART = "(no article)"
STAGE_TARGET = 2000   # staged rows; final cap 1,500 after blind-verify rejects

# test_point head -> (patternHint, priority weight). None = drop the row.
HEAD_MAP = {
    "prepositions": ("preposition", 1.0), "preposition": ("preposition", 1.0),
    "verb tenses": ("tense", 1.0), "verb tense": ("tense", 1.0), "tenses": ("tense", 1.0), "tense": ("tense", 1.0),
    "gerunds & infinitives": ("verb-pattern", 1.2), "infinitives": ("verb-pattern", 1.0), "infinitive": ("verb-pattern", 1.0),
    "gerunds": ("verb-pattern", 1.0), "infinitive phrase": ("verb-pattern", 0.8),
    "modal verbs": ("modal", 1.0), "modal verb": ("modal", 1.0),
    "passive voice": ("passive", 1.3), "conditional sentences": ("conditional", 1.5), "conditionals": ("conditional", 1.5),
    "relative clauses": ("relative", 1.5), "reported speech": ("tense", 1.2),
    "articles": ("article", 1.0), "subject-verb agreement": ("agreement", 1.0),
    "countable & uncountable nouns": ("agreement", 0.8), "determiners": ("agreement", 0.7),
    "conjunctions": ("linker", 1.0), "logical connectors": ("linker", 1.2),
    "comparatives & superlatives": ("word-form", 0.8), "word formation": ("word-form", 1.2), "adjectives": ("word-form", 0.7),
    "adverbs": ("word-form", 0.7), "nouns": ("word-form", 0.6), "pronouns": ("word-form", 0.7),
    "collocations": ("collocation", 1.2), "fixed expressions": ("collocation", 0.9), "phrasal verbs": ("collocation", 1.1),
    "idioms & phrases": ("collocation", 0.6), "vocabulary": ("collocation", 0.6), "contextual vocabulary": ("collocation", 0.6),
    "common expressions": ("collocation", 0.5),
}
DROP_HEADS = {"phonetics", "pronunciation", "conversational english", "situational dialogues", "listening comprehension",
              "reading comprehension", "question formation", "sentence structure", "word order", "fixed sentence patterns",
              "time expressions", "adverbs of frequency", "synonyms & antonyms", "sentence completion", "grammar"}

# childish, school-register, Chinese-exam-specific or sensitive content (adult/natural register only)
BLOCK = re.compile(r"""\b(sex\w*|porn\w*|rape\w*|nude|naked|fuck\w*|shit\w*|bitch\w*|slut\w*|whore\w*|penis|vagina|kill\w*|
 murder\w*|suicid\w*|massacre\w*|genocide|holocaust|nazi\w*|terroris\w*|bomb\w*|weapon\w*|gun|guns|shoot\w*|slave\w*|racis\w*|
 negro|jew\w*|muslim\w*|islam\w*|christ\w*|jesus|god|allah|church\w*|pope|religio\w*|abortion|drug\w*|cocaine|heroin|alcohol\w*|
 drunk|cancer|death|dead|die|died|dying|corpse|war|wars|battle\w*|soldier\w*|army|troops|prison\w*|crime\w*|criminal\w*|
 arrest\w*|police|trump|obama|hitler|stalin|israel\w*|palestin\w*|gay|lesbian|stupid|idiot\w*|fat|ugly|hell|damn\w*|crap|
 pregnan\w*|divorce\w*|funeral|steal|stole|stolen|thief|cheat\w*|affair|vote|election\w*|president|politician\w*|
 school\w*|pupil\w*|student\w*|teacher\w*|homework|classmate\w*|class|classes|classroom\w*|grade|grades|exam\w*|test\w*|
 kid|kids|child|children|toddler\w*|baby|babies|boy|boys|girl|girls|teen\w*|mom|mum|mommy|dad|daddy|grandpa|grandma|
 grandfather|grandmother|uncle|aunt|cousin\w*|brother|sister|fairy|princess|cartoon\w*|disney|dinosaur\w*|toy|toys|puppy|
 kitten\w*|santa|candy|birthday|playground|kindergarten|boyfriend|girlfriend|crush|cry|cried|crying|tears|hate|hated|
 china|chinese|beijing|shanghai|guangzhou|yuan|mid-autumn|spring festival|dragon boat|monkey|panda|kite|kites|football|
 basketball|ping-pong|badminton|volleyball|piano|violin|dumpling\w*|noodle\w*|mr|mrs|miss|ms|li|wang|zhang|liu|chen|
 lingling|lily|lucy|lilei|tom|jim|mike|kate|bob|peter|mary|amy|sam|tony|jack|john|jenny|anna|alice|ben|dave)\b""",
                   re.I | re.X)
CJK = re.compile(r"[　-鿿＀-￯]")
NONWORD_OPT = re.compile(r"^[\W_]+$")


def read_jsonl(path: Path):
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.strip():
            yield json.loads(line)


def hval(s: str) -> int:
    return int(hashlib.sha1(s.encode()).hexdigest()[:12], 16)


def cmd_fetch(a):
    raw = Path(a.raw)
    raw.mkdir(parents=True, exist_ok=True)
    meta = json.loads(urllib.request.urlopen(API, timeout=60).read())
    lic = (meta.get("cardData") or {}).get("license")
    tags = [t for t in meta.get("tags", []) if t.startswith("license:")]
    print("HF license:", lic, tags, "sha:", meta.get("sha"))
    if lic != "cc-by-4.0" or "license:cc-by-4.0" not in tags:
        sys.exit("dry-melon license tag is not cc-by-4.0 at the source; stop and re-check before using any row.")
    (raw / "license-check.json").write_text(json.dumps({"license": lic, "tags": tags, "sha": meta.get("sha")}, indent=1))
    for g in (8, 9):
        dest = raw / f"g{g}.jsonl"
        if not dest.exists() or dest.stat().st_size < 1_000_000:
            with urllib.request.urlopen(FILE_URL.format(g=g), timeout=120) as r:
                dest.write_bytes(r.read())
        print(dest, dest.stat().st_size)


def head_of(tp: str) -> str:
    return tp.split(";")[0].strip().lower()


def norm_opt(o: str) -> str:
    o = re.sub(r"\s+", " ", o.strip())
    if o in ("/", "-", "×", "x", "X", "—", "∅", "\\"):
        return NOART
    return o


def surface_ok(filled: str) -> str | None:
    if not filled.isascii() or CJK.search(filled):
        return "non-ascii/CJK"
    if re.search(r"[\[\]{}|*=#@\\~^]|https?:|\(\s*\)|\d{5,}", filled):
        return "markup/numbers"
    if re.search(r"\s[,.;:!?]|\(\s|\s\)|\.\.|,,|\?\?|\s{2,}", filled):
        return "spacing/punctuation artifact"
    if re.match(r"^\s*[A-D]\s*[:.)]", filled) or re.search(r"\b[AB]\s*:", filled):
        return "dialogue/label"
    if BLOCK.search(filled):
        return "blocklist (childish/school/Chinese-exam/sensitive)"
    return None


def candidates(rej: Counter) -> list[dict]:
    out = []
    for g in (8, 9):
        p = ROOT / f".ingest/raw/{SRC}/g{g}.jsonl"
        for ln, row in enumerate(read_jsonl(p)):
            for qi, q in enumerate(row.get("questions", [])):
                sid = f"g{g}-{ln}" + (f"-{qi}" if qi else "")
                text = (q.get("text") or "").strip()
                ch = q.get("choices") or {}
                key = q.get("answer")
                tp = q.get("test_point") or ""
                h = head_of(tp)
                if h in DROP_HEADS or h not in HEAD_MAP:
                    rej["test_point not grammar/vocab pattern"] += 1
                    continue
                if text.count("<blank>") != 1:
                    rej["not exactly one <blank>"] += 1
                    continue
                if sorted(ch) != ["A", "B", "C", "D"] or key not in ch:
                    rej["bad choices/key"] += 1
                    continue
                opts = [norm_opt(ch[k]) for k in "ABCD"]
                if len({o.lower() for o in opts}) != 4 or any((not o) or NONWORD_OPT.match(o) and o != NOART for o in opts):
                    rej["options not 4 distinct"] += 1
                    continue
                if any(len(o.split()) > 4 or "," in o or "/" in o for o in opts):
                    rej["option too long / multi-part"] += 1
                    continue
                sentence = re.sub(r"\s+", " ", text.replace("<blank>", "____")).strip()
                ans = opts["ABCD".index(key)]
                if sentence.startswith("____"):
                    pass
                filled = sentence.replace("____ ", "").replace("____", "") if ans == NOART else sentence.replace("____", ans)
                filled = re.sub(r"\s+", " ", filled).strip()
                why = surface_ok(filled + " " + " ".join(opts))
                if why:
                    rej[why] += 1
                    continue
                if "____" in filled or not re.match(r"[A-Z\"']", filled) or not re.search(r"[.!?]\"?$", filled):
                    rej["not a complete sentence"] += 1
                    continue
                wc = textnorm.word_count(filled)
                if wc < 7 or wc > 28:
                    rej["length out of 7-28 words"] += 1
                    continue
                if re.search(r"\([^)]*\)", sentence):
                    rej["parenthetical hint"] += 1
                    continue
                pat, w = HEAD_MAP[h]
                if pat == "collocation" and h in ("vocabulary", "contextual vocabulary") and wc < 9:
                    rej["short vocab item"] += 1
                    continue
                # a/an/the options are an article item whatever the head says
                if {o.lower() for o in opts} & {"a", "an", "the", NOART.lower()} and len({o.lower() for o in opts} & {"a", "an", "the", NOART.lower()}) >= 3:
                    pat = "article"
                out.append({"sourceId": sid, "grade": g, "sentence": sentence, "options": opts, "answer": "ABCD".index(key),
                            "filled": filled, "answerProvided": bool(q.get("is_answer_provided")), "testPoint": tp,
                            "patternHint": pat, "weight": w, "srcExplanation": (q.get("explanation") or "").strip()})
    return out


def existing_filled(index: DedupeIndex) -> None:
    for f in sorted((ROOT / "Content/items").glob("*.json")):
        if f.name == OUT_FILE:
            continue
        for it in json.loads(f.read_text(encoding="utf-8")):
            if it.get("type") == "grammarMC" and "____" in it.get("sentence", ""):
                try:
                    ans = it["options"][it["answer"]]
                except (KeyError, IndexError):
                    continue
                s = it["sentence"]
                filled = re.sub(r"\s+", " ", s.replace("____ ", "").replace("____", "")) if ans == NOART else s.replace("____", ans)
                index.add("filled-" + it["id"], filled)


def score(c: dict) -> float:
    lvl = {"B1": 0, "B1+": 0.5, "B2": 1.0, "B2+": 1.5, "C1": 2.0}.get(cefr.lexical_level(c["filled"]), 0)
    s = c["weight"] + 0.4 * lvl + 1.2 * workplace.score(c["filled"])
    s += 0.5 if c["grade"] == 9 else 0.0
    s += 0.4 if c["answerProvided"] else 0.0
    s += 0.2 if 9 <= textnorm.word_count(c["filled"]) <= 20 else 0.0
    s += (hval(c["filled"]) % 1000) / 2500
    return s


def cmd_extract(a):
    stage = Path(a.stage)
    (stage / "batches").mkdir(parents=True, exist_ok=True)
    for old in (stage / "batches").glob("batch-*.jsonl"):
        old.unlink()
    lic = ROOT / f".ingest/raw/{SRC}/license-check.json"
    if not lic.exists() or json.loads(lic.read_text()).get("license") != "cc-by-4.0":
        sys.exit("run `fetch` first: license check missing or not cc-by-4.0")
    rej: Counter = Counter()
    cands = candidates(rej)
    n_raw = len(cands)
    index = DedupeIndex.from_content(ROOT / "Content")
    existing_filled(index)
    cands.sort(key=lambda c: -score(c))
    kept = []
    for c in cands:
        dup = index.check("tmp-" + c["sourceId"], c["filled"]) if False else index.check(c["filled"])
        if dup:
            rej["dedupe vs Content/ or within set"] += 1
            continue
        index.add("dm-" + c["sourceId"], c["filled"])
        kept.append(c)

    # variety: cap rows per (pattern, correct answer string) so e.g. "used to" cannot flood; per-pattern quotas by weight
    cap_ans = Counter()
    capped = []
    for c in kept:
        k = (c["patternHint"], c["options"][c["answer"]].lower())
        lim = 14 if c["patternHint"] in ("preposition", "tense", "linker", "modal", "article") else 8
        if cap_ans[k] >= lim:
            rej["cap per (pattern, answer)"] += 1
            continue
        cap_ans[k] += 1
        capped.append(c)
    by_pat = defaultdict(list)
    for c in capped:
        by_pat[c["patternHint"]].append(c)
    quota = {"preposition": 260, "tense": 280, "verb-pattern": 240, "modal": 160, "passive": 130, "conditional": 100, "relative": 120,
             "article": 110, "agreement": 150, "linker": 140, "word-form": 200, "collocation": 220}
    chosen = []
    for p, rows in by_pat.items():
        chosen += rows[:quota.get(p, 100)]
    chosen.sort(key=lambda c: -score(c))
    chosen = chosen[:STAGE_TARGET]
    for c in chosen:
        c["id"] = ids.hashed_id("grammarMC", SRC, c["sentence"] + "|" + c["options"][c["answer"]])
    assert len({c["id"] for c in chosen}) == len(chosen), "id collision"

    full = []
    for c in chosen:
        full.append({**{k: c[k] for k in ("id", "sourceId", "sentence", "options", "answer", "filled", "answerProvided", "testPoint",
                                          "patternHint", "grade")},
                     "cefrHint": "B1" if c["grade"] == 8 else "B1+", "workplace": round(workplace.score(c["filled"]), 3),
                     "emitFile": OUT_FILE, "source": "dry-melon exam MCQs (grammarMC)", "license": LICENSE, "tier": "unclear",
                     "origin": "adapted"})
    (stage / "candidates.jsonl").write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in full), encoding="utf-8")

    # NOTE: no key in batch rows (blind verify). testPoint is a hint about what the exam tests, not the answer.
    slim = [{"id": r["id"], "sentence": r["sentence"], "options": r["options"], "patternHint": r["patternHint"],
             "cefrHint": r["cefrHint"], "testPoint": r["testPoint"]} for r in full]
    slim.sort(key=lambda r: hval(r["id"]))
    nb = max(1, round(len(slim) / 40))
    size = -(-len(slim) // nb)
    batches = [slim[i:i + size] for i in range(0, len(slim), size)]
    for i, b in enumerate(batches, 1):
        (stage / "batches" / f"batch-{i:03d}.jsonl").write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in b), encoding="utf-8")
    (stage / "selection.json").write_text(json.dumps({
        "total": len(full), "batches": len(batches), "batchSizes": [len(b) for b in batches],
        "byPattern": dict(Counter(r["patternHint"] for r in full)), "byGrade": dict(Counter(r["grade"] for r in full)),
        "answerProvided": dict(Counter(r["answerProvided"] for r in full)), "passedRowFilters": n_raw, "afterDedupe": len(kept)}, indent=1))
    rp = ROOT / f".ingest/reports/{SRC}.md"
    L = [f"# {SRC} (P4, tier unclear)", "", f"License at source: {LICENSE}", "",
         f"Row filters passed: {n_raw}; after dedupe {len(kept)}; after caps/quotas {len(capped)}; staged {len(full)} in {len(batches)} batches.", "",
         "## Rejects", ""] + [f"- {k}: {v}" for k, v in rej.most_common()]
    L += ["", "## Staged by pattern", ""] + [f"- {k}: {v}" for k, v in Counter(r["patternHint"] for r in full).most_common()]
    L += ["", "## 30-item sample", ""]
    for r in random.Random(5).sample(full, min(30, len(full))):
        L.append(f"- [{r['patternHint']}/{r['cefrHint']}] {r['sentence']} | {r['options']} -> {r['options'][r['answer']]}")
    rp.write_text("\n".join(L) + "\n", encoding="utf-8")
    print(f"staged {len(full)} rows in {len(batches)} batches; patterns {dict(Counter(r['patternHint'] for r in full))}")


EMIT_MARK = "\n## Emit\n"
CN_NAMES = re.compile(r"\b(Liwei|Wenzhou|Hong|Kong|Hongkong|Guilin|Hua|Mount|Dalian|Yang|Changjiang|Tao|Hainan|Tian|Lin|Nanjing|Tianjin|Zhaozhou|Putuo|Yaping|Tsinghua|Honglin|Hunan|Shenyang|Xi|Nanchang|Hangzhou|Zhejiang|Wangfujing|Wei|Chongqing|Chengdu|Huaxi|Wuhan|Huang|Meimei|Qingdao|Mingwei|Xiong|Rulin|Shandong|Shijiazhuang|Hui|Fang|Sichuan|Ming|Heping|Wangdian|Wall|Palace|Olympic|Starsearch|Lakeside|Maths)\b")


def cmd_emit(a):
    from lib import emit as emitlib
    stage = Path(a.stage)
    content = ROOT / "Content"
    filled = {}
    per = {}
    for f in sorted((stage / "batches").glob("batch-*.filled.jsonl")):
        name = f.name.replace(".filled.jsonl", "")
        per[name] = Counter()
        for r in read_jsonl(f):
            filled[r["id"]] = r
            per[name][r["verdict"]] += 1
    index = DedupeIndex()
    for f in sorted((content / "items").glob("*.json")):
        if f.name == OUT_FILE:
            continue
        for it in json.loads(f.read_text(encoding="utf-8")):
            try:
                index.add(it["id"], item_text(it))
            except Exception:
                pass
    existing_filled(index)
    drop: Counter = Counter()
    reasons: Counter = Counter()
    items = []
    for c in read_jsonl(stage / "candidates.jsonl"):
        r = filled.get(c["id"])
        if not r:
            drop["no filled row"] += 1
            continue
        if r["verdict"] != "ok":
            drop["llm reject"] += 1
            reasons[(r.get("reason") or "unspecified")[:60]] += 1
            continue
        if r.get("blindAnswer") != c["answer"]:
            drop["blind answer disagrees with source key"] += 1
            continue
        if not (r.get("explanation") or "").strip():
            drop["empty explanation"] += 1
            continue
        if re.search(r"\w____|____\w", c["sentence"]):
            drop["blank glued to a word"] += 1
            continue
        if CN_NAMES.search(c["sentence"]):
            drop["Chinese place/person name or school-specific term"] += 1
            continue
        pat = r["pattern"] if r.get("pattern") in schema.PATTERNS else c["patternHint"]
        lvl = r["cefr"] if r.get("cefr") in ("B1", "B2", "C1") else c["cefrHint"][:2]
        item = {"id": c["id"], "type": "grammarMC", "cefr": lvl, "skill": "grammar", "sentence": c["sentence"],
                "options": c["options"], "answer": c["answer"], "explanation": r["explanation"].strip(), "pattern": pat,
                "source": c["source"], "sourceId": c["sourceId"], "license": c["license"], "tier": "unclear", "origin": "adapted"}
        if c["workplace"] >= 0.5:
            item["topics"] = ["workplace"]
        if index.check_and_add(c["id"], c["filled"]):
            drop["dedupe"] += 1
            continue
        probs = schema.problems_item(item)
        if probs:
            drop["schema"] += 1
            continue
        items.append(item)
    items.sort(key=lambda x: x["id"])
    random.Random(7).shuffle(items)
    items = sorted(items[:1500], key=lambda x: x["id"])
    emitlib.emit(content, "items", OUT_FILE, items, source="dry-melon Chinese middle-school English exam questions",
                 url=f"https://huggingface.co/datasets/{REPO}", license=LICENSE, tier="unclear",
                 attribution="Questions compiled by dry-melon (CC BY 4.0 tag); upstream exam copyright not cleared. Explanations by Claude.")
    rp = ROOT / f".ingest/reports/{SRC}.md"
    txt = rp.read_text(encoding="utf-8").split(EMIT_MARK)[0].rstrip("\n") + "\n"
    L = [f"Emitted {len(items)} items.", ""] + [f"- {k}: {v}" for k, v in drop.most_common()]
    L += ["", "reject rate per batch: " + ", ".join(f"{b} {c_['reject']}/{sum(c_.values())}" for b, c_ in per.items())]
    L += ["", "top llm reject reasons: " + "; ".join(f"{k} x{v}" for k, v in reasons.most_common(8) if v > 1)]
    L += ["", "level: " + str(dict(Counter(i["cefr"] for i in items))), "pattern: " + str(dict(Counter(i["pattern"] for i in items))),
          "answer position: " + str(dict(Counter(i["answer"] for i in items)))]
    rp.write_text(txt + EMIT_MARK + "\n".join(L) + "\n", encoding="utf-8")
    L2 = ["", "## 30-item random sample of emitted items", ""]
    for it in random.Random(11).sample(items, min(30, len(items))):
        L2.append(f"- [{it['pattern']}/{it['cefr']}] {it['sentence']} | {it['options']} -> {it['options'][it['answer']]} | {it['explanation']}")
    rp.write_text(rp.read_text(encoding="utf-8") + "\n".join(L2) + "\n", encoding="utf-8")
    print(len(items), dict(drop))


def main(argv):
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    f = sub.add_parser("fetch")
    f.add_argument("--raw", default=str(ROOT / f".ingest/raw/{SRC}"))
    f.set_defaults(fn=cmd_fetch)
    e = sub.add_parser("extract")
    e.add_argument("--stage", default=str(ROOT / f".ingest/stage/{SRC}"))
    e.set_defaults(fn=cmd_extract)
    m = sub.add_parser("emit")
    m.add_argument("--stage", default=str(ROOT / f".ingest/stage/{SRC}"))
    m.set_defaults(fn=cmd_emit)
    a = ap.parse_args(argv)
    a.fn(a)


if __name__ == "__main__":
    main(sys.argv[1:])
