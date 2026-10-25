"""Checks cast.py against the golden vectors the Swift tests also read.
Run: cd scripts/tts && uv run python -m unittest -v"""

import json
import unittest

import cast


class GoldenVectors(unittest.TestCase):
    def setUp(self):
        self.golden = json.loads(cast.GOLDEN.read_text(encoding="utf-8"))

    def test_constants(self):
        self.assertEqual(self.golden["model"], cast.MODEL)
        self.assertEqual(self.golden["speed"], cast.SPEED)
        self.assertEqual(self.golden["female"], cast.FEMALE)
        self.assertEqual(self.golden["male"], cast.MALE)

    def test_cases(self):
        for case in self.golden["cases"]:
            with self.subTest(case["name"]):
                lines = case["lines"]
                self.assertEqual(str(cast.offset(lines)), case["offset"])
                vs = cast.voices(lines)
                self.assertEqual(vs, case["voices"])
                self.assertEqual([cast.cache_key(v, ln["text"]) for v, ln in zip(vs, lines)], case["keys"])

    def test_speakers_never_share_a_voice(self):
        for case in self.golden["cases"]:
            assigned = cast.cast(case["lines"])
            self.assertEqual(len(set(assigned.values())), len(assigned), case["name"])

    def test_spoken_groups_mirror_exam_script(self):
        convo = {"type": "listenConversation", "script": [
            {"speaker": "A", "voice": "female", "line": "Hi."}, {"speaker": "B", "voice": "male", "line": "Hello."}]}
        self.assertEqual(cast.spoken_groups(convo), [[cast.line("Hi.", "female", "A"), cast.line("Hello.", "male", "B")]])
        talk = {"type": "listenTalk", "voice": "male", "script": "Today we look at tides."}
        self.assertEqual(cast.spoken_groups(talk), [[cast.line("Today we look at tides.", "male")]])
        interview = {"type": "interview", "questions": ["Q1?", "Q2?"]}
        self.assertEqual(cast.spoken_groups(interview), [[cast.line("Q1?", "female")], [cast.line("Q2?", "female")]])
        self.assertEqual(cast.spoken_groups({"type": "grammarMC", "sentence": "x"}), [])


if __name__ == "__main__":
    unittest.main()
