"""completeWords generator (dataset-plan 3.5).

Rule (matches FORMAT.md and the 24 existing items' invariants):
  * 70-110 word window cut on sentence boundaries, text kept unchanged
  * the first sentence has no gaps
  * eligible tokens (sentence 2 on): purely alphabetic, >= 3 letters, not ALL-CAPS; numbers, hyphenated
    words and words with apostrophes are ineligible and do not count in the alternation
  * gap every second eligible token (2nd, 4th, ...) until there are exactly 10 gaps; the rest stays plain
  * visible part = first ceil(n/2) letters, hidden = the rest, written `vis{{hid}}`, punctuation outside
"""
from __future__ import annotations

import math
import re

try:
    from lib.textnorm import split_sentences
except ImportError:  # pragma: no cover
    from textnorm import split_sentences  # type: ignore

N_GAPS = 10
MIN_WORDS, MAX_WORDS = 70, 110
_TOKEN = re.compile(r"^(\W*)(.*?)(\W*)$", re.S)


def _eligible(core: str) -> bool:
    return core.isalpha() and core.isascii() and len(core) >= 3 and not core.isupper()


def make_gaps(sentences: list[str]) -> str | None:
    """Gap the passage made of `sentences`. Returns the passage or None if < 10 gaps fit."""
    if len(sentences) < 2:
        return None
    out = [sentences[0]]
    count = 0
    gaps = 0
    for sent in sentences[1:]:
        toks = sent.split(" ")
        for k, tok in enumerate(toks):
            if gaps >= N_GAPS:
                break
            pre, core, post = _TOKEN.match(tok).groups()
            if not _eligible(core):
                continue
            count += 1
            if count % 2 == 0:
                n = math.ceil(len(core) / 2)
                toks[k] = f"{pre}{core[:n]}{{{{{core[n:]}}}}}{post}"
                gaps += 1
        out.append(" ".join(toks))
    return " ".join(out) if gaps == N_GAPS else None


def windows(text: str):
    """Yield candidate sentence lists of 70-110 words from `text`, starting at each sentence."""
    sents = split_sentences(text)
    for i in range(len(sents)):
        n, cur = 0, []
        for s in sents[i:]:
            w = len(s.split())
            if n + w > MAX_WORDS:
                break
            cur.append(s)
            n += w
            if n >= MIN_WORDS:
                yield list(cur)
                break


def from_text(text: str) -> list[str]:
    """All valid gapped passages obtainable from `text` (one per starting sentence), in order."""
    res = []
    for w in windows(text):
        p = make_gaps(w)
        if p:
            res.append(p)
    return res


def passage_stats(passage: str) -> dict:
    """Invariants of an existing passage, parsed with the same logic as CompleteWordsParser."""
    gaps = []
    rest = passage
    while (o := rest.find("{{")) >= 0 and (c := rest.find("}}", o + 2)) >= 0:
        before = rest[:o]
        i = len(before)
        while i > 0 and before[i - 1].isalpha():
            i -= 1
        gaps.append((before[i:], rest[o + 2:c]))
        rest = rest[c + 2:]
    plain = passage.replace("{{", "").replace("}}", "")
    return {"gaps": len(gaps), "words": len(plain.split()),
            "half_ok": all(len(v) == math.ceil((len(v) + len(h)) / 2) for v, h in gaps),
            "min_len": min((len(v) + len(h) for v, h in gaps), default=0),
            "first_sentence_plain": "{{" not in (split_sentences(passage) or [""])[0]}
