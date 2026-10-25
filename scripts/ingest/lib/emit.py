"""Write a Content file, enforce schema + global id uniqueness, update Content/licenses.json."""
from __future__ import annotations

import json
from datetime import date
from pathlib import Path

try:
    from lib import licenses, schema
except ImportError:  # pragma: no cover
    import licenses, schema  # type: ignore


class EmitError(Exception):
    pass


def existing_ids(content_root: Path, exclude_file: Path | None = None) -> dict[str, str]:
    """id -> relative file for every row in Content/items and Content/vocab (except `exclude_file`, being rewritten)."""
    ids: dict[str, str] = {}
    for sub in ("items", "vocab"):
        for f in sorted((content_root / sub).glob("*.json")):
            if exclude_file and f.resolve() == exclude_file.resolve():
                continue
            for r in json.loads(f.read_text(encoding="utf-8")):
                ids[r["id"]] = f"{sub}/{f.name}"
    return ids


def emit(content_root: Path, kind: str, filename: str, rows: list[dict], *, source: str, url: str, license: str,
         tier: str, attribution: str, retrieved: str | None = None) -> dict:
    """kind is 'items' or 'vocab'. Rows failing schema or colliding on id raise EmitError and nothing is written.

    Rewrites the file wholesale (so reruns are idempotent) and upserts the licenses.json entry.
    `.nc.json` filenames are required for tier nc/unclear.
    """
    if kind not in ("items", "vocab"):
        raise EmitError("kind must be 'items' or 'vocab'")
    if tier in ("nc", "unclear") and not filename.endswith(".nc.json"):
        raise EmitError("nc/unclear tiers must use a *.nc.json filename")
    target = content_root / kind / filename
    check = schema.problems_item if kind == "items" else schema.problems_vocab
    errors: list[str] = []
    ids = existing_ids(content_root, exclude_file=target)
    seen: set[str] = set()
    for r in rows:
        rid = r.get("id", "?")
        errors += [f"{rid}: {p}" for p in check(r)]
        if rid in ids:
            errors.append(f"{rid}: id already used in {ids[rid]}")
        if rid in seen:
            errors.append(f"{rid}: duplicate id within this emit")
        seen.add(rid)
    if errors:
        raise EmitError("\n".join(errors[:50]) + (f"\n... {len(errors)} problems" if len(errors) > 50 else ""))
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(rows, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    origin = {"verbatim": 0, "adapted": 0, "generated": 0}
    for r in rows:
        if r.get("origin") in origin:
            origin[r["origin"]] += 1
    entry = licenses.make_entry(f"{kind}/{filename}", source=source, url=url, license=license, tier=tier,
                                attribution=attribution, retrieved=retrieved or date.today().isoformat(),
                                items=len(rows), origin=origin)
    licenses.upsert(content_root, entry)
    return entry
