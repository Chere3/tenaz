"""Python port of ContentValidator (Swift) plus the FORMAT.md bounds.

Run:  uv run --project scripts/ingest python -I scripts/ingest/lib/schema.py Content/

Stdlib only and self-contained on purpose: `python -I` does not put this folder on sys.path.
Two layers of checks:
  * swift_*  : exact port of ContentValidator.problems (if the app would drop it, we flag it).
  * bounds_* : stricter FORMAT.md / dataset-plan 3.4 limits that Swift does not check.
Swift wins: if the two ever disagree on the swift layer, fix this file.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

CEFR_LABELS = {"A1", "A2", "B1", "B1+", "B2", "B2+", "C1", "C2"}
EXAM_TYPES = {
    "completeWords", "readDaily", "readAcademic", "listenResponse", "listenConversation",
    "listenAnnouncement", "listenTalk", "buildSentence", "grammarMC", "writeEmail",
    "writeDiscussion", "lifeParagraph", "listenRepeat", "interview",
}
PATTERNS = {"preposition", "verb-pattern", "tense", "agreement", "article", "conditional", "passive",
            "relative", "modal", "word-form", "linker", "collocation", "false-friend"}
VOCAB_TAGS = {"core", "verb-pattern", "academic", "workplace", "meetings", "tech", "phrasal", "collocation",
              "intensifier", "false-friend", "linker", "preposition", "idiom", "error-pattern"}
SKILLS = {"reading", "listening", "writing", "speaking", "grammar"}
VOICES = {"female", "male"}
# New optional fields (dataset-plan 3.2); validated when present.
ORIGINS = {"verbatim", "adapted", "generated"}
TIERS = {"permissive", "share-alike", "nc", "unclear"}
VOCAB_STR_FIELDS = ["id", "headword", "pos", "cefr", "es", "definition", "example", "exampleEs", "cloze", "answer", "note"]
OPTIONAL_STR = ["source", "sourceId", "license", "group", "kind"]


# ---------- Swift: CEFRLevel / CompleteWordsParser ----------

def cefr_ok(label) -> bool:
    return isinstance(label, str) and label.upper() in CEFR_LABELS and label.upper() == label.upper()


def parse_gaps(passage: str) -> list[tuple[str, str]]:
    """Port of CompleteWordsParser.gaps: visible = run of letters right before '{{'."""
    gaps: list[tuple[str, str]] = []
    rest = passage
    while True:
        o = rest.find("{{")
        if o < 0:
            break
        c = rest.find("}}", o + 2)
        if c < 0:
            break
        before = rest[:o]
        i = len(before)
        while i > 0 and before[i - 1].isalpha():
            i -= 1
        gaps.append((before[i:], rest[o + 2:c]))
        rest = rest[c + 2:]
    return gaps


def _norm_letters(s: str) -> str:
    return "".join(ch for ch in s.lower() if ch.isalpha() or ch.isnumeric())


# ---------- Swift port ----------

def swift_problems_vocab(e: dict) -> list[str]:
    p: list[str] = []
    for f in VOCAB_STR_FIELDS:
        if not isinstance(e.get(f), str):
            p.append(f"decode: vocab field {f} missing or not a string")
    for f in ("distractors", "collocations", "tags"):
        v = e.get(f)
        if not (isinstance(v, list) and all(isinstance(x, str) for x in v)):
            p.append(f"decode: vocab field {f} missing or not [String]")
    if p:
        return p
    if len(e["cloze"].split("____")) != 2:
        p.append("cloze must contain ____ exactly once")
    if e["cloze"].replace("____", e["answer"]) != e["example"]:
        p.append("cloze + answer != example")
    if len(e["distractors"]) != 3:
        p.append("needs 3 distractors")
    low = {d.lower() for d in e["distractors"]}
    if len(low) != len(e["distractors"]) or e["answer"].lower() in low:
        p.append("distractors must be distinct and differ from answer")
    if not cefr_ok(e["cefr"]):
        p.append(f"bad cefr {e['cefr']}")
    return p


def _decode_problems(i: dict) -> list[str]:
    """Things the Swift Codable decoder would reject outright (whole file fails to load)."""
    p: list[str] = []
    if not isinstance(i.get("id"), str):
        p.append("decode: id missing")
    if i.get("type") not in EXAM_TYPES:
        p.append(f"decode: unknown type {i.get('type')!r}")
    if not isinstance(i.get("cefr"), str):
        p.append("decode: cefr missing")
    return p


def _choice(options, answer, p: list[str]) -> None:
    if options is None or answer is None or isinstance(answer, bool) or not isinstance(answer, int):
        p.append("missing options/answer")
        return
    if len(options) != 4:
        p.append("needs 4 options")
    if not (0 <= answer < len(options)):
        p.append("answer index out of range")


def _questions(i: dict, p: list[str]) -> None:
    qs = i.get("questions")
    if not qs:
        p.append("missing questions")
        return
    for q in qs:
        _choice(q.get("options"), q.get("answer"), p)


def swift_problems_item(i: dict) -> list[str]:
    p = _decode_problems(i)
    if p:
        return p
    t = i["type"]
    if not cefr_ok(i["cefr"]):
        p.append(f"bad cefr {i['cefr']}")
    if t == "completeWords":
        gaps = parse_gaps(i.get("passage") or "")
        if len(gaps) < 6:
            p.append(f"completeWords needs gaps (has {len(gaps)})")
        if any(not v or not h for v, h in gaps):
            p.append("empty gap part")
    elif t in ("readDaily", "readAcademic"):
        if not i.get("text"):
            p.append("missing text")
        _questions(i, p)
    elif t in ("listenConversation", "listenAnnouncement", "listenTalk"):
        if i.get("script") is None:
            p.append("missing script")
        _questions(i, p)
    elif t == "listenResponse":
        if not i.get("prompt"):
            p.append("missing prompt")
        _choice(i.get("options"), i.get("answer"), p)
    elif t == "grammarMC":
        if "____" not in (i.get("sentence") or ""):
            p.append("sentence needs ____")
        _choice(i.get("options"), i.get("answer"), p)
    elif t == "buildSentence":
        chunks, ans = i.get("chunks"), i.get("answer")
        if chunks is None or not isinstance(ans, str):
            p.append("missing chunks/answer")
        elif sorted(_norm_letters("".join(chunks))) != sorted(_norm_letters(ans)):
            p.append("chunks don't spell the answer")
    elif t == "writeEmail":
        if not i.get("situation") or not i.get("tasks"):
            p.append("missing situation/tasks")
    elif t == "writeDiscussion":
        if not i.get("professor"):
            p.append("missing professor post")
    elif t == "lifeParagraph":
        if not i.get("prompt"):
            p.append("missing prompt")
    elif t == "listenRepeat":
        if not i.get("sentence"):
            p.append("missing sentence")
    elif t == "interview":
        if not i.get("questions"):
            p.append("missing interview questions")
    return p


# ---------- Bounds (stricter than Swift) ----------

def wc(s: str) -> int:
    return len(s.split())


def is_lexical_chunk(entry: str) -> bool:
    """Same predicate as GatePrompt.pick."""
    e = entry.lower()
    return not e.startswith("use ") and "tense" not in e and len(e.split()) <= 4


_URL = re.compile(r"https?://|www\.", re.I)
_HTML = re.compile(r"</?[a-zA-Z][^>]*>|&[a-z]+;")
_CJK = re.compile(r"[㐀-鿿豈-﫿]")
_TOKART = re.compile(r" [,;:!?]| \.(?!\.)| (?:n't|'s|'re|'ve|'ll|'d|'m)(?![-\w])|`` | ''|-LRB-|-RRB-")


def display_texts(i: dict) -> list[str]:
    out: list[str] = []
    for k in ("title", "text", "prompt", "sentence", "context", "situation", "professor", "studentA",
              "studentB", "topic", "explanation", "answer"):
        v = i.get(k)
        if isinstance(v, str):
            out.append(v)
    for k in ("options", "chunks", "tasks", "mustUse", "accepted"):
        v = i.get(k)
        if isinstance(v, list):
            out += [x for x in v if isinstance(x, str)]
    s = i.get("script")
    if isinstance(s, str):
        out.append(s)
    elif isinstance(s, list):
        out += [x.get("line", "") for x in s if isinstance(x, dict)]
    if i.get("type") == "interview":
        out += [x for x in (i.get("questions") or []) if isinstance(x, str)]
    else:
        for q in i.get("questions") or []:
            if isinstance(q, dict):
                out.append(q.get("q", ""))
                out += [x for x in q.get("options", []) if isinstance(x, str)]
                if isinstance(q.get("explanation"), str):
                    out.append(q["explanation"])
    if isinstance(i.get("passage"), str):
        out.append(i["passage"].replace("{{", "").replace("}}", ""))
    return out


def _nq(i: dict, lo: int, hi: int, p: list[str]) -> None:
    n = len(i.get("questions") or [])
    if not lo <= n <= hi:
        p.append(f"needs {lo}-{hi} questions (has {n})")


def bounds_problems_item(i: dict, exempt_life_minwords: bool = False) -> list[str]:
    p: list[str] = []
    t = i.get("type")
    if t == "readDaily":
        if not 40 <= wc(i.get("text") or "") <= 150:
            p.append(f"readDaily text must be 40-150 words (has {wc(i.get('text') or '')})")
        _nq(i, 2, 3, p)
    elif t == "readAcademic":
        if not 150 <= wc(i.get("text") or "") <= 220:
            p.append(f"readAcademic text must be 150-220 words (has {wc(i.get('text') or '')})")
        _nq(i, 5, 5, p)
    elif t == "listenConversation":
        s = i.get("script")
        if not isinstance(s, list):
            p.append("listenConversation script must be a list of lines")
        else:
            if not 8 <= len(s) <= 14:
                p.append(f"listenConversation needs 8-14 lines (has {len(s)})")
            if any(x.get("speaker") not in ("A", "B") for x in s):
                p.append("speaker must be A or B")
            if any(x.get("voice") not in (None, *VOICES) for x in s):
                p.append("bad voice")
        _nq(i, 3, 4, p)
    elif t == "listenAnnouncement":
        s = i.get("script")
        if not isinstance(s, str):
            p.append("listenAnnouncement script must be a string")
        elif not 80 <= wc(s) <= 140:
            p.append(f"listenAnnouncement script must be 80-140 words (has {wc(s)})")
        _nq(i, 3, 3, p)
    elif t == "listenTalk":
        s = i.get("script")
        if not isinstance(s, str):
            p.append("listenTalk script must be a string")
        elif not 180 <= wc(s) <= 250:
            p.append(f"listenTalk script must be 180-250 words (has {wc(s)})")
        _nq(i, 4, 4, p)
    elif t == "buildSentence":
        n = len(i.get("chunks") or [])
        if not 5 <= n <= 8:
            p.append(f"buildSentence needs 5-8 chunks (has {n})")
    elif t == "listenRepeat":
        n = wc(i.get("sentence") or "")
        if not 6 <= n <= 22:
            p.append(f"listenRepeat sentence must be 6-22 words (has {n})")
    elif t == "completeWords":
        passage = i.get("passage") or ""
        plain = passage.replace("{{", "").replace("}}", "")
        n = len(parse_gaps(passage))
        if not 70 <= wc(plain) <= 110:
            p.append(f"completeWords passage must be 70-110 words (has {wc(plain)})")
        if n != 10:
            p.append(f"completeWords needs exactly 10 gaps (has {n})")
    elif t == "lifeParagraph":
        mw = i.get("minWords")
        if not exempt_life_minwords and not (isinstance(mw, int) and 40 <= mw <= 80):
            p.append(f"lifeParagraph minWords must be 40-80 (has {mw})")
        mu = i.get("mustUse") or []
        if not any(is_lexical_chunk(m) for m in mu):
            p.append("lifeParagraph mustUse needs a lexical chunk (<=4 words, not 'use ...', no 'tense')")
        if not 1 <= len(mu) <= 3:
            p.append("lifeParagraph mustUse should have 1-3 entries")
    elif t == "grammarMC":
        if i.get("pattern") not in PATTERNS:
            p.append(f"bad pattern {i.get('pattern')!r}")
    elif t == "interview":
        n = len(i.get("questions") or [])
        if n != 4:
            p.append(f"interview needs 4 questions (has {n})")
    if i.get("skill") is not None and i["skill"] not in SKILLS:
        p.append(f"bad skill {i['skill']!r}")
    if i.get("voice") is not None and i["voice"] not in VOICES:
        p.append(f"bad voice {i['voice']!r}")
    # new optional fields
    for k in OPTIONAL_STR:
        if k in i and not isinstance(i[k], str):
            p.append(f"{k} must be a string")
    if "origin" in i and i["origin"] not in ORIGINS:
        p.append(f"bad origin {i['origin']!r}")
    if "tier" in i and i["tier"] not in TIERS:
        p.append(f"bad tier {i['tier']!r}")
    if "topics" in i and not (isinstance(i["topics"], list) and all(isinstance(x, str) for x in i["topics"])):
        p.append("topics must be [String]")
    if "reference" in i and not (isinstance(i["reference"], list) and i["reference"] and all(isinstance(x, str) and x.strip() for x in i["reference"])):
        p.append("reference must be a non-empty [String]")
    p += _text_hygiene(display_texts(i))
    return p


def _text_hygiene(texts: list[str]) -> list[str]:
    p: list[str] = []
    for s in texts:
        if "{{" in s or "}}" in s:
            p.append(f"stray braces in {s[:40]!r}")
        if _HTML.search(s):
            p.append(f"HTML in {s[:40]!r}")
        if _URL.search(s):
            p.append(f"URL in {s[:40]!r}")
        if _CJK.search(s):
            p.append(f"CJK characters in {s[:40]!r}")
        if _TOKART.search(s):
            p.append(f"tokenization artifact in {s[:40]!r}")
    return sorted(set(p))


def bounds_problems_vocab(e: dict) -> list[str]:
    p: list[str] = []
    for t in e.get("tags", []):
        if t not in VOCAB_TAGS:
            p.append(f"bad tag {t!r}")
    texts = [e.get(k, "") for k in ("headword", "es", "definition", "example", "exampleEs", "note")] + e.get("collocations", [])
    p += [x for x in _text_hygiene([t for t in texts if isinstance(t, str)])]
    return p


def display_check_item_texts(i: dict) -> list[str]:
    """For items, '____' is only legal in grammarMC sentences; flag it elsewhere."""
    p = []
    if i.get("type") != "grammarMC":
        for s in display_texts(i):
            if "____" in s:
                p.append(f"unexpected ____ in {s[:40]!r}")
    return p


# ---------- Public API ----------

def problems_item(i: dict, exempt_life_minwords: bool = False) -> list[str]:
    p = swift_problems_item(i)
    if any(x.startswith("decode:") for x in p):
        return p
    return p + bounds_problems_item(i, exempt_life_minwords) + display_check_item_texts(i)


def problems_vocab(e: dict) -> list[str]:
    p = swift_problems_vocab(e)
    if any(x.startswith("decode:") for x in p):
        return p
    return p + bounds_problems_vocab(e)


def validate_content(root: Path) -> list[str]:
    """Validate everything under root/items and root/vocab, including global id uniqueness."""
    out: list[str] = []
    seen: dict[str, str] = {}
    for sub, fn in (("vocab", problems_vocab), ("items", problems_item)):
        for f in sorted((root / sub).glob("*.json")):
            try:
                rows = json.loads(f.read_text(encoding="utf-8"))
            except Exception as ex:  # noqa: BLE001
                out.append(f"{sub}/{f.name}: unreadable JSON: {ex}")
                continue
            if not isinstance(rows, list):
                out.append(f"{sub}/{f.name}: top level must be an array")
                continue
            for r in rows:
                rid = r.get("id", "?") if isinstance(r, dict) else "?"
                if not isinstance(r, dict):
                    out.append(f"{sub}/{f.name}: row is not an object")
                    continue
                if sub == "items":
                    probs = fn(r, exempt_life_minwords=f.name == "placement.json")
                else:
                    probs = fn(r)
                for x in probs:
                    out.append(f"{sub}/{f.name}: {rid}: {x}")
                if rid in seen:
                    out.append(f"{sub}/{f.name}: {rid}: duplicate id (also in {seen[rid]})")
                seen[rid] = f"{sub}/{f.name}"
    return out


def main(argv: list[str]) -> int:
    root = Path(argv[1] if len(argv) > 1 else "Content")
    probs = validate_content(root)
    for x in probs:
        print(x)
    print(f"{len(probs)} problem(s)", file=sys.stderr)
    return 1 if probs else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
