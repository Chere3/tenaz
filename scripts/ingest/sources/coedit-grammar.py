"""C10 grammarMC (CoEdIT gec) + C11 rule-based grammarMC: fetch / extract (stage only, no LLM, no emit).

  fetch    verifies the CoEdIT license at the source (stops if it is not apache-2.0) -> .ingest/raw/coedit-grammar/license-check.json
  extract  reads staged data only:
             .ingest/stage/coedit/gec-pairs.jsonl           (C10, single-edit gec pairs)
             .ingest/stage/tatoeba/pairs.jsonl              (C11, English side)
             .ingest/stage/onestopenglish/{windows,readacademic}.jsonl, .ingest/stage/openstax/paragraphs.jsonl
           and writes .ingest/stage/coedit-grammar/{candidates.jsonl, batches/batch-NNN.jsonl, selection.json}
           plus .ingest/reports/coedit-grammar.md

Rows needing LLM work (distractors, explanation, pattern/cefr confirmation, strict one-correct-answer check) go to
batches/; `candidates.jsonl` keeps the full rows (provenance, license, emitFile) for the later emit step.
Nothing here writes Content/. Run with -I:
  uv run --project scripts/ingest python -I scripts/ingest/sources/coedit-grammar.py fetch
  uv run --project scripts/ingest python -I scripts/ingest/sources/coedit-grammar.py extract
"""
from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import os
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
SRC = "coedit-grammar"
API = "https://huggingface.co/api/datasets/grammarly/coedit"
PATTERNS = ["preposition", "article", "verb-pattern", "tense", "agreement", "word-form", "linker", "collocation",
            "false-friend", "relative", "passive"]
NOART = "(no article)"
ARTS = {"a", "an", "the"}

# per-file licence facts (used by the later emit step; the fill agents never see them)
FILES = {
    "coedit": dict(file="grammar-coedit.json", source="CoEdIT (grammarMC, gec)", tier="permissive",
                   license="Apache-2.0 (HF tag and card; the public release keeps only rows from publicly available "
                           "datasets, but upstream corpora behind the gec/simplification/coherence tasks may carry their own terms)",
                   url="https://huggingface.co/datasets/grammarly/coedit",
                   attribution="Raheja et al. 2023, grammarly/coedit (gec task)"),
    "rules": dict(file="grammar-rules.json", source="Tatoeba; OpenStax paragraphs (rule-based blanking)", tier="permissive",
                  license="CC BY 2.0 FR (Tatoeba); CC BY 4.0 (OpenStax)",
                  url="https://tatoeba.org/en/downloads ; https://huggingface.co/datasets/HuggingFaceTB/openstax_paragraphs",
                  attribution="Tatoeba contributors; OpenStax (Rice University)"),
    "rules-ose": dict(file="grammar-rules-ose.json", source="OneStopEnglish corpus (rule-based blanking)", tier="share-alike",
                      license="CC BY-SA 4.0", url="https://github.com/nishkalavallabhi/OneStopEnglishCorpus",
                      attribution="Vajjala & Lucic 2018, OneStopEnglish corpus"),
}

# ---------------------------------------------------------------- hygiene (same spirit as sources/coedit.py)
BLOCK = re.compile(r"""\b(mickey|minnie|cavegirl|tomboy|surg\w*|blood|infect\w*|bacteri\w*|medical|patient\w*|goebbels|
 caucasian|propaganda|fascis\w*|communis\w*|dictator\w*|sex\w*|porn\w*|rape\w*|rapist|nude|naked|erotic|fuck\w*|shit\w*|
 bitch\w*|slut\w*|whore\w*|cock|dick|penis|vagina|breast\w*|kill\w*|murder\w*|suicid\w*|massacre\w*|genocide|holocaust|
 nazi\w*|terroris\w*|bomb\w*|weapon\w*|gun|guns|shoot\w*|slave\w*|racis\w*|racial|negro|jew\w*|muslim\w*|islam\w*|
 christ\w*|jesus|god|allah|church\w*|pope|religio\w*|abortion|drug\w*|cocaine|heroin|alcohol\w*|drunk|cancer|disease\w*|
 death|dead|die|died|dying|corpse|war|wars|battle\w*|soldier\w*|army|troops|invasion|prison\w*|crime\w*|criminal\w*|
 arrest\w*|police|trump|obama|hitler|stalin|israel\w*|palestin\w*|gay|lesbian|transgender|homosexual\w*|kid|kids|child|
 children|toddler\w*|baby|babies|teen\w*|school\w*|pupil\w*|student\w*|teacher\w*|homework|fairy|princess|cartoon\w*|
 disney|pokemon|dinosaur\w*|stupid|idiot\w*|fat|ugly|hell|damn\w*|crap|sucks|mommy|daddy|mum|toy|toys|puppy|kitten\w*|
 santa|teddy|doll|dolls|candy|pajamas|bedtime|playground|kindergarten|birthday|boyfriend|girlfriend|pregnan\w*|
 divorce\w*|widow\w*|funeral|cry|cried|crying|tears|hate|hated|steal|stole|stolen|thief|cheat\w*|affair|vote|election\w*|
 president|politician\w*|refugee\w*|immigrant\w*)\b""", re.I | re.X)


def surface_ok(s: str) -> str | None:
    if not s.isascii():
        return "non-ascii"
    if re.search(r"[\[\]{}<>|*_=#@\\/~^]|\d{5,}|https?:|\bet al\b|\be\.g\.|\bi\.e\.|\bFig\b|\bTable\b", s):
        return "markup/citation/numbers"
    if re.search(r"\b\d{4}\b", s) and not re.search(r"\b(19|20)\d\d\b", s):
        return "odd number"
    if s.count('"') % 2 or s.count("(") != s.count(")"):
        return "unbalanced quotes/brackets"
    if re.search(r"\s[,.;:!?]|\(\s|\s\)|\.\.|,,|\?\?|\s{2,}", s):
        return "spacing/punctuation artifact"
    if not re.match(r"[A-Z\"]", s) or not re.search(r"[.!?]\"?$", s):
        return "does not start capital / end with punctuation"
    if BLOCK.search(s):
        return "blocklist (childish/offensive/sensitive)"
    return None


def read_jsonl(path: Path):
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.strip():
            yield json.loads(line)


def hval(s: str) -> int:
    return int(hashlib.sha1(s.encode()).hexdigest()[:12], 16)


# ---------------------------------------------------------------- verb forms (explicit: base past pp ing)
_VERB_LINES = """
go went gone going|see saw seen seeing|take took taken taking|make made made making|do did done doing|give gave given giving
find found found finding|know knew known knowing|think thought thought thinking|come came come coming|run ran run running
write wrote written writing|begin began begun beginning|buy bought bought buying|bring brought brought bringing
build built built building|choose chose chosen choosing|drive drove driven driving|eat ate eaten eating|fall fell fallen falling
feel felt felt feeling|forget forgot forgotten forgetting|grow grew grown growing|hear heard heard hearing|keep kept kept keeping
leave left left leaving|lose lost lost losing|meet met met meeting|pay paid paid paying|say said said saying|sell sold sold selling
send sent sent sending|show showed shown showing|speak spoke spoken speaking|spend spent spent spending|stand stood stood standing
teach taught taught teaching|tell told told telling|understand understood understood understanding|win won won winning
wear wore worn wearing|break broke broken breaking|catch caught caught catching|draw drew drawn drawing|hold held held holding
lead led led leading|rise rose risen rising|sleep slept slept sleeping|throw threw thrown throwing|wake woke woken waking
work worked worked working|use used used using|start started started starting|try tried tried trying|call called called calling
ask asked asked asking|move moved moved moving|play played played playing|live lived lived living|change changed changed changing
turn turned turned turning|talk talked talked talking|open opened opened opening|close closed closed closing|follow followed followed following
check checked checked checking|create created created creating|develop developed developed developing|improve improved improved improving
manage managed managed managing|decide decided decided deciding|plan planned planned planning|stop stopped stopped stopping
study studied studied studying|visit visited visited visiting|share shared shared sharing|include included included including
allow allowed allowed allowing|reduce reduced reduced reducing|increase increased increased increasing|provide provided provided providing
discuss discussed discussed discussing|prepare prepared prepared preparing|receive received received receiving|solve solved solved solving
finish finished finished finishing|learn learned learned learning|offer offered offered offering|cook cooked cooked cooking
clean cleaned cleaned cleaning|order ordered ordered ordering|explain explained explained explaining|arrive arrived arrived arriving
repair repaired repaired repairing|deliver delivered delivered delivering|report reported reported reporting|review reviewed reviewed reviewing
approve approved approved approving|cancel cancelled cancelled cancelling|invite invited invited inviting|join joined joined joining
organize organized organized organizing|support supported supported supporting|walk walked walked walking|watch watched watched watching
help helped helped helping|invest invested invested investing|replace replaced replaced replacing|confirm confirmed confirmed confirming
""".replace("\n", "|")
VERBS: dict[str, tuple[str, str, str]] = {}   # base -> (past, pp, ing)
for _ent in _VERB_LINES.split("|"):
    _p = _ent.split()
    if len(_p) == 4:
        VERBS[_p[0]] = (_p[1], _p[2], _p[3])
