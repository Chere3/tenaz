"""Stable ids: <typeprefix>-<source>-<stable source key>. Never derive from a row index."""
from __future__ import annotations

import hashlib
import re

PREFIX = {
    "readDaily": "rd", "readAcademic": "ra", "completeWords": "cw", "listenResponse": "lr",
    "listenConversation": "lc", "listenAnnouncement": "la", "listenTalk": "lt", "buildSentence": "bs",
    "grammarMC": "gm", "listenRepeat": "lrep", "interview": "iv", "writeEmail": "we",
    "writeDiscussion": "wd", "lifeParagraph": "lp",
}


def slug(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def sha8(s: str) -> str:
    return hashlib.sha256(s.encode()).hexdigest()[:8]


def item_id(item_type: str, source: str, key: str) -> str:
    """e.g. item_id('readDaily', 'cosmos', 'train-12345') -> 'rd-cosmos-train-12345'."""
    return f"{PREFIX[item_type]}-{slug(source)}-{slug(key)}"


def hashed_id(item_type: str, source: str, content: str) -> str:
    """For sources without stable keys: id from a hash of the (normalized) content."""
    return f"{PREFIX[item_type]}-{slug(source)}-{sha8(content)}"


def vocab_id(headword: str, pos: str) -> str:
    return f"v-{slug(headword)}-{slug(pos)}"
