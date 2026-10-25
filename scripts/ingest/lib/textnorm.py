"""Text cleanup helpers shared by converters."""
from __future__ import annotations

import hashlib
import re
import unicodedata

_SMART = {"‘": "'", "’": "'", "“": '"', "”": '"', "–": "-", "—": " - ", " ": " ", "…": "..."}


def fix_unicode(s: str) -> str:
    s = unicodedata.normalize("NFC", s)
    for a, b in _SMART.items():
        s = s.replace(a, b)
    return s


def detokenize(s: str) -> str:
    """PTB-style tokenized text -> normal text: "you 've gone , did n't he ?" -> "you've gone, didn't he?"."""
    s = fix_unicode(s)
    s = s.replace("-LRB-", "(").replace("-RRB-", ")").replace("``", '"').replace("''", '"')
    s = re.sub(r"\s+(n't|'s|'re|'ve|'ll|'d|'m)\b", r"\1", s, flags=re.I)
    s = re.sub(r"\bcan not\b", "cannot", s)
    s = re.sub(r"\s+([,.;:!?%)\]])", r"\1", s)
    s = re.sub(r"([(\[$])\s+", r"\1", s)
    s = re.sub(r'"\s+([^"]*?)\s+"', r'"\1"', s)
    return re.sub(r"\s+", " ", s).strip()


def recapitalize(s: str) -> str:
    """Capitalize the first letter of the text and of each sentence (after . ! ? and a space)."""
    s = s.strip()
    s = re.sub(r"(^|[.!?]\s+)([a-z])", lambda m: m.group(1) + m.group(2).upper(), s)
    return re.sub(r"\bi\b(?=(\s|'|,|\.|$))", "I", s)


def clean_sentence(s: str) -> str:
    return recapitalize(detokenize(s))


def normalize_for_hash(s: str) -> str:
    """Lowercase, strip accents/punctuation, collapse whitespace. Used for exact and MinHash dedupe."""
    s = unicodedata.normalize("NFKD", fix_unicode(s).lower())
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = re.sub(r"[^a-z0-9\s]", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def text_hash(s: str) -> str:
    return hashlib.sha256(normalize_for_hash(s).encode()).hexdigest()


def words(s: str) -> list[str]:
    return s.split()


def word_count(s: str) -> int:
    return len(s.split())


def split_sentences(s: str) -> list[str]:
    return [x for x in re.split(r"(?<=[.!?])[\"')\]]*\s+(?=[A-Z\"'(\[])", s.strip()) if x]