ING2BASE = {v[2]: b for b, v in VERBS.items()}
PP2BASE: dict[str, str] = {}
PAST2BASE: dict[str, str] = {}
for _b, (_pa, _pp, _ing) in VERBS.items():
    if _pp != _b:
        PP2BASE.setdefault(_pp, _b)
    if _pa != _b:
        PAST2BASE.setdefault(_pa, _b)
IRREG_PAST = {w for w, b in PAST2BASE.items() if not w.endswith("ed")}


def cap_like(ref: str, s: str) -> str:
    return s[:1].upper() + s[1:] if ref[:1].isupper() else s


# ---------------------------------------------------------------- C10: CoEdIT single-edit classification
TOKEN = re.compile(r"\w+(?:'\w+)?|[^\w\s]")
PREPS = set("""about above across after against along among around at before behind between beyond by despite during for from in
into near of on onto over since through throughout to toward towards under until upon with within without""".split())
INS_PREPS = PREPS - {"to", "since", "until", "before", "after", "near", "across", "along"}  # insertions of these are ambiguous
LINKERS = set("""however although though despite because since therefore thus hence moreover furthermore besides whereas while
nevertheless instead otherwise consequently unless whether""".split()) | {"in spite of", "because of", "due to", "as a result",
                                                                          "in addition", "even though", "so that"}
RELS = {"who", "whom", "which", "whose", "where", "that"}
BE_AGR = [{"is", "are"}, {"was", "were"}, {"has", "have"}, {"does", "do"}, {"doesn't", "don't"}, {"isn't", "aren't"},
          {"wasn't", "weren't"}, {"hasn't", "haven't"}]
TENSE_PAIRS = [{"is", "was"}, {"are", "were"}, {"has", "had"}, {"have", "had"}, {"does", "did"}, {"do", "did"}]
TO_TRIGGERS = set("""want wants wanted need needs needed try tries tried decide decides decided plan plans planned hope hopes hoped
expect expects expected ask asks asked allow allows allowed enable enables enabled manage manages managed refuse refused
offer offered promise promised learn learned learnt help helps helped able how where what whether encourage invite remind
tell told advise advised force forced""".split())
BASE_TRIGGERS = set("to can could will would should must may might let lets make makes made help helps please didn't don't doesn't did does do not".split())
GERUND_TRIGGERS = set("""avoid avoids avoided enjoy enjoys enjoyed suggest suggests suggested consider considers considered finish finished
mind keep keeps kept practice practise delay delayed miss missed imagine recommend recommends recommended admit deny risk postpone
quit appreciate by without after before of about for in on at""".split())
DETERMINERS = {"the", "my", "your", "his", "her", "our", "their", "this", "that", "a", "an"}


def lem(w: str) -> str | None:
    w = w.lower()
    if w in VERBS:
        return w
    for tab in (ING2BASE, PP2BASE, PAST2BASE):
        if w in tab:
            return tab[w]
    for suf in ("es", "s"):
        if w.endswith(suf) and w[: -len(suf)] in VERBS:
            return w[: -len(suf)]
    return None


def lemma_pair(a: str, b: str) -> bool:
    la, lb = lem(a), lem(b)
    return la is not None and la == lb


def classify_coedit(op: str, old: list[str], new: list[str], prev: str, nxt: str) -> tuple[str, str] | None:
    """-> (pattern, subtype) for a teachable single edit, else None."""
    o, n = " ".join(old).lower(), " ".join(new).lower()
    if not any(re.match(r"\w", t) for t in old + new) or o == n:
        return None
    pv = prev.lower()
    if op == "replace" and o in ARTS and n in ARTS:
        return "article", "swap"
    if op == "insert" and n in ARTS:
        return "article", "insert"
    if op == "delete" and o in ARTS:
        return "article", "delete"
    if op == "replace" and o in RELS and n in RELS:
        return "relative", "swap"
    if op == "replace" and len(old) == 1 and len(new) == 1 and o in PREPS and n in PREPS:
        return "preposition", "swap"
    if op == "insert" and len(new) == 1 and n in INS_PREPS:
        return "preposition", "insert"
    if op == "replace" and o in LINKERS and n in LINKERS:
        return "linker", "swap"
    if op == "insert" and n == "to" and pv in TO_TRIGGERS and nxt.isalpha() and nxt.lower() not in DETERMINERS:
        return "verb-pattern", "insert-to"
    if op == "replace" and len(old) == len(new) == 1:
        if o in PREPS or n in PREPS:
            return None
        for grp in BE_AGR:
            if o in grp and n in grp:
                return "agreement", "aux"
        for grp in TENSE_PAIRS:
            if o in grp and n in grp:
                return "tense", "aux"
        if lemma_pair(o, n):
            if pv in BASE_TRIGGERS and n in VERBS:
                return "verb-pattern", "base-after-trigger"
            if pv in GERUND_TRIGGERS and n in ING2BASE:
                return "verb-pattern", "gerund-after-trigger"
            if pv in {"he", "she", "it", "they", "we", "you", "i", "people"}:
                return "agreement", "s-form"
            if n.endswith("ed") or o.endswith("ed") or n in PAST2BASE or o in PAST2BASE or n in PP2BASE or o in PP2BASE:
                return "tense", "form"
            return None
        a, b = o, n
        if a.isalpha() and b.isalpha() and len(a) >= 5 and len(b) >= 5 and a not in LINKERS and b not in LINKERS:
            pre = len(os.path.commonprefix([a, b]))
            if pre >= 4 and pre >= min(len(a), len(b)) - 4 and abs(len(a) - len(b)) <= 5:
                return "word-form", "suffix"
        return None
    if op == "replace" and len(old) == 2 and len(new) == 1 and old[0].lower() == "to" and (new[0].endswith("ing") or new[0].lower() in VERBS):
        return "verb-pattern", "to-vs-other"
    if op == "replace" and len(old) == 1 and len(new) == 2 and new[0].lower() == "to" and (old[0].endswith("ing") or old[0].lower() in VERBS):
        return "verb-pattern", "to-vs-other"
    return None


def coedit_candidates(rej: Counter) -> list[dict]:
    out = []
    for r in read_jsonl(ROOT / ".ingest/stage/coedit/gec-pairs.jsonl"):
        if r["nEdits"] != 1:
            rej["coedit: not exactly one edit"] += 1
            continue
        tgt, src = r["tgt"], r["src"]
        if not 8 <= textnorm.word_count(tgt) <= 30:
            rej["coedit: length not 8-30 words"] += 1
            continue
        why = surface_ok(tgt) or surface_ok(src)
        if why:
            rej[f"coedit: {why}"] += 1
            continue
        tt = [(m.group(), m.start(), m.end()) for m in TOKEN.finditer(tgt)]
        st = [m.group() for m in TOKEN.finditer(src)]
        sm = difflib.SequenceMatcher(None, st, [t[0] for t in tt], autojunk=False)
        ops = [x for x in sm.get_opcodes() if x[0] != "equal"]
        if len(ops) != 1:
            rej["coedit: re-alignment disagrees"] += 1
            continue
        tag, i1, i2, j1, j2 = ops[0]
        old, new = st[i1:i2], [t[0] for t in tt[j1:j2]]
        if len(old) > 2 or len(new) > 2:
            rej["coedit: edit longer than 2 tokens"] += 1
            continue
        prev = tt[j1 - 1][0] if j1 > 0 else ""
        nxt = tt[j2][0] if j2 < len(tt) else ""
        cl = classify_coedit(tag, old, new, prev, nxt)
        if not cl:
            rej["coedit: edit is not a teachable pattern (dropped)"] += 1
            continue
        pattern, sub = cl
        if tag == "delete":
            if j1 >= len(tt):
                rej["coedit: delete at end"] += 1
                continue
            pos = tt[j1][1]
            sentence = tgt[:pos] + "____ " + tgt[pos:]
            answer = NOART
            learner = " ".join(old)
        else:
            a, b = tt[j1][1], tt[j2 - 1][2]
            answer = tgt[a:b]
            sentence = tgt[:a] + "____" + tgt[b:]
            learner = NOART if tag == "insert" else " ".join(old)
        if tag == "replace" and learner.lower() == answer.lower():
            rej["coedit: case-only edit"] += 1
            continue
        if sentence.count("____") != 1:
            rej["coedit: blank problem"] += 1
            continue
        if pattern == "article":
            pool = ["a", "an", "the", NOART]
            if sentence.startswith("____"):
                pool = [x if x == NOART else x.capitalize() for x in pool]
            given, need = [x for x in pool if x.lower() != answer.lower()], 0
        else:
            given = [learner] if (tag == "replace" and learner) else []
            need = 3 - len(given)
        out.append(dict(origin="coedit", sourceId=r["sourceId"], sentence=sentence, filled=tgt, answer=answer, given=given,
                        need=need, patternHint=pattern, ruleId=f"coedit:{pattern}:{sub}", learnerError=learner, note="", trap=False))
    return out


