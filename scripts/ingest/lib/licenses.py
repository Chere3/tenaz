"""Content/licenses.json: one manifest entry per emitted file."""
from __future__ import annotations

import json
from pathlib import Path


def load(content_root: Path) -> list[dict]:
    p = content_root / "licenses.json"
    return json.loads(p.read_text(encoding="utf-8")) if p.exists() else []


def upsert(content_root: Path, entry: dict) -> None:
    """Insert or replace the entry whose `file` matches. Keeps the manifest sorted by file."""
    entries = [e for e in load(content_root) if e["file"] != entry["file"]]
    entries.append(entry)
    entries.sort(key=lambda e: e["file"])
    (content_root / "licenses.json").write_text(json.dumps(entries, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def remove(content_root: Path, file: str) -> None:
    entries = [e for e in load(content_root) if e["file"] != file]
    (content_root / "licenses.json").write_text(json.dumps(entries, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def make_entry(file: str, *, source: str, url: str, license: str, tier: str, attribution: str,
               retrieved: str, items: int, origin: dict[str, int] | None = None) -> dict:
    return {"file": file, "source": source, "url": url, "license": license, "tier": tier,
            "attribution": attribution, "retrieved": retrieved, "items": items,
            "origin": {"verbatim": 0, "adapted": 0, "generated": 0, **(origin or {})}}
