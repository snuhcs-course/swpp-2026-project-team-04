"""P10: the battle server reads every account's latest battles for the
skill estimates (POST /internal/skills)."""

from datetime import datetime, timedelta, timezone

import pytest
from django.test import override_settings

from accounts.models import User
from matches.models import Match

from .conftest import sign_up
from .test_results import SECRET, internal

START = datetime(2026, 11, 27, 12, 0, tzinfo=timezone.utc)


def play(user, reps, exercise="push_up", minutes=0, client_id=None):
    return Match.objects.create(
        user=user,
        client_id=client_id or f"{exercise}-{minutes}-{reps}",
        exercise=exercise,
        opponent_name="AI 봇 · 고수",
        my_reps=reps,
        opponent_reps=10,
        played_at=START + timedelta(minutes=minutes),
        outcome="draw",
    )


@pytest.fixture
def accounts(client):
    a = sign_up(client, login_id="woohyun", nickname="우현")
    b = sign_up(client, login_id="jinyoung", nickname="진영")
    return User.objects.get(id=a["user"]["id"]), User.objects.get(id=b["user"]["id"])


def players_of(response):
    assert response.status_code == 200, response.content
    return {p["player_id"]: p for p in response.json()["players"]}


def test_skills_lists_the_latest_five_battles_per_exercise_newest_first(
    client, accounts
):
    a, _ = accounts
    for minute, reps in enumerate([3, 4, 5, 6, 7, 8, 9]):
        play(a, reps, minutes=minute)
    play(a, 20, exercise="squat", minutes=1)
    play(a, 21, exercise="squat", minutes=2)

    players = players_of(internal(client, "skills", {}))

    assert players[str(a.id)] == {
        "player_id": str(a.id),
        "display_name": "우현",
        "recent": {"push_up": [9, 8, 7, 6, 5], "squat": [21, 20]},
    }


def test_skills_leaves_out_accounts_with_no_battle(client, accounts):
    a, b = accounts
    play(a, 10)

    players = players_of(internal(client, "skills", {}))

    assert list(players) == [str(a.id)]
    assert str(b.id) not in players


def test_skills_breaks_a_tie_in_time_by_the_newer_row(client, accounts):
    a, _ = accounts
    play(a, 4, client_id="older")
    play(a, 9, client_id="newer")

    players = players_of(internal(client, "skills", {"limit": 1}))

    assert players[str(a.id)]["recent"] == {"push_up": [9]}


def test_skills_takes_another_limit(client, accounts):
    a, _ = accounts
    for minute in range(4):
        play(a, minute, minutes=minute)

    players = players_of(internal(client, "skills", {"limit": 2}))

    assert players[str(a.id)]["recent"]["push_up"] == [3, 2]


@pytest.mark.parametrize("limit", [0, 11, "5", True, 2.5])
def test_skills_refuses_a_bad_limit(client, accounts, limit):
    response = internal(client, "skills", {"limit": limit})

    assert response.status_code == 400
    assert "limit" in response.json()


def test_skills_sends_only_nicknames_and_reps(client, accounts):
    a, _ = accounts
    play(a, 10)

    player = internal(client, "skills", {}).json()["players"][0]

    assert set(player) == {"player_id", "display_name", "recent"}


def test_skills_needs_the_secret(client, accounts):
    assert internal(client, "skills", {}, secret="wrong" * 10).status_code == 403


def test_skills_is_closed_through_the_proxy(client, accounts):
    response = internal(client, "skills", {}, HTTP_X_FORWARDED_FOR="203.0.113.5")

    assert response.status_code == 403


def test_skills_is_closed_from_another_host(client, accounts):
    response = internal(client, "skills", {}, REMOTE_ADDR="203.0.113.5")

    assert response.status_code == 403


@override_settings(RESULTS_SECRET="")
def test_skills_is_closed_without_a_configured_secret(client, accounts):
    assert internal(client, "skills", {}, secret="").status_code == 403


def test_skills_answers_an_empty_list_with_no_battles(client, accounts):
    assert internal(client, "skills", {}).json() == {"players": []}