# ---------------------------------------------------------------- C11: rule-based blanking
def mk(s, start, end, answer, pattern, given, need, rule, note="", trap=False, insert_at=None):
    if insert_at is not None:
        return dict(sentence=s[:insert_at] + "____ " + s[insert_at:], filled=s, answer=answer, given=given, need=need,
                    patternHint=pattern, ruleId=rule, note=note, trap=trap)
    return dict(sentence=s[:start] + "____" + s[end:], filled=s, answer=s[start:end], given=given, need=need,
                patternHint=pattern, ruleId=rule, note=note, trap=trap)


def _fix_case(ans: str, ds: list[str], at_start: bool) -> list[str]:
    return [cap_like(ans, d) if at_start else d for d in ds]


PREP_RULES = [  # (regex with named group a, distractors, note, spanish_trap)
    (r"\bdepend(?:s|ed|ing)?\s+(?P<a>on)\b", ["of", "from", "in"], "depender de: Spanish speakers say 'depend of'", True),
    (r"\brel(?:y|ies|ied|ying)\s+(?P<a>on)\b", ["in", "of", "to"], "", False),
    (r"\bconsist(?:s|ed|ing)?\s+(?P<a>of)\b", ["in", "on", "by"], "consistir en: Spanish speakers say 'consist in/on'", True),
    (r"\binsist(?:s|ed|ing)?\s+(?P<a>on)\b", ["in", "to", "for"], "insistir en: 'insist in' is the Spanish calque", True),
    (r"\bfocus(?:es|ed|ing)?\s+(?P<a>on)\b", ["in", "at", "to"], "centrarse en", True),
    (r"\bsucceed(?:s|ed|ing)?\s+(?P<a>in)\b", ["at", "on", "to"], "", False),
    (r"\bbelieve(?:s|d)?\s+(?P<a>in)\b", ["on", "at", "to"], "creer en", True),
    (r"\binterested\s+(?P<a>in)\b", ["on", "at", "by"], "interesado en", True),
    (r"\b(?:good|bad|great|terrible|excellent)\s+(?P<a>at)\b", ["in", "on", "with"], "bueno en: 'good in' is the Spanish calque", True),
    (r"\bafraid\s+(?P<a>of)\b", ["from", "for", "by"], "tener miedo de", False),
    (r"\bproud\s+(?P<a>of)\b", ["for", "from", "with"], "orgulloso de", False),
    (r"\bworried\s+(?P<a>about)\b", ["of", "with", "by"], "preocupado por", True),
    (r"\bexcited\s+(?P<a>about)\b", ["of", "with", "by"], "", False),
    (r"\bmarried\s+(?P<a>to)\b", ["with", "by", "for"], "casado con: 'married with' is the Spanish calque", True),
    (r"\bdifferent\s+(?P<a>from)\b", ["of", "with", "in"], "", False),
    (r"\bsimilar\s+(?P<a>to)\b", ["with", "of", "than"], "", False),
    (r"\bresponsible\s+(?P<a>for)\b", ["of", "about", "with"], "responsable de", True),
    (r"\bin\s+charge\s+(?P<a>of)\b", ["for", "to", "with"], "encargado de", True),
    (r"\baccus(?:e|es|ed|ing)\s+\w+\s+(?P<a>of)\b", ["for", "about", "with"], "", False),
    (r"\bbelong(?:s|ed|ing)?\s+(?P<a>to)\b", ["at", "in", "with"], "", False),
    (r"\bwait(?:s|ed|ing)?\s+(?P<a>for)\b", ["to", "at", "in"], "esperar: 'wait to' is a common slip", True),
    (r"\blook(?:s|ed|ing)?\s+forward\s+(?P<a>to)\b", ["for", "at", "in"], "", False),
    (r"\blisten(?:s|ed|ing)?\s+(?P<a>to)\b", ["at", "in", "with"], "escuchar (no preposition in Spanish): 'listen music'", True),
    (r"\bparticipat(?:e|es|ed|ing)\s+(?P<a>in)\b", ["at", "on", "to"], "", False),
    (r"\btake\s+part\s+(?P<a>in)\b", ["on", "at", "of"], "", False),
    (r"\bsuffer(?:s|ed|ing)?\s+(?P<a>from)\b", ["of", "by", "at"], "sufrir de", True),
    (r"\baccording\s+(?P<a>to)\b", ["with", "at", "for"], "segun: 'according with' is a calque", True),
    (r"\bthank(?:s|ed|ing)?\s+(?:you|him|her|them|us|me)\s+(?P<a>for)\b", ["to", "about", "of"], "", False),
    (r"\bcontribut(?:e|es|ed|ing)\s+(?P<a>to)\b", ["for", "at", "in"], "", False),
    (r"\bcompl(?:y|ies|ied|ying)\s+(?P<a>with)\b", ["to", "at", "for"], "cumplir con", True),
    (r"\bdeal(?:s|t|ing)?\s+(?P<a>with)\b", ["to", "on", "about"], "", False),
    (r"\bcop(?:e|es|ed|ing)\s+(?P<a>with)\b", ["to", "on", "about"], "", False),
    (r"\bgraduat(?:e|es|ed|ing)\s+(?P<a>from)\b", ["of", "at", "by"], "graduarse de", True),
    (r"\bexplain(?:s|ed|ing)?\s+(?:it|this|that|the\s+\w+|\w+)\s+(?P<a>to)\s+(?:me|you|him|her|us|them|the|our|my|your)\b", ["for", "with", "at"],
     "explain sth TO sb: 'explain me' is the Spanish slip", True),
    (r"\b(?:an?\s+)?increase\s+(?P<a>in)\b", ["of", "on", "at"], "", False),
    (r"\bdemand\s+(?P<a>for)\b", ["of", "on", "to"], "", False),
    (r"\bsolution\s+(?P<a>to)\b", ["of", "for", "at"], "", False),
    (r"\baccess\s+(?P<a>to)\b", ["of", "for", "at"], "", False),
    (r"\b(?:impact|effect|influence)\s+(?P<a>on)\b", ["in", "to", "at"], "", False),
    (r"\bneed\s+(?P<a>for)\b", ["of", "to", "on"], "", False),
    (r"\breason\s+(?P<a>for)\b", ["of", "to", "about"], "", False),
    (r"\bproblem\s+(?P<a>with)\b", ["of", "in", "at"], "", False),
    (r"\black\s+(?P<a>of)\b", ["for", "in", "from"], "", False),
    (r"\bprefer(?:s|red|ring)?\s+\w+(?:\s+\w+)?\s+(?P<a>to)\s+(?:the\s+)?\w+", ["than", "from", "at"], "", False),
    (r"\bprevent(?:s|ed|ing)?\s+\w+\s+(?P<a>from)\b", ["of", "to", "by"], "", False),
    (r"\bcommitted\s+(?P<a>to)\b", ["with", "for", "in"], "", False),
    (r"\bspecializ(?:e|es|ed|ing)\s+(?P<a>in)\b", ["on", "at", "of"], "", False),
]
PREP_RULES = [(re.compile(p, re.I), d, n, t) for p, d, n, t in PREP_RULES]


def rule_prepositions(s):
    for rx, ds, note, trap in PREP_RULES:
        for m in rx.finditer(s):
            st, en = m.span("a")
            ans = s[st:en]
            if ans.lower() not in PREPS:
                continue
            yield mk(s, st, en, ans, "preposition", _fix_case(ans, ds, st == 0), 0, "prep:" + ans.lower() + ":" + rx.pattern[:24], note, trap)


