# /// script
# dependencies = ["fsrs==6.3.2"]
# ///
"""Golden fixtures for Tenaz's FSRS port, generated from py-fsrs 6.3.2 (fuzz off).

Run from the repo root:
    uv run --with 'fsrs==6.3.2' scripts/fsrs-fixtures.py

Writes Tests/TenazCoreTests/Fixtures/fsrs_with_steps.json and fsrs_long_term.json.
Output is deterministic: running it again must give no diff.
"""

import json
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path

from fsrs import Card, Rating, Scheduler


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Tests" / "TenazCoreTests" / "Fixtures"
START = datetime(2026, 1, 1, 12, 0, tzinfo=timezone.utc)
STATE = {1: "learning", 2: "review", 3: "relearning"}


def scheduler(retention=0.9, learning=(60, 600), relearning=(600,)):
    return Scheduler(
        desired_retention=retention,
        learning_steps=[timedelta(seconds=s) for s in learning],
        relearning_steps=[timedelta(seconds=s) for s in relearning],
        enable_fuzzing=False,
    )


def run(name, sched, plan, retention, learning, relearning):
    """`plan` is a list of (rating, when): when is "due", ("due", seconds) or ("after", seconds)."""
    card = Card(card_id=1, due=START)
    last = START
    reviews = []
    for rating, when in plan:
        if when == "due":
            at = card.due
        elif when[0] == "due":
            at = card.due + timedelta(seconds=when[1])
        else:
            at = last + timedelta(seconds=when[1])
        card, _ = sched.review_card(card, Rating(rating), review_datetime=at)
        last = at
        reviews.append({
            "rating": rating,
            "at": int(at.timestamp()),
            "state": STATE[int(card.state)],
            "step": card.step,
            "stability": card.stability,
            "difficulty": card.difficulty,
            "due": int(card.due.timestamp()),
        })
    return {
        "name": name,
        "desiredRetention": retention,
        "learningSteps": list(learning),
        "relearningSteps": list(relearning),
        "start": int(START.timestamp()),
        "reviews": reviews,
    }


def sequence(name, plan, retention=0.9, learning=(60, 600), relearning=(600,)):
    return run(name, scheduler(retention, learning, relearning), plan, retention, learning, relearning)


def random_plan(seed, n):
    rng = random.Random(seed)
    plan = []
    for _ in range(n):
        rating = rng.choice([1, 2, 3, 3, 3, 4])
        kind = rng.random()
        if kind < 0.5:
            plan.append((rating, "due"))
        elif kind < 0.8:
            plan.append((rating, ("due", rng.randint(1, 60) * 3600)))
        else:
            plan.append((rating, ("after", rng.randint(1, 600) * 60)))
    return plan


def main():
    sequences = [
        sequence("newAgain", [(1, "due")]),
        sequence("newHard", [(2, "due")]),
        sequence("newGood", [(3, "due")]),
        sequence("newEasy", [(4, "due")]),
        sequence("learnGraduateLapse", [
            (3, "due"), (3, "due"), (3, "due"), (3, "due"), (1, "due"),
            (2, "due"), (3, "due"), (3, ("due", 5 * 3600)), (4, ("due", 30 * 3600)), (2, "due"),
        ]),
        sequence("againLoop", [(1, "due"), (1, "due"), (2, "due"), (3, "due"), (2, "due"), (3, "due"), (3, "due")]),
        sequence("earlyAndLate", [
            (4, "due"), (3, ("after", 3 * 3600)), (2, ("after", 2 * 86400)), (1, ("due", 7 * 86400 + 3600)),
            (1, "due"), (3, "due"), (3, ("after", 20 * 3600)),
        ]),
        # A lapse long after due on a young card: the 6.3.2 short-term cap on forget stability binds.
        sequence("lateLapse", [(1, "due"), (3, "due"), (3, "due"), (1, ("due", 1000 * 86400)), (3, "due"), (3, "due")]),
        sequence("mustKnow093", [(3, "due"), (3, "due"), (3, "due"), (2, "due"), (1, "due"), (3, "due"), (3, "due")], retention=0.93),
        sequence("random7", random_plan(7, 30)),
        sequence("random11", random_plan(11, 30)),
        sequence("random23", random_plan(23, 30), retention=0.93),
    ]
    s = scheduler()
    round_cases = [[x, s._next_interval(stability=x)] for x in [0.5, 1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 10.5, 12.5]]
    with_steps = {"generator": "py-fsrs 6.3.2, enable_fuzzing=False", "sequences": sequences, "roundCases": round_cases}

    # The fluo table (no learning steps): Good, Hard, Good, Again, Good, Easy, each on its due date.
    long_term = {
        "generator": "py-fsrs 6.3.2, learning_steps=(), relearning_steps=(), enable_fuzzing=False",
        "sequences": [sequence("fluoTable", [(3, "due"), (2, "due"), (3, "due"), (1, "due"), (3, "due"), (4, "due")], learning=(), relearning=())],
    }

    OUT.mkdir(parents=True, exist_ok=True)
    for name, data in [("fsrs_with_steps.json", with_steps), ("fsrs_long_term.json", long_term)]:
        (OUT / name).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
        print(f"wrote {OUT / name}")


if __name__ == "__main__":
    main()
