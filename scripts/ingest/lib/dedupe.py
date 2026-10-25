"""Exact + near-duplicate detection against everything already in Content/ and anything added this run."""
from __future__ import annotations

import json
from pathlib import Path

from datasketch import MinHash, MinHashLSH

try:
    from lib.textnorm import normalize_for_hash, text_hash
except ImportError:  # pragma: no cover
    from textnorm import normalize_for_hash, text_hash  # type: ignore

NUM_PERM = 128
SHINGLE = 3


def item_text(item: dict) -> str:
    """The identifying text of an item or vocab row (what a learner would read)."""
    parts: list[str] = []
    for k in ("passage", "text", "prompt", "sentence", "context", "situation", "professor", "topic", "answer", "example"):
        v = item.get(k)
        if isinstance(v, str) and (k != "answer" or item.get("type") == "buildSentence"):
            parts.append(v.replace("{{", "").replace("}}", ""))
    s = item.get("script")
    if isinstance(s, str):
        parts.append(s)
    elif isinstance(s, list):
        parts += [x.get("line", "") for x in s]
    for q in item.get("questions") or []:
        parts.append(q if isinstance(q, str) else q.get("q", ""))
    if item.get("type") == "grammarMC":
        parts.append(" | ".join(item.get("options", [])))
    return "\n".join(parts)


def _minhash(text: str) -> MinHash | None:
    toks = normalize_for_hash(text).split()
    if len(toks) < SHINGLE:
        return None
    m = MinHash(num_perm=NUM_PERM)
    for i in range(len(toks) - SHINGLE + 1):
        m.update(" ".join(toks[i:i + SHINGLE]).encode())
    return m


class DedupeIndex:
    """check(text) -> reason or None; add(id, text) registers it. Short texts (<3 words) only get exact matching."""

    def __init__(self, threshold: float = 0.8) -> None:
        self.exact: dict[str, str] = {}
        self.lsh = MinHashLSH(threshold=threshold, num_perm=NUM_PERM)
        self.ids: set[str] = set()

    @classmethod
    def from_content(cls, content_root: Path, threshold: float = 0.8) -> "DedupeIndex":
        idx = cls(threshold)
        for sub in ("items", "vocab"):
            for f in sorted((content_root / sub).glob("*.json")):
                for row in json.loads(f.read_text(encoding="utf-8")):
                    idx.add(row["id"], item_text(row))
        return idx

    def check(self, text: str) -> str | None:
        h = text_hash(text)
        if h in self.exact:
            return f"exact duplicate of {self.exact[h]}"
        m = _minhash(text)
        if m is not None:
            hits = self.lsh.query(m)
            if hits:
                return f"near duplicate of {hits[0]}"
        return None

    def add(self, item_id: str, text: str) -> None:
        self.ids.add(item_id)
        self.exact.setdefault(text_hash(text), item_id)
        m = _minhash(text)
        if m is not None and item_id not in self.lsh.keys:
            self.lsh.insert(item_id, m)

    def check_and_add(self, item_id: str, text: str) -> str | None:
        reason = self.check(text)
        if reason is None:
            self.add(item_id, text)
        return reason
