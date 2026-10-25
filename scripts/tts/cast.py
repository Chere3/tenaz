"""The voice-cast rule, mirrored EXACTLY from Sources/TenazCore/Speech/VoiceCast.swift.

Both sides are checked against Tests/TenazCoreTests/Fixtures/voice-cast-golden.json
(test_cast.py here, VoiceCastTests.swift there). After changing the rule on both sides,
regenerate the file with `uv run python cast.py --write-golden` and check that Swift agrees.
"""

import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GOLDEN = ROOT / "Tests" / "TenazCoreTests" / "Fixtures" / "voice-cast-golden.json"

MODEL = "kokoro-v1.0"
SPEED = "0.95"
FEMALE = ["af_heart", "bf_emma", "af_bella", "bf_isabella", "af_aoede", "af_sarah"]
MALE = ["am_michael", "bm_george", "am_fenrir", "bm_fable", "am_puck"]


def line(text, voice=None, speaker=None):
    return {"text": text, "voice": voice, "speaker": speaker}


def speaker_key(ln):
    # Swift `??` semantics: only a missing value falls through (an empty string does not).
    for k in ("speaker", "voice"):
        if ln.get(k) is not None:
            return ln[k]
    return "narrator"


def offset(lines):
    digest = hashlib.sha256("\n".join(ln["text"] for ln in lines).encode("utf-8")).digest()
    return int.from_bytes(digest[:8], "big")


def cast(lines):
    shift = offset(lines)
    assigned, used, counts = {}, set(), {"female": 0, "male": 0}
    for ln in lines:
        key = speaker_key(ln)
        if key in assigned:
            continue
        gender = "male" if ln.get("voice") == "male" else "female"
        pool, other = (MALE, FEMALE) if gender == "male" else (FEMALE, MALE)
        start = (shift % len(pool) + counts[gender]) % len(pool)
        other_start = shift % len(other)
        pick = next((v for v in pool[start:] + pool[:start] if v not in used), None)
        if pick is None:
            pick = next((v for v in other[other_start:] + other[:other_start] if v not in used), pool[start])
        counts[gender] += 1
        used.add(pick)
        assigned[key] = pick
    return assigned


def voices(lines):
    assigned = cast(lines)
    return [assigned[speaker_key(ln)] for ln in lines]


def cache_key(voice, text):
    return hashlib.sha256(f"{MODEL}|{voice}|{SPEED}|{text}".encode("utf-8")).hexdigest()


def lang(voice):
    return "en-gb" if voice.startswith("b") else "en-us"


def spoken_groups(item):
    """The line lists the app hands to speak() for one item, one list per call.
    Mirrors Tenaz/Features/Exam/Runner/ExamScript.swift `lines(for:question:)`."""
    t = item.get("type")
    if t == "listenResponse":
        return [[line(item["prompt"], item.get("voice"))]] if item.get("prompt") else []
    if t in ("listenConversation", "listenAnnouncement", "listenTalk"):
        script = item.get("script")
        if isinstance(script, list):
            return [[line(s["line"], s.get("voice"), s.get("speaker")) for s in script]] if script else []
        if isinstance(script, str):
            return [[line(script, item.get("voice"))]]
        return []
    if t == "listenRepeat":
        return [[line(item["sentence"], item.get("voice"))]] if item.get("sentence") else []
    if t == "interview":
        return [[line(q, "female")] for q in item.get("questions") or []]
    return []


GOLDEN_CASES = [
    ("monologue female", [line("Please remember that the office closes early on Friday.", "female")]),
    ("monologue male", [line("Our company's first priority is meeting our customers' needs.", "male")]),
    ("no voice is the narrator, female pool", [line("Tell me about a project you are proud of.")]),
    ("interview question", [line("What do you usually do on a weekend?", "female")]),
    ("two speakers, mixed gender", [
        line("Hi, I'd like to book a table for two tonight.", "female", "A"),
        line("Sure. What time would you like?", "male", "B"),
        line("Around eight, if possible.", "female", "A"),
        line("Eight works. Can I have your name?", "male", "B"),
    ]),
    ("two speakers, both female", [
        line("Did you send the report to Marta?", "female", "A"),
        line("Not yet, I'm still checking the numbers.", "female", "B"),
        line("Okay, let me know when it's done.", "female", "A"),
    ]),
    ("two speakers, both male", [
        line("Is the train to Leeds on time?", "male", "A"),
        line("It's running about ten minutes late.", "male", "B"),
    ]),
    ("three speakers", [
        line("Welcome, everyone.", "female", "A"),
        line("Thanks for having us.", "male", "B"),
        line("Shall we start with the budget?", "female", "C"),
        line("Good idea.", "male", "B"),
    ]),
    ("more female speakers than the female pool", [
        line(f"Speaker {s} says hello.", "female", s) for s in "ABCDEFGH"
    ]),
    ("unicode: curly quotes, accents, dash", [
        line("It’s the café on Main Street — the one with the “blue” door.", "female", "A"),
        line("Oh, the one near Zoë’s place? I know it.", "male", "B"),
    ]),
]


def golden():
    cases = []
    for name, lines in GOLDEN_CASES:
        vs = voices(lines)
        cases.append({
            "name": name,
            "lines": lines,
            "offset": str(offset(lines)),
            "voices": vs,
            "keys": [cache_key(v, ln["text"]) for v, ln in zip(vs, lines)],
        })
    return {"model": MODEL, "speed": SPEED, "female": FEMALE, "male": MALE, "cases": cases}


if __name__ == "__main__":
    if sys.argv[1:] == ["--write-golden"]:
        GOLDEN.write_text(json.dumps(golden(), indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"wrote {GOLDEN}")
    else:
        print("usage: uv run python cast.py --write-golden")