GER_V = r"(?:enjoy(?:s|ed|ing)?|avoid(?:s|ed|ing)?|suggest(?:s|ed|ing)?|consider(?:s|ed|ing)?|finish(?:es|ed|ing)?|mind(?:s|ed)?|keep(?:s|ing)?|kept|practi[cs]e[sd]?|delay(?:s|ed|ing)?|miss(?:es|ed|ing)?|imagin(?:e|es|ed|ing)|recommend(?:s|ed|ing)?|admit(?:s|ted)?|deny|denied|risk(?:s|ed|ing)?|postpone[sd]?|quit|appreciate[sd]?)"
INF_V = r"(?:want(?:s|ed)?|hope[sd]?|plan(?:s|ned)?|decide[sd]?|expect(?:s|ed)?|manage[sd]?|refuse[sd]?|agree[sd]?|offer(?:s|ed)?|promise[sd]?|afford(?:s|ed)?|learn(?:s|ed|t)?|fail(?:s|ed)?|tend(?:s|ed)?|seem(?:s|ed)?|pretend(?:s|ed)?|wish(?:es|ed)?|prepare[sd]?|choose|chose|intend(?:s|ed)?)"
OBJ_V = r"(?:want(?:s|ed)?|ask(?:s|ed)?|tell|tells|told|allow(?:s|ed)?|enable[sd]?|expect(?:s|ed)?|advise[sd]?|encourage[sd]?|invite[sd]?|remind(?:s|ed)?|warn(?:s|ed)?|force[sd]?|persuade[sd]?|order(?:s|ed)?|cause[sd]?|require[sd]?|need(?:s|ed)?)"
OBJ = r"(?:me|you|him|her|us|them)"
RX_GER = re.compile(rf"\b{GER_V}\s+(?P<a>\w+ing)\b", re.I)
RX_INF = re.compile(rf"\b{INF_V}\s+(?P<a>to\s+(?P<v>\w+))\b", re.I)
RX_OBJ = re.compile(rf"\b{OBJ_V}\s+{OBJ}\s+(?P<a>to\s+(?P<v>\w+))\b", re.I)
RX_MAKE = re.compile(rf"\b(?:make|makes|made|making|let|lets|letting)\s+{OBJ}\s+(?P<a>\w+)\b", re.I)


def rule_verb_patterns(s):
    for m in RX_GER.finditer(s):
        w = m.group("a")
        base = ING2BASE.get(w.lower())
        if not base:
            continue
        past = VERBS[base][0]
        st, en = m.span("a")
        yield mk(s, st, en, w, "verb-pattern", _fix_case(w, [f"to {base}", base, past], st == 0), 0, "vp:gerund",
                 "verb + -ing (enjoy/avoid/suggest/consider/finish...); Spanish speakers use the infinitive", True)
    for rx, tag in ((RX_INF, "inf"), (RX_OBJ, "obj-inf")):
        for m in rx.finditer(s):
            v = m.group("v").lower()
            if v not in VERBS:
                continue
            past, _pp, ing = VERBS[v]
            st, en = m.span("a")
            note = ("want/ask/tell/allow SB to do: Spanish 'quiero que hagas' is not 'want that you do'" if tag == "obj-inf"
                    else "verb + to-infinitive")
            yield mk(s, st, en, s[st:en], "verb-pattern", _fix_case(s[st:en], [ing, v, past], st == 0), 0, f"vp:{tag}", note, tag == "obj-inf")
    for m in RX_MAKE.finditer(s):
        v = m.group("a").lower()
        if v not in VERBS:
            continue
        past, _pp, ing = VERBS[v]
        st, en = m.span("a")
        yield mk(s, st, en, s[st:en], "verb-pattern", _fix_case(s[st:en], [f"to {v}", ing, past], st == 0), 0, "vp:make-let",
                 "make/let + object + bare infinitive; Spanish speakers add 'to'", True)


RX_ARTICLES = [
    (re.compile(r"\bsuch\s+(?P<a>an?)\s+\w+", re.I), "art:such-a"),
    (re.compile(r"\bwhat\s+(?P<a>an?)\s+\w+", re.I), "art:what-a"),
    (re.compile(r"\bquite\s+(?P<a>an?)\s+\w+", re.I), "art:quite-a"),
    (re.compile(r"\bhalf\s+(?P<a>an?)\s+(?:hour|day|year)\b", re.I), "art:half-a"),
    (re.compile(r"\b(?P<a>a)\s+(?:lot of|couple of|bit of|number of)\b", re.I), "art:a-lot"),
    (re.compile(r"\b(?P<a>the)\s+(?:most\s+\w+|(?!interest|west|east|forest|request|suggest|guest|rest|test|invest|harvest|contest|quest|honest|modest|nest|chest|protest|arrest|digest|manifest|crest)\w{3,}est)\b", re.I), "art:superlative"),
    (re.compile(r"\b(?P<a>the)\s+(?:same|only)\s+\w+", re.I), "art:the-same"),
    (re.compile(r"\b(?:at|in)\s+(?P<a>the)\s+(?:moment|end|morning|afternoon|evening)\b", re.I), "art:the-fixed"),
    (re.compile(r"\bon\s+(?P<a>the)\s+(?:other hand|phone|internet|whole)\b", re.I), "art:the-fixed"),
    (re.compile(r"\bplay(?:s|ed|ing)?\s+(?P<a>the)\s+(?:guitar|piano|violin|drums|saxophone|flute|trumpet|cello)\b", re.I), "art:instrument"),
]
RX_NOART = [
    (re.compile(r"\bby\s+(?P<n>(?:car|bus|train|plane|bike|taxi|subway|ferry|metro|bicycle|boat))\b", re.I), "art:by-transport"),
    (re.compile(r"\bat\s+(?P<n>home|work)\b", re.I), "art:at-home"),
]


def rule_articles(s):
    for rx, rid in RX_ARTICLES:
        for m in rx.finditer(s):
            st, en = m.span("a")
            ans = s[st:en]
            given = [x for x in ("a", "an", "the", NOART) if x != ans.lower()]
            if st == 0:
                given = [x if x == NOART else x.capitalize() for x in given]
            note = "Spanish uses the article in some places English does not, and the reverse" if rid in ("art:the-fixed", "art:instrument") else ""
            yield mk(s, st, en, ans, "article", given, 0, rid, note, rid == "art:instrument")
    for rx, rid in RX_NOART:
        for m in rx.finditer(s):
            yield mk(s, 0, 0, NOART, "article", ["a", "an", "the"], 0, rid,
                     "no article in these fixed phrases (at home, by bus): Spanish says 'en la casa'", True, insert_at=m.start("n"))


def rule_linkers(s):
    def one(rx, ans, ds, rid, note, trap=True):
        for m in re.finditer(rx, s, re.I if rid != "link:so" else 0):
            st, en = m.span("a")
            yield mk(s, st, en, s[st:en], "linker", _fix_case(s[st:en], ds, st == 0), 0, rid, note, trap)
    yield from one(r"\b(?P<a>although)\s+(?:it|he|she|they|we|I|the|there|this|that|you)\b", "although", ["despite", "however", "because"], "link:although", "although + clause vs despite + noun")
    yield from one(r"\b(?P<a>despite)\s+(?:the|his|her|their|our|my|its)\s+\w+(?:\s+\w+)?,", "despite", ["although", "however", "because"], "link:despite", "despite + noun phrase, no 'of'")
    yield from one(r"\b(?P<a>in spite of)\b", "in spite of", ["despite of", "although", "in spite"], "link:inspite", "'in spite of' or 'despite', never 'despite of'")
    yield from one(r",\s+(?P<a>so)\s+(?:I|we|he|she|they|it|the|there)\b", "so", ["because", "although", "unless"], "link:so", "result clause", False)
    yield from one(r"(?:,|\s)\s*(?P<a>whereas)\s+\w+", "whereas", ["because", "so", "unless"], "link:whereas", "", False)
    yield from one(r"\b(?P<a>instead of)\s+\w+ing\b", "instead of", ["instead", "rather", "besides"], "link:insteadof", "'instead of' + -ing/noun; 'instead' stands alone")
    yield from one(r"\b(?P<a>during)\s+(?:the|my|his|her|our|their|this|that|a)\s+\w+", "during", ["while", "however", "because"], "link:during", "during + noun vs while + clause")
    yield from one(r"\b(?P<a>because of)\s+(?:the|his|her|their|our|my|its|this|that)\s+\w+(?:,|\.)", "because of", ["because", "although", "so"], "link:becauseof", "because of + noun phrase; because + clause")


ADJ_TABLE = [  # (-ed, -ing, filler, filler)
    ("bored", "boring", "bore", "boredom"), ("interested", "interesting", "interest", "interests"),
    ("excited", "exciting", "excite", "excitement"), ("tired", "tiring", "tire", "tires"),
    ("surprised", "surprising", "surprise", "surprisingly"), ("confused", "confusing", "confuse", "confusion"),
    ("disappointed", "disappointing", "disappoint", "disappointment"), ("annoyed", "annoying", "annoy", "annoyance"),
    ("worried", "worrying", "worry", "worries"), ("satisfied", "satisfying", "satisfy", "satisfaction"),
    ("frustrated", "frustrating", "frustrate", "frustration"), ("shocked", "shocking", "shock", "shocks"),
    ("embarrassed", "embarrassing", "embarrass", "embarrassment"), ("amazed", "amazing", "amaze", "amazement"),
    ("fascinated", "fascinating", "fascinate", "fascination"), ("exhausted", "exhausting", "exhaust", "exhaustion"),
    ("relaxed", "relaxing", "relax", "relaxation"), ("overwhelmed", "overwhelming", "overwhelm", "overwhelmingly"),
    ("motivated", "motivating", "motivate", "motivation"), ("inspired", "inspiring", "inspire", "inspiration"),
    ("alarmed", "alarming", "alarm", "alarmingly"), ("depressed", "depressing", "depress", "depression"),
    ("thrilled", "thrilling", "thrill", "thrills"), ("convinced", "convincing", "convince", "conviction"),
    ("challenged", "challenging", "challenge", "challenges"),
]
ADJ_LOOKUP = {}
for _row in ADJ_TABLE:
    for _i in (0, 1):
        ADJ_LOOKUP.setdefault(_row[_i], _row)
