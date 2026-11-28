"""P10 -> P20: how long POST /internal/skills takes as the accounts grow.

The battle server reads every account's latest battles from it at start-up
and every 5 minutes. This fills an in-memory SQLite database (the test
settings; production is SQLite too, on disk) with made-up accounts and
battles, then times the real view through Django's test client.

    cd server
    .venv/bin/python benchmarks/matchmaking/skills_endpoint_bench.py
    .venv/bin/python benchmarks/matchmaking/skills_endpoint_bench.py --sizes 100,1000 --battles 20
"""

import argparse
import json
import os
import random
import statistics
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

SERVER = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(SERVER))
# Forced, not defaulted: fill() deletes every account and battle, so this
# must never run on a database the shell happens to point at.
os.environ["DJANGO_SETTINGS_MODULE"] = "gymrats.test_settings"
os.environ["DATABASE_URL"] = "sqlite://:memory:"

import django  # noqa: E402

django.setup()

from django.conf import settings  # noqa: E402
from django.core.management import call_command  # noqa: E402
from django.db import connection  # noqa: E402
from django.test import Client  # noqa: E402

from accounts.models import User  # noqa: E402
from matches.models import Match  # noqa: E402

START = datetime(2026, 11, 1, tzinfo=timezone.utc)
EXERCISES = ("push_up", "squat")


def in_memory() -> bool:
    """Whether the default database is a throwaway in-memory SQLite one
    (`:memory:`, or pytest-django's shared `...?mode=memory` name)."""
    db = connection.settings_dict
    name = str(db["NAME"])
    return db["ENGINE"].endswith("sqlite3") and (
        name == ":memory:" or "mode=memory" in name
    )


def fill(accounts: int, battles: int, seed: int = 20) -> int:
    """Replaces the data with `accounts` accounts, each with `battles`
    time-up battles of each exercise. Returns the battle rows made.
    Refuses any database but an in-memory one."""
    if not in_memory():
        raise RuntimeError("skills bench runs only on an in-memory database")
    Match.objects.all().delete()
    User.objects.all().delete()
    rng = random.Random(seed)
    User.objects.bulk_create(
        User(login_id=f"bench{i}", nickname=f"Rat {i}", password="!")
        for i in range(accounts)
    )
    rows = [
        Match(
            user=user,
            client_id=f"{exercise}-{n}",
            exercise=exercise,
            opponent_name="AI",
            my_reps=max(0, int(rng.gauss(15, 5))),
            opponent_reps=10,
            played_at=START + timedelta(minutes=n),
            outcome="draw",
            reason="time_up",
        )
        for user in User.objects.all()
        for exercise in EXERCISES
        for n in range(battles)
    ]
    Match.objects.bulk_create(rows, batch_size=5000)
    return len(rows)


def time_skills(client: Client, repeats: int) -> dict:
    """Median and max of `repeats` calls, after one warm-up, in ms."""
    def call():
        started = time.perf_counter()
        response = client.post(
            "/internal/skills",
            {},
            content_type="application/json",
            HTTP_X_RESULTS_SECRET=settings.RESULTS_SECRET,
        )
        elapsed = (time.perf_counter() - started) * 1000
        assert response.status_code == 200, response.content
        return elapsed, len(response.content), len(response.json()["players"])

    call()
    runs = [call() for _ in range(repeats)]
    times = [r[0] for r in runs]
    return {
        "median_ms": round(statistics.median(times), 1),
        "max_ms": round(max(times), 1),
        "response_bytes": runs[-1][1],
        "players": runs[-1][2],
    }


def main(argv=None) -> list:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--sizes", default="100,1000,5000")
    parser.add_argument("--battles", type=int, default=20,
                        help="battles per account and exercise")
    parser.add_argument("--repeats", type=int, default=5)
    args = parser.parse_args(argv)
    if not in_memory():
        raise SystemExit("skills bench runs only on an in-memory database")
    call_command("migrate", verbosity=0)
    # pytest-django allows the test client's host; outside it, add it here.
    settings.ALLOWED_HOSTS = [*settings.ALLOWED_HOSTS, "testserver"]
    client = Client()
    rows = []
    for accounts in [int(s) for s in args.sizes.split(",")]:
        battles = fill(accounts, args.battles)
        row = {"accounts": accounts, "battle_rows": battles,
               **time_skills(client, args.repeats)}
        print(json.dumps(row))
        rows.append(row)
    return rows


if __name__ == "__main__":
    main()
