"""P20: the /internal/skills bench fills and times what it says.

Outside `testpaths`, so run it by path, from server/:
    .venv/bin/python -m pytest benchmarks/matchmaking -q
"""

import pytest
from django.test import Client

from accounts.models import User
from matches.models import Match

import skills_endpoint_bench as bench


@pytest.mark.django_db
def test_fill_makes_the_accounts_and_battles_asked_for():
    rows = bench.fill(accounts=3, battles=4)

    assert rows == 3 * 4 * 2
    assert User.objects.count() == 3
    assert Match.objects.filter(exercise="push_up").count() == 12
    assert Match.objects.filter(exercise="squat").count() == 12


@pytest.mark.django_db
def test_fill_replaces_an_earlier_fill():
    bench.fill(accounts=5, battles=2)
    bench.fill(accounts=2, battles=1)

    assert User.objects.count() == 2
    assert Match.objects.count() == 4


@pytest.mark.django_db
def test_time_skills_reports_every_account_of_the_fill():
    bench.fill(accounts=4, battles=6)

    row = bench.time_skills(Client(), repeats=2)

    assert row["players"] == 4
    assert row["response_bytes"] > 0
    assert 0 < row["median_ms"] <= row["max_ms"]


@pytest.mark.django_db
def test_main_prints_one_row_per_size(capsys):
    rows = bench.main(["--sizes", "2,3", "--battles", "1", "--repeats", "1"])

    assert [r["accounts"] for r in rows] == [2, 3]
    assert [r["battle_rows"] for r in rows] == [4, 6]
    assert capsys.readouterr().out.count("\n") == 2


@pytest.mark.django_db
def test_a_database_on_disk_is_refused_before_anything_is_deleted(monkeypatch):
    bench.fill(accounts=2, battles=1)
    monkeypatch.setitem(bench.connection.settings_dict, "NAME", "/srv/gymrats/data/gymrats.db")

    assert bench.in_memory() is False
    with pytest.raises(RuntimeError, match="in-memory"):
        bench.fill(accounts=1, battles=1)
    with pytest.raises(SystemExit):
        bench.main(["--sizes", "1"])
    assert User.objects.count() == 2


def test_the_shell_cannot_point_the_bench_at_another_database():
    import os

    assert os.environ["DATABASE_URL"] == "sqlite://:memory:"
    assert os.environ["DJANGO_SETTINGS_MODULE"] == "gymrats.test_settings"