RX_ADJ = re.compile(r"\b(?:is|are|was|were|am|be|been|feel|feels|felt|feeling|seem|seems|seemed|look|looks|looked|find|found|get|gets|got|"
                    r"become|became|sound|sounds|sounded|very|really|so|quite|too|rather|extremely|pretty|totally|completely|absolutely)\s+(?P<a>\w+)\b", re.I)


def rule_adjectives(s):
    for m in RX_ADJ.finditer(s):
        w = m.group("a")
        row = ADJ_LOOKUP.get(w.lower())
        if not row:
            continue
        st, en = m.span("a")
        ds = [x for x in row if x != w.lower()]
        yield mk(s, st, en, w, "word-form", _fix_case(w, ds, st == 0), 0, "adj:ed-ing",
                 "-ed describes how a person feels; -ing describes the thing that causes it (bored/boring)", True)


FAMILIES = [  # noun, verb, adjective, adverb ("" if none)
    ("success", "succeed", "successful", "successfully"), ("difference", "differ", "different", "differently"),
    ("comparison", "compare", "comparative", "comparatively"), ("creation", "create", "creative", "creatively"),
    ("production", "produce", "productive", "productively"), ("competition", "compete", "competitive", "competitively"),
    ("beauty", "", "beautiful", "beautifully"), ("safety", "", "safe", "safely"),
    ("strength", "strengthen", "strong", "strongly"), ("efficiency", "", "efficient", "efficiently"),
    ("reliability", "rely", "reliable", "reliably"), ("analysis", "analyze", "analytical", "analytically"),
    ("economy", "", "economic", "economically"), ("danger", "endanger", "dangerous", "dangerously"),
    ("popularity", "popularize", "popular", "popularly"), ("importance", "", "important", "importantly"),
    ("significance", "", "significant", "significantly"), ("possibility", "", "possible", "possibly"),
    ("decision", "decide", "decisive", "decisively"), ("communication", "communicate", "communicative", "communicatively"),
    ("development", "develop", "developing", "developmental"), ("improvement", "improve", "improved", "improvingly"),
    ("preparation", "prepare", "prepared", "preparatory"), ("explanation", "explain", "explanatory", "explicitly"),
    ("variety", "vary", "various", "variously"), ("responsibility", "", "responsible", "responsibly"),
    ("accuracy", "", "accurate", "accurately"),
]
STOP_FAM = {"improved", "prepared", "improvingly", "developing", "popularly", "explicitly", "developmental", "preparatory", "explanatory",
            "variously", "communicatively", "analytically", "decisively", "decisive", "popularize", "strengthen", "endanger", "comparatively"}
FAM_LOOKUP: dict[str, tuple] = {}
for _fam in FAMILIES:
    for _w in _fam:
        if _w:
            FAM_LOOKUP.setdefault(_w, _fam)


def rule_wordform(s):
    for m in re.finditer(r"[A-Za-z]+", s):
        w = m.group().lower()
        fam = FAM_LOOKUP.get(w)
        if not fam or w in STOP_FAM:
            continue
        ds = [x for x in fam if x and x != w and x not in STOP_FAM]
        if len(ds) < 2:
            continue
        given = ds[:3]
        st, en = m.span()
        yield mk(s, st, en, m.group(), "word-form", _fix_case(m.group(), given, st == 0), 3 - len(given), "wf:family",
                 "word families: noun/verb/adjective/adverb; pick the form the sentence slot needs", False)


LEMMAS = {  # base, 3sg, past, ing, pp
    "make": ("make", "makes", "made", "making", "made"), "do": ("do", "does", "did", "doing", "done"),
    "take": ("take", "takes", "took", "taking", "taken"), "have": ("have", "has", "had", "having", "had"),
    "get": ("get", "gets", "got", "getting", "got"), "give": ("give", "gives", "gave", "giving", "given"),
}
MAKE_NOUNS = {  # noun -> other lemmas that are also valid (excluded from distractors)
    "decision": {"take"}, "decisions": {"take"}, "mistake": set(), "mistakes": set(), "effort": set(), "efforts": set(), "progress": set(),
    "sense": set(), "difference": set(), "plan": {"have"}, "plans": {"have"}, "suggestion": {"give"}, "suggestions": {"give"},
    "money": {"get"}, "appointment": set(), "offer": {"give"}, "mess": set(), "noise": set(), "impression": {"get", "give"},
    "choice": set(), "choices": set(), "point": set(), "profit": {"get"}, "contribution": set(), "improvement": set(),
    "improvements": set(), "promise": {"give"}, "comment": {"give"}, "comments": {"give"}, "complaint": set(),
    "deal": {"get"}, "excuse": {"give"}, "excuses": {"give"}, "attempt": set(), "speech": {"give"},
    "contact": {"get"}, "recommendation": {"give"}, "recommendations": {"give"}, "payment": set(), "reservation": set(),
    "change": {"get"}, "changes": {"get"}, "call": {"give", "get"}, "calls": {"give", "get"}, "fortune": set(),
}
DO_NOUNS = {"homework": set(), "research": set(), "business": set(), "damage": set(), "harm": set(), "job": set(), "favor": set(),
            "favour": set(), "exercise": set(), "exercises": set(), "shopping": set(), "laundry": set(), "dishes": set(), "housework": set(),
            "good": set(), "analysis": set(), "survey": set(), "math": set(), "maths": set(), "work": {"get"},
            "wonders": set(), "chores": set(), "study": set(), "experiment": set(), "experiments": set()}
ALL_MD = {f: l for l in ("make", "do") for f in LEMMAS[l]}
RX_MD = re.compile(r"\b(?P<a>make|makes|made|making|do|does|did|done|doing)\s+(?:(?:a|an|the|some|any|more|no|my|your|his|her|our|their|good|great|big)\s+)?(?P<n>[a-z]+)\b", re.I)


def rule_collocations(s):
    for m in RX_MD.finditer(s):
        v, n = m.group("a").lower(), m.group("n").lower()
        lemma = ALL_MD[v]
        table = MAKE_NOUNS if lemma == "make" else DO_NOUNS
        if n not in table:
            continue
        if lemma == "make" and v == "done":
            continue
        slot = LEMMAS[lemma].index(v) if v in LEMMAS[lemma] else 0
        if lemma == "make" and v == "made":
            slot = 2
        valid = table[n] | {lemma}
        others = [l for l in ("make", "do", "take", "have", "get", "give") if l not in valid]
        random.Random(hval(s)).shuffle(others)
        swap = "do" if lemma == "make" else "make"
        pick = ([swap] if swap not in valid else []) + [o for o in others if o != swap]
        ds = [d for d in dict.fromkeys(LEMMAS[l][slot] for l in pick[:4]) if d != v][:3]
        if len(ds) < 3:
            continue
        st, en = m.span("a")
        yield mk(s, st, en, m.group("a"), "collocation", _fix_case(m.group("a"), ds, st == 0), 0, f"coll:{lemma}-{n}",
                 "make vs do (hacer): make = create/produce, do = activity/task", True)


RX_FOR = re.compile(r"\b(?P<a>for)\s+(?:\d+|a|an|one|two|three|four|five|six|seven|eight|nine|ten|several|many|a few|about|almost|over|nearly)\s+(?:\w+\s+)?(?:seconds?|minutes?|hours?|days?|weeks?|months?|years?|decades?)\b", re.I)
RX_SINCE = re.compile(r"\b(?P<a>since)\s+(?:(?:19|20)\d\d\b|last\b|yesterday\b|Monday\b|Tuesday\b|Wednesday\b|Thursday\b|Friday\b|Saturday\b|Sunday\b|January\b|February\b|March\b|April\b|May\b|June\b|July\b|August\b|September\b|October\b|November\b|December\b|the (?:beginning|start)\b|then\b)", re.I)


