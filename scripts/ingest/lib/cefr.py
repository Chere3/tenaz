"""Lexical CEFR estimate (placeholder until the CEFR-J/Octanove/NGSL lookups are fetched).

Signals, no external lists beyond the `wordfreq` package (Zipf frequency, 1-8 scale):
  * rare share: fraction of alphabetic tokens with Zipf < 3.5
  * very-rare share: Zipf < 2.8
  * mean sentence length in words
score = 8*rare + 12*very_rare + 0.06*mean_len; thresholds in THRESHOLDS were grid-fitted on the 109
existing Content/ texts of >=30 words: 46% exact, 64% within one step (the plan wants >=70%, so treat this as a
weak prior only; replace with CEFR-J/Octanove/NGSL lookups, plan 3.7, and recalibrate). Output is one of B1, B1+, B2, B2+, C1 (A2 and C2 are dropped per
the plan). `estimate(text, prior=None)`: a source prior (e.g. 'B1' for OneStopEnglish Ele) is returned as-is
when the lexical estimate is within one step; otherwise the lexical value is returned and `disagrees()` is
True so the caller can queue an LLM tiebreak.
"""
from __future__ import annotations

import re
from wordfreq import zipf_frequency

LEVELS = ["B1", "B1+", "B2", "B2+", "C1"]
# Upper bounds of the score for B1, B1+, B2, B2+ (above the last -> C1)
THRESHOLDS = [0.6, 0.7, 1.5, 1.65]
_WORD = re.compile(r"[A-Za-z]+")


def features(text: str) -> dict:
    toks = [t.lower() for t in _WORD.findall(text)]
    if not toks:
        return {"rare": 0.0, "very_rare": 0.0, "mean_len": 0.0}
    z = [zipf_frequency(t, "en") for t in toks]
    sents = [s for s in re.split(r"[.!?]+", text) if s.strip()]
    return {"rare": sum(x < 3.5 for x in z) / len(z), "very_rare": sum(x < 2.8 for x in z) / len(z),
            "mean_len": len(toks) / max(1, len(sents))}


def score(text: str) -> float:
    f = features(text)
    return 8 * f["rare"] + 12 * f["very_rare"] + 0.06 * f["mean_len"]


def lexical_level(text: str) -> str:
    s = score(text)
    for lvl, ub in zip(LEVELS, THRESHOLDS):
        if s <= ub:
            return lvl
    return "C1"


def _idx(l: str) -> int:
    return LEVELS.index(l) if l in LEVELS else (0 if l < "B1" else len(LEVELS) - 1)


def disagrees(a: str, b: str) -> bool:
    return abs(_idx(a) - _idx(b)) > 1


def estimate(text: str, prior: str | None = None) -> str:
    lex = lexical_level(text)
    if prior and not disagrees(prior, lex):
        return prior
    return lex
