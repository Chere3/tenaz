"""Workplace relevance score (0..1): share of tokens in a supply-chain / office lexicon.

A BSL (Business Service List) file can be merged in later via `load_extra(path)`; until then this
built-in lexicon is the whole signal. Use `score(text)`; `>= 0.04` is already clearly workplace text.
"""
from __future__ import annotations

import re
from pathlib import Path

LEXICON = set("""
supplier suppliers shipment shipments lead time forecast forecasts inventory batch batches deviation deviations
purchase order orders stakeholder stakeholders deadline deadlines escalate escalation otif invoice invoices
procurement logistics warehouse stock backlog delivery deliveries vendor vendors contract contracts budget
meeting meetings agenda minutes schedule reschedule client clients customer customers manager team teammate
colleague colleagues report reports proposal deliverable deliverables milestone milestones sprint project
projects update follow-up follow up approval approve approved request requests priority priorities quarter
revenue cost costs invoice payment payments quality audit compliance issue issues risk risks delay delays
capacity demand supply planning planner planning workflow process processes feedback review reviews
presentation slides spreadsheet email emails attachment deadline overtime shift roster hire hiring onboarding
""".split())
_WORD = re.compile(r"[a-z][a-z'-]*")


def load_extra(path: Path) -> None:
    LEXICON.update(w.strip().lower() for w in path.read_text(encoding="utf-8").split() if w.strip())


def score(text: str) -> float:
    toks = _WORD.findall(text.lower())
    if not toks:
        return 0.0
    hits = sum(1 for t in toks if t in LEXICON)
    return min(1.0, hits / len(toks) * 5)  # ~20% hit rate saturates at 1.0


def hits(text: str) -> list[str]:
    return sorted({t for t in _WORD.findall(text.lower()) if t in LEXICON})