def rule_since_for(s):
    note = "for + length of time, since + starting point (Spanish 'desde hace' / 'desde')"
    for m in RX_FOR.finditer(s):
        st, en = m.span("a")
        yield mk(s, st, en, s[st:en], "preposition", _fix_case("for", ["since", "during", "from"], st == 0), 0, "prep:for-duration", note, True)
    for m in RX_SINCE.finditer(s):
        st, en = m.span("a")
        yield mk(s, st, en, s[st:en], "preposition", _fix_case("since", ["for", "during", "from"], st == 0), 0, "prep:since-point", note, True)


FF = [  # (word regex, distractors, note)
    (r"\b(?P<a>actual)\b", ["current", "present", "recent"], "actual = real, not 'current' (Spanish actual = current)"),
    (r"\b(?P<a>actually)\b", ["currently", "recently", "finally"], "actually = in fact, not 'currently'"),
    (r"\b(?P<a>currently)\b", ["actually", "really", "exactly"], "currently = at present; 'actually' is the false friend"),
    (r"\b(?P<a>current)\b", ["actual", "real", "exact"], "current = present; 'actual' means real"),
    (r"\b(?P<a>eventually)\b", ["possibly", "occasionally", "definitely"], "eventually = in the end, not 'eventualmente' (possibly)"),
    (r"\b(?P<a>sensible)\b", ["sensitive", "sensual", "senseless"], "sensible = reasonable; 'sensitive' = sensible in Spanish"),
    (r"\b(?P<a>sensitive)\b", ["sensible", "sensational", "sentimental"], "sensitive = easily affected; 'sensible' = reasonable"),
    (r"\b(?P<a>attend)\b", ["assist", "assume", "accept"], "attend = go to; 'assist' = help (asistir a = attend)"),
    (r"\b(?P<a>attended)\b", ["assisted", "assumed", "accepted"], "attend = go to; 'assist' = help (asistir a = attend)"),
    (r"\b(?P<a>assist)\b", ["attend", "assume", "accept"], "assist = help; asistir a = attend"),
    (r"\b(?P<a>intend)\b", ["pretend", "extend", "attend"], "intend = plan to; 'pretend' = fingir"),
    (r"\b(?P<a>intended)\b", ["pretended", "extended", "attended"], "intend = plan to; 'pretend' = fingir"),
    (r"\b(?P<a>pretend)\b", ["intend", "extend", "attend"], "pretend = act as if; 'intend' = pretender"),
    (r"\b(?P<a>summari[sz]e)\b", ["resume", "assume", "presume"], "summarize = give a short version; 'resume' = continue"),
    (r"\b(?P<a>resume)\b", ["summarize", "assume", "presume"], "resume = continue; summarize = resumir"),
]
FF = [(re.compile(p, re.I), d, n) for p, d, n in FF]


def rule_false_friends(s):
    for rx, ds, note in FF:
        for m in rx.finditer(s):
            st, en = m.span("a")
            w = m.group("a")
            yield mk(s, st, en, w, "false-friend", _fix_case(w, ds, st == 0), 0, "ff:" + w.lower(), note, True)


RX_REL = [
    (re.compile(r"\b(?:the|a|an|those|these)\s+(?:people|person|man|men|woman|women|colleagues?|friends?|customers?|employees?|managers?|engineers?|clients?|team members?|users?)\s+(?P<a>who)\s+\w+", re.I), "who", ["which", "whose", "where"]),
    (re.compile(r"\b(?:the|a|an)\s+(?:place|city|town|country|house|room|office|building|area|village|restaurant|hotel|store|shop|factory|warehouse)\s+(?P<a>where)\s+(?:I|we|he|she|they|you|the|it)\b", re.I), "where", ["which", "who", "whose"]),
    (re.compile(r"\b(?:the|a|an)\s+(?:book|report|project|system|product|idea|document|tool|plan|company|machine|device|process|app|website|software)\s+(?P<a>which)\s+\w+", re.I), "which", ["who", "whose", "where"]),
    (re.compile(r"\b\w+\s+(?P<a>whose)\s+\w+", re.I), "whose", ["who", "which", "whom"]),
]


def rule_relative(s):
    for rx, ans, ds in RX_REL:
        for m in rx.finditer(s):
            st, en = m.span("a")
            if s[st:en].lower() == ans:
                yield mk(s, st, en, s[st:en], "relative", _fix_case(ans, ds, st == 0), 0, f"rel:{ans}", "", False)


RX_AGR = [
    re.compile(r"\b(?:everyone|everybody|nobody|everything|something|nothing|someone|somebody|each of the \w+s|one of the \w+s|neither of the \w+s)\s+(?P<a>is|was|has|does)\b", re.I),
    re.compile(r"\bThere\s+(?P<a>is|was)\s+(?:a|an|one|much|little|another)\b"),
    re.compile(r"\bThere\s+(?P<a>are|were)\s+(?:many|several|two|three|four|five|six|a few|a number of)\b"),
]
AGR_D = {"is": ["are", "were", "being"], "was": ["were", "are", "being"], "has": ["have", "are", "were"], "does": ["do", "are", "were"],
         "are": ["is", "was", "being"], "were": ["was", "is", "being"]}


def rule_agreement(s):
    for rx in RX_AGR:
        for m in rx.finditer(s):
            st, en = m.span("a")
            w = s[st:en]
            if w.lower() in AGR_D:
                yield mk(s, st, en, w, "agreement", _fix_case(w, AGR_D[w.lower()], st == 0), 0, "agr:" + w.lower(),
                         "subject-verb agreement (everyone/nobody/one of + singular verb; there is/are + noun)", True)


RX_PERF = re.compile(r"\b(?P<a>(?:has|have)\s+(?P<v>\w+))\b")
PERF_SIGNAL = re.compile(r"\b(since|so far|yet|ever|recently|lately|for the (?:last|past))\b", re.I)
PAST_SIGNAL = re.compile(r"\b(yesterday|last (?:night|week|month|year|summer|winter|Monday|Friday|weekend)|\d+ (?:days?|weeks?|months?|years?|hours?) ago|in (?:19|20)\d\d)\b", re.I)


def rule_tense(s):
    if PERF_SIGNAL.search(s):
        for m in RX_PERF.finditer(s):
            v = m.group("v").lower()
            if v in PP2BASE or (v.endswith("ed") and lem(v)):
                st, en = m.span("a")
                yield mk(s, st, en, s[st:en], "tense", [], 3, "tense:perfect",
                         "present perfect with since / so far / yet / ever / the last few years", True)
                break
    if PAST_SIGNAL.search(s):
        for m in re.finditer(r"\b(?P<a>[a-z]+)\b", s):
            w = m.group("a")
            if w in IRREG_PAST and m.start() > 0:
                st, en = m.span("a")
                yield mk(s, st, en, w, "tense", [], 3, "tense:past", "past simple with a finished-time expression (yesterday, last week, ago)", True)
                break


RX_PASS = re.compile(r"\b(?:is|are|was|were|been|be)\s+(?P<a>\w+)\s+by\b", re.I)


def rule_passive(s):
    for m in RX_PASS.finditer(s):
        w = m.group("a").lower()
        base = PP2BASE.get(w)
        if base is None:
            continue
        past, pp, ing = VERBS[base]
        ds = [x for x in dict.fromkeys([past, base, ing]) if x != w]
        if len(ds) < 3:
            ds.append(f"to {base}")
        st, en = m.span("a")
        yield mk(s, st, en, s[st:en], "passive", _fix_case(w, ds[:3], st == 0), 0, "passive:by",
                 "passive voice: be + past participle (+ by agent)", False)


RULES = [rule_prepositions, rule_verb_patterns, rule_articles, rule_linkers, rule_adjectives, rule_wordform, rule_collocations,
         rule_since_for, rule_false_friends, rule_relative, rule_agreement, rule_tense, rule_passive]


def sentence_pool(rej: Counter) -> list[dict]:
    """Clean English sentences from the other converters' stages, with source facts."""
    part = json.loads((ROOT / ".ingest/stage/tatoeba/partition.json").read_text())
    claimed = set(part.get("listenRepeat_eng_ids", [])) | set(part.get("translate_eng_ids", []))
    pool: list[dict] = []
    seen: set[str] = set()

    def add(text, **kw):
        t = re.sub(r"\s+", " ", textnorm.fix_unicode(text)).strip()
        k = textnorm.text_hash(t)
        if k in seen:
            return
        seen.add(k)
        if not 7 <= textnorm.word_count(t) <= 26:
            rej["pool: length not 7-26 words"] += 1
            return
        why = surface_ok(t)
        if why:
            rej[f"pool: {why}"] += 1
            return
        pool.append(dict(text=t, **kw))

    for r in read_jsonl(ROOT / ".ingest/stage/tatoeba/pairs.jsonl"):
        if r["engId"] in claimed:
            rej["pool: tatoeba id claimed by listenRepeat/translate"] += 1
            continue
        add(r["en"], src="rules", corpus="tatoeba", sourceId=f"tatoeba-{r['engId']}")
    for r in read_jsonl(ROOT / ".ingest/stage/openstax/paragraphs.jsonl"):
        for i, sent in enumerate(textnorm.split_sentences(r["text"])):
            add(sent, src="rules", corpus="openstax", sourceId=f"openstax-{r['sourceId']}-s{i}")
    for fname in ("windows.jsonl", "readacademic.jsonl"):
        for r in read_jsonl(ROOT / ".ingest/stage/onestopenglish" / fname):
            for i, sent in enumerate(textnorm.split_sentences(r["text"])):
                add(sent, src="rules-ose", corpus="ose", sourceId=f"ose-{r['sourceId']}-s{i}")
    return pool


