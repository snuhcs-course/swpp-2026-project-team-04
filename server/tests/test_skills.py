"""P10: the battle server reads every account's latest battles for the
skill estimates (POST /internal/skills)."""

from datetime import datetime, timedelta, timezone

import pytest
from django.test import override_settings

from accounts.models import User
from matches.models import Match, MatchFeedback, OnlineBattle

from .conftest import sign_up
from .test_results import SECRET, internal

START = datetime(2026, 11, 27, 12, 0, tzinfo=timezone.utc)


def play(user, reps, exercise="push_up", minutes=0, client_id=None, reason="time_up"):
    return Match.objects.create(
        reason=reason,
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

    assert response.status_code == 422
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


def played_for(user, match, ms):
    """The form report of [match], saying it lasted [ms]."""
    MatchFeedback.objects.create(
        user=user,
        client_id=match.client_id,
        summary={},
        report={"version": 1, "roundMs": ms, "reps": [], "samples": [], "poses": []},
    )


def test_skills_scales_a_ko_battle_to_a_full_round(client, accounts):
    a, _ = accounts
    played_for(a, play(a, 12, minutes=2, reason="ko"), 20_000)
    play(a, 10, minutes=1)

    players = players_of(internal(client, "skills", {}))

    # 12 reps in 20 s is 18 in 30 s.
    assert players[str(a.id)]["recent"]["push_up"] == [18.0, 10]


def test_skills_takes_an_online_ko_length_from_the_battle(client, accounts):
    a, b = accounts
    play(a, 8, client_id="result-ko-1", reason="ko")
    play(b, 2, client_id="result-ko-1", reason="ko")
    OnlineBattle.objects.create(
        match_id="match-ko-1",
        result_id="result-ko-1",
        status=OnlineBattle.FINISHED,
        started_at=START,
        ended_at=START + timedelta(seconds=12),
    )

    players = players_of(internal(client, "skills", {}))

    assert players[str(a.id)]["recent"]["push_up"] == [20.0]
    assert players[str(b.id)]["recent"]["push_up"] == [5.0]


def test_skills_leaves_out_a_ko_under_ten_seconds(client, accounts):
    a, _ = accounts
    played_for(a, play(a, 6, minutes=2, reason="ko"), 9_999)
    played_for(a, play(a, 7, minutes=1, reason="ko"), 10_000)

    players = players_of(internal(client, "skills", {}))

    assert players[str(a.id)]["recent"]["push_up"] == [21.0]


def test_skills_leaves_out_a_ko_of_unknown_length(client, accounts):
    a, b = accounts
    play(a, 12, minutes=2, reason="ko")
    # Another account's report under the same client id does not count.
    played_for(b, play(b, 3, client_id="ko-shared", reason="time_up"), 20_000)
    play(a, 12, client_id="ko-shared", minutes=1, reason="ko")

    players = players_of(internal(client, "skills", {}))

    assert str(a.id) not in players


def test_skills_leaves_out_battles_a_player_left(client, accounts):
    a, _ = accounts
    play(a, 1, minutes=3, reason="forfeit")
    play(a, 2, minutes=2, reason="disconnect_timeout")
    play(a, 9, minutes=1)

    players = players_of(internal(client, "skills", {}))

    assert players[str(a.id)]["recent"]["push_up"] == [9]


def test_skills_fills_the_five_from_battles_that_count(client, accounts):
    a, _ = accounts
    for minute in range(5):
        play(a, 10 + minute, minutes=10 + minute)
    play(a, 1, minutes=20, reason="forfeit")
    play(a, 2, minutes=21, reason="ko")  # unknown length

    players = players_of(internal(client, "skills", {}))

    assert players[str(a.id)]["recent"]["push_up"] == [14, 13, 12, 11, 10]


def test_skills_ignores_a_report_without_a_usable_length(client, accounts):
    a, _ = accounts
    match = play(a, 12, reason="ko")
    MatchFeedback.objects.create(
        user=a,
        client_id=match.client_id,
        summary={},
        report={"version": 1, "roundMs": "20000", "reps": [], "samples": [], "poses": []},
    )

    assert players_of(internal(client, "skills", {})) == {}