def rule_candidates(rej: Counter) -> list[dict]:
    out = []
    for p in sentence_pool(rej):
        for rule in RULES:
            for c in rule(p["text"]):
                low = [d.lower() for d in c["given"]]
                if len(set(low)) != len(low) or c["answer"].lower() in low or any(not d for d in c["given"]):
                    rej["rules: bad/duplicate distractors"] += 1
                    continue
                if c["sentence"].count("____") != 1:
                    rej["rules: blank problem"] += 1
                    continue
                c.update(origin=p["src"], corpus=p["corpus"], sourceId=p["sourceId"], learnerError="")
                out.append(c)
    return out


# ---------------------------------------------------------------- selection, ids, batches
def existing_filled(index: DedupeIndex) -> None:
    """Existing grammarMC items are indexed with their answer filled in, so a rebuilt sentence is caught."""
    for f in sorted((ROOT / "Content/items").glob("*.json")):
        for it in json.loads(f.read_text(encoding="utf-8")):
            if it.get("type") == "grammarMC" and "____" in it.get("sentence", ""):
                try:
                    ans = it["options"][it["answer"]]
                except (KeyError, IndexError):
                    continue
                s = it["sentence"]
                filled = re.sub(r"\s+", " ", s.replace("____ ", "").replace("____", "")) if ans == NOART else s.replace("____", ans)
                index.add("filled-" + it["id"], filled)


def score_row(c: dict) -> float:
    s = 1.5 * workplace.score(c["filled"])
    s += 0.6 if c.get("trap") else 0.0
    s += 0.3 if 10 <= textnorm.word_count(c["filled"]) <= 22 else 0.0
    s += 0.4 if c["origin"] == "coedit" else 0.0
    s += (hval(c["filled"] + c["ruleId"]) % 1000) / 4000
    return s


def cmd_fetch(a):
    raw = Path(a.raw)
    raw.mkdir(parents=True, exist_ok=True)
    meta = json.loads(urllib.request.urlopen(API, timeout=60).read())
    lic = (meta.get("cardData") or {}).get("license")
    tags = [t for t in meta.get("tags", []) if t.startswith("license:")]
    print("HF license:", lic, tags, "sha:", meta.get("sha"))
    if lic != "apache-2.0" or "license:apache-2.0" not in tags:
        sys.exit("CoEdIT license is not apache-2.0 at the source; stop and re-check before using any row.")
    (raw / "license-check.json").write_text(json.dumps({"license": lic, "tags": tags, "sha": meta.get("sha")}, indent=1))
    local = ROOT / ".ingest/raw/coedit/README.md"
    if local.exists() and "license: apache-2.0" not in local.read_text()[:400]:
        sys.exit("local CoEdIT README does not say apache-2.0; stop.")
    print("ok: nothing to download; extract reads the staged gec pairs from .ingest/stage/coedit/")


def cmd_extract(a):
    stage = Path(a.stage)
    (stage / "batches").mkdir(parents=True, exist_ok=True)
    for old in (stage / "batches").glob("batch-*.jsonl"):
        old.unlink()
    rej: Counter = Counter()
    lic = ROOT / ".ingest/raw/coedit-grammar/license-check.json"
    if not lic.exists() or json.loads(lic.read_text()).get("license") != "apache-2.0":
        sys.exit("run `fetch` first: CoEdIT license check missing or not apache-2.0")

    cands = coedit_candidates(rej) + rule_candidates(rej)
    raw_counts = Counter((c["patternHint"], "coedit" if c["origin"] == "coedit" else "rules") for c in cands)
    index = DedupeIndex.from_content(ROOT / "Content")
    existing_filled(index)

    cands.sort(key=lambda c: -score_row(c))
    kept, seen_filled = [], set()
    for c in cands:
        key = textnorm.text_hash(c["filled"])
        if key in seen_filled:
            rej["dedupe: same sentence already used by a better candidate"] += 1
            continue
        reason = index.check(c["filled"])
        if reason:
            rej["dedupe: " + ("near" if reason.startswith("near") else "exact") + " duplicate of existing Content/"] += 1
            continue
        c["cefr"] = cefr.estimate(c["filled"])
        seen_filled.add(key)
        kept.append(c)

    by_pat: dict[str, list[dict]] = defaultdict(list)
    ans_count: Counter = Counter()
    fn_patterns = ("preposition", "article", "linker", "relative", "agreement")
    for c in kept:
        k = (c["patternHint"], c["answer"].lower() if c["patternHint"] in fn_patterns else c["ruleId"])
        if ans_count[k] >= (a.cap_answer if c["patternHint"] in fn_patterns else a.cap_rule):
            rej["cap: too many with the same answer/rule within a pattern"] += 1
            continue
        ans_count[k] += 1
        by_pat[c["patternHint"]].append(c)
    chosen = []
    for pat in PATTERNS:
        rows = by_pat.get(pat, [])
        ce = [c for c in rows if c["origin"] == "coedit"]
        by_rule: dict[str, list[dict]] = defaultdict(list)
        for c in rows:
            if c["origin"] != "coedit":
                by_rule[c["ruleId"]].append(c)
        rr = []
        while any(by_rule.values()):  # round-robin so one rule cannot swallow the quota
            for k in sorted(by_rule):
                if by_rule[k]:
                    rr.append(by_rule[k].pop(0))
        n_ce = min(len(ce), int(a.per_pattern * a.coedit_share))
        n_ru = min(len(rr), a.per_pattern - n_ce)
        n_ce = min(len(ce), a.per_pattern - n_ru)
        chosen += ce[:n_ce] + rr[:n_ru]
    for c in chosen:
        sig = c["sentence"] + "|" + c["answer"]
        c["emit"] = "coedit" if c["origin"] == "coedit" else c["origin"]  # rules | rules-ose
        c["id"] = ids.hashed_id("grammarMC", "coedit" if c["emit"] == "coedit" else "rules", sig)
    assert len({c["id"] for c in chosen}) == len(chosen), "id collision"

    full = []
    for c in chosen:
        meta = FILES[c["emit"]]
        full.append({**{k: c[k] for k in ("id", "sourceId", "sentence", "filled", "answer", "given", "need", "patternHint", "ruleId",
                                           "learnerError", "note", "trap", "cefr")},
                     "emitFile": meta["file"], "source": meta["source"], "license": meta["license"], "tier": meta["tier"],
                     "corpus": c.get("corpus", "coedit"), "workplace": round(workplace.score(c["filled"]), 3), "origin": "adapted"})
    (stage / "candidates.jsonl").write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in full), encoding="utf-8")

    slim = [{"id": r["id"], "sentence": r["sentence"], "answer": r["answer"], "givenWrong": r["given"],
             "needDistractors": r["need"], "patternHint": r["patternHint"], "cefrHint": r["cefr"],
             "learnerError": r["learnerError"], "note": r["note"]} for r in full]
    slim.sort(key=lambda r: hval(r["id"]))
    nb = max(1, round(len(slim) / 50))
    size = -(-len(slim) // nb)
    batches = [slim[i:i + size] for i in range(0, len(slim), size)]
    for i, b in enumerate(batches, 1):
        (stage / "batches" / f"batch-{i:03d}.jsonl").write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in b), encoding="utf-8")

    sel = Counter((r["patternHint"], r["emitFile"]) for r in full)
    (stage / "selection.json").write_text(json.dumps({
        "total": len(full), "batches": len(batches), "batchSizes": [len(b) for b in batches],
        "byPattern": dict(Counter(r["patternHint"] for r in full)), "byFile": dict(Counter(r["emitFile"] for r in full)),
        "byPatternFile": {f"{p}|{f}": n for (p, f), n in sorted(sel.items())},
        "needDistractors": dict(Counter(r["need"] for r in full)),
        "candidatesBeforeSelection": {f"{p}|{s}": n for (p, s), n in sorted(raw_counts.items())},
    }, indent=1))
    write_report(full, rej, raw_counts, len(batches))
    print(f"selected {len(full)} rows in {len(batches)} batches; patterns {dict(Counter(r['patternHint'] for r in full))}")


def write_report(full, rej, raw_counts, nbatches):
    rnd = random.Random(7)
    lines = ["# coedit-grammar (C10 grammarMC part + C11 rule-based grammarMC)", "",
             f"Selected {len(full)} rows in {nbatches} batches (staged; LLM fill pending).", "", "## By pattern", ""]
    for p in PATTERNS:
        n_ce = sum(1 for r in full if r["patternHint"] == p and r["emitFile"] == "grammar-coedit.json")
        n_ru = sum(1 for r in full if r["patternHint"] == p and r["emitFile"] != "grammar-coedit.json")
        lines.append(f"- {p}: {n_ce + n_ru} (coedit {n_ce}, rules {n_ru}); candidates before selection: "
                     f"coedit {raw_counts.get((p, 'coedit'), 0)}, rules {raw_counts.get((p, 'rules'), 0)}")
    lines += ["", "## By output file", ""] + [f"- {f}: {n}" for f, n in Counter(r["emitFile"] for r in full).items()]
    lines += ["", "## Rows needing LLM distractors", ""] + [f"- need {k}: {v}" for k, v in sorted(Counter(r["need"] for r in full).items())]
    lines += ["", "## Reject reasons", ""] + [f"- {k}: {v}" for k, v in rej.most_common()]
    lines += ["", "## 30-row sample", ""]
    for r in rnd.sample(full, min(30, len(full))):
        lines.append(f"- [{r['patternHint']}/{r['ruleId']}] {r['sentence']}  -> **{r['answer']}**  given={r['given']} need={r['need']} ({r['emitFile']})")
    (ROOT / ".ingest/reports/coedit-grammar.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


EMIT_REPORT_MARK = "\n## Emit\n"


def load_filled(stage: Path):
    """id -> (filled row, batch name); also per-batch totals."""
    rows, per = {}, {}
    for f in sorted((stage / "batches").glob("batch-*.filled.jsonl")):
        name = f.name.replace(".filled.jsonl", "")
        per[name] = Counter()
        for r in read_jsonl(f):
            rows[r["id"]] = (r, name)
            per[name][r["verdict"]] += 1
    return rows, per


def cmd_emit(a):
    from lib import emit as emitlib
    stage = Path(a.stage)
    content = ROOT / "Content"
    filled, per_batch = load_filled(stage)
    cands = list(read_jsonl(stage / "candidates.jsonl"))
    drop: Counter = Counter()
    by_file: dict[str, list[dict]] = defaultdict(list)
    own = {m["file"] for m in FILES.values()}  # rewritten by this emit: not part of the dedupe baseline
    index = DedupeIndex()
    for f in sorted((content / "items").glob("*.json")):
        if f.name in own:
            continue
        for it in json.loads(f.read_text(encoding="utf-8")):
            try:
                index.add(it["id"], item_text(it))
            except Exception:
                pass
    for f in sorted((content / "items").glob("*.json")):
        if f.name in own:
            continue
        for it in json.loads(f.read_text(encoding="utf-8")):
            if it.get("type") == "grammarMC" and "____" in it.get("sentence", ""):
                try:
                    index.add("filled-" + it["id"], it["sentence"].replace("____", it["options"][it["answer"]]))
                except (KeyError, IndexError):
                    pass
    for c in cands:
        fr = filled.get(c["id"])
        if not fr:
            drop["no filled row"] += 1
            continue
        r, _b = fr
        if r["verdict"] != "ok":
            drop["llm reject"] += 1
            continue
        if re.search(r"\$ |\d %|--|\s{2}| [,.;:?!]|\( | \)", c["sentence"]):
            drop["spacing/punctuation artifact in sentence"] += 1
            continue
        ans = c["answer"]
        dis = [d.strip() for d in c["given"] + r["distractors"]]
        low = [d.lower() for d in dis]
        if len(dis) != 3 or len(set(low)) != 3 or ans.lower() in low or any(not d for d in dis):
            drop["distractors not 3 distinct and different from the key"] += 1
            continue
        if c["sentence"].lstrip().startswith("____") and ans[:1].isupper():
            dis = [d[:1].upper() + d[1:] if d != NOART else d for d in dis]
        elif ans[:1].islower() and not ans.startswith("("):
            dis = [d[:1].lower() + d[1:] if d[:1].isupper() and not d.startswith("I ") and d != "I" else d for d in dis]
        pat = r["pattern"] if r["pattern"] in schema_patterns() else c["patternHint"]
        lvl = r["cefr"] if r["cefr"] in ("B1", "B2", "C1") else c["cefr"][:2]
        if not r["explanation"].strip():
            drop["empty explanation"] += 1
            continue
        opts = [ans] + dis
        random.Random(c["id"]).shuffle(opts)
        item = {"id": c["id"], "type": "grammarMC", "cefr": lvl, "skill": "grammar", "sentence": c["sentence"],
                "options": opts, "answer": opts.index(ans), "explanation": r["explanation"].strip(), "pattern": pat,
                "source": c["source"], "sourceId": c["sourceId"], "license": c["license"], "tier": c["tier"],
                "origin": "adapted"}
        if c["workplace"] >= 0.5:
            item["topics"] = ["workplace"]
        dup = index.check_and_add(c["id"], c["filled"])
        if dup:
            drop["dedupe: near duplicate within emitted set or other Content"] += 1
            continue
        probs = schema.problems_item(item)
        if probs:
            drop["schema: " + probs[0]] += 1
            continue
        by_file[c["emitFile"]].append(item)
    out_counts = {}
    for fn, rows_ in by_file.items():
        meta = next(m for m in FILES.values() if m["file"] == fn)
        rows_.sort(key=lambda x: x["id"])
        emitlib.emit(content, "items", fn, rows_, source=meta["source"], url=meta["url"], license=meta["license"],
                     tier=meta["tier"], attribution=meta["attribution"])
        out_counts[fn] = len(rows_)
    # report
    rp = ROOT / ".ingest/reports/coedit-grammar.md"
    txt = rp.read_text(encoding="utf-8")
    txt = txt.split(EMIT_REPORT_MARK)[0].rstrip("\n") + "\n"
    allitems = [i for v in by_file.values() for i in v]
    L = [EMIT_REPORT_MARK.strip(), "", f"Emitted {len(allitems)} items: " + ", ".join(f"{k} {v}" for k, v in sorted(out_counts.items())), "",
         "### Filters", ""] + [f"- {k}: {v}" for k, v in drop.most_common()]
    L += ["", "### LLM reject rate per batch (>30% flagged)", ""]
    for b, c_ in per_batch.items():
        tot = sum(c_.values())
        rate = c_["reject"] / tot
        L.append(f"- {b}: {c_['reject']}/{tot} = {rate:.0%}" + ("  <-- above 30%" if rate > 0.30 else ""))
    L += ["", "### Distributions", "", "- level: " + str(dict(Counter(i["cefr"] for i in allitems))),
          "- pattern: " + str(dict(Counter(i["pattern"] for i in allitems))),
          "- file: " + str(out_counts), "- workplace-tagged: " + str(sum(1 for i in allitems if "topics" in i)),
          "- answer position: " + str(dict(Counter(i["answer"] for i in allitems)))]
    L += ["", "### 30-item random sample (read by hand)", ""]
    for i in random.Random(11).sample(allitems, min(30, len(allitems))):
        L.append(f"- [{i['pattern']}/{i['cefr']}] {i['sentence']} | {i['options']} -> {i['options'][i['answer']]} | {i['explanation']}")
    rp.write_text(txt + "\n" + "\n".join(L) + "\n", encoding="utf-8")
    print(out_counts, dict(drop))


def schema_patterns():
    from lib import schema
    return schema.PATTERNS


def main(argv):
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    f = sub.add_parser("fetch")
    f.add_argument("--raw", default=str(ROOT / ".ingest/raw/coedit-grammar"))
    f.set_defaults(fn=cmd_fetch)
    e = sub.add_parser("extract")
    e.add_argument("--stage", default=str(ROOT / ".ingest/stage/coedit-grammar"))
    e.add_argument("--per-pattern", type=int, default=190, help="staged rows per pattern (1,500 final after ~25%% LLM rejects)")
    e.add_argument("--coedit-share", type=float, default=0.6)
    e.add_argument("--cap-answer", type=int, default=40, help="max rows per (pattern, answer token) for function-word patterns")
    e.add_argument("--cap-rule", type=int, default=40, help="max rows per rule id for the other patterns")
    e.set_defaults(fn=cmd_extract)
    m = sub.add_parser("emit")
    m.add_argument("--stage", default=str(ROOT / ".ingest/stage/coedit-grammar"))
    m.set_defaults(fn=cmd_emit)
    a = ap.parse_args(argv)
    a.fn(a)


if __name__ == "__main__":
    main(sys.argv[1:])
