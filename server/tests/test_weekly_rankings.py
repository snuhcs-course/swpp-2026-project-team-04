"""P11: weekly rankings from online battles, global and among friends."""

from datetime import datetime, timedelta, timezone as dt_timezone
from types import SimpleNamespace
from zoneinfo import ZoneInfo

import pytest

from accounts.models import FriendRequest, User
from matches import rankings
from matches.models import Match, OnlineBattle

from .conftest import auth, match_body, sign_up
from .test_results import internal

KST = ZoneInfo("Asia/Seoul")
# Wednesday of the week that starts on Monday 2026-11-23 00:00 KST.
NOW = datetime(2026, 11, 25, 12, 0, tzinfo=KST)
MONDAY = datetime(2026, 11, 23, tzinfo=KST)


@pytest.fixture(autouse=True)
def frozen_now(monkeypatch):
    monkeypatch.setattr(rankings, "timezone", SimpleNamespace(now=lambda: NOW))


def account(client, login_id, nickname):
    body = sign_up(client, login_id=login_id, nickname=nickname)
    return SimpleNamespace(
        id=body["user"]["id"], name=nickname, headers=auth(body["token"])
    )


@pytest.fixture
def people(client):
    return [
        account(client, "woohyun", "우현"),
        account(client, "jinyoung", "진영"),
        account(client, "sangwoo", "상우"),
        account(client, "hyunwoo", "현우"),
    ]


_ids = iter(range(1, 10**6))


def battle(a, b, *, outcomes=("win", "loss"), reason="time_up", at=NOW, kind=None):
    """One online battle as the battle server reports it: a row per player."""
    n = next(_ids)
    body = {
        "match_id": f"match-{n:04d}",
        "result_id": f"result-{n:04d}",
        "reason": reason,
        **({"kind": kind} if kind else {}),
        "ended_at_ms": int(at.timestamp() * 1000),
        "players": [
            {
                "player_id": str(p.id),
                "display_name": p.name,
                "valid_reps": 10,
                "invalid_reps": 0,
                "outcome": o,
            }
            for p, o in ((a, outcomes[0]), (b, outcomes[1]))
        ],
    }
    return body


def store(client, body):
    response = internal(client, "results", body)
    assert response.status_code == 201, response.content
    return body


def weekly(client, me, scope=None):
    query = f"?scope={scope}" if scope else ""
    response = client.get(f"/matches/rankings/weekly{query}", **me.headers)
    assert response.status_code == 200, response.content
    return response.json()


def points_of(body):
    return {row["nickname"]: row["points"] for row in body["entries"]}


@pytest.mark.parametrize(
    "outcome, reason, expected",
    [
        ("win", "ko", 10),
        ("win", "time_up", 5),
        ("win", "forfeit", 5),
        ("win", "disconnect_timeout", 5),
        ("draw", "time_up", 3),
        ("loss", "time_up", 1),
        ("loss", "ko", 1),
        ("loss", "forfeit", 0),
        ("loss", "disconnect_timeout", 0),
    ],
)
def test_points_follow_the_outcome_and_how_the_battle_ended(outcome, reason, expected):
    assert rankings.points(outcome, reason) == expected


@pytest.mark.parametrize(
    "now, start",
    [
        (datetime(2026, 11, 23, 0, 0, tzinfo=KST), MONDAY),
        (datetime(2026, 11, 29, 23, 59, 59, tzinfo=KST), MONDAY),
        # Sunday 15:00 UTC is already Monday in Korea.
        (datetime(2026, 11, 22, 15, 0, tzinfo=dt_timezone.utc), MONDAY),
        (datetime(2026, 11, 22, 14, 59, 59, tzinfo=dt_timezone.utc), MONDAY - timedelta(days=7)),
    ],
)
def test_a_week_runs_from_monday_midnight_in_korea(now, start):
    assert rankings.week_bounds(now) == (start, start + timedelta(days=7))


def test_a_ko_win_a_win_a_draw_and_a_loss_add_up(client, people):
    a, b, *_ = people
    store(client, battle(a, b, reason="ko"))
    store(client, battle(a, b))
    store(client, battle(a, b, outcomes=("draw", "draw")))
    store(client, battle(b, a))

    body = weekly(client, a)

    assert points_of(body) == {"우현": 10 + 5 + 3 + 1, "진영": 1 + 1 + 3 + 5}
    me = body["me"]
    assert (me["rank"], me["battles"], me["wins"], me["ko_wins"]) == (1, 4, 2, 1)
    assert me["is_me"] is True


def test_leaving_a_battle_scores_nothing_and_gives_the_other_a_win(client, people):
    a, b, *_ = people
    store(client, battle(a, b, reason="forfeit"))
    store(client, battle(b, a, reason="disconnect_timeout"))

    assert points_of(weekly(client, a)) == {"우현": 5 + 0, "진영": 0 + 5}


def test_only_this_weeks_battles_count(client, people):
    a, b, *_ = people
    store(client, battle(a, b, at=MONDAY))  # the first moment of the week
    store(client, battle(a, b, at=MONDAY - timedelta(seconds=1)))  # last week
    store(client, battle(a, b, at=MONDAY + timedelta(days=7)))  # next week

    body = weekly(client, a)

    assert points_of(body) == {"우현": 5, "진영": 1}
    assert body["week_start"] == "2026-11-23T00:00:00+09:00"
    assert body["week_end"] == "2026-11-30T00:00:00+09:00"


def test_a_resent_result_counts_once(client, people):
    a, b, *_ = people
    body = store(client, battle(a, b, reason="ko"))
    assert internal(client, "results", body).json()["saved"] == 0

    assert points_of(weekly(client, a)) == {"우현": 10, "진영": 1}


def test_a_battle_the_app_saved_itself_does_not_count(client, people):
    a, *_ = people
    played = NOW.isoformat()
    response = client.post(
        "/matches", match_body(1, played_at=played), format="json", **a.headers
    )
    assert response.status_code == 201

    body = weekly(client, a)

    assert body["entries"] == []
    assert body["me"] is None


def test_only_the_real_player_of_a_simulated_battle_scores(client, people):
    a, b, *_ = people
    body = battle(a, b, outcomes=("loss", "win"))
    # The simulated opponent copies b, but is not b.
    body["players"][1].update(player_id="sim-0a1b2c3d4e5f", simulated=True)
    store(client, body)

    assert points_of(weekly(client, a)) == {"우현": 1}


def test_a_friend_battle_does_not_count(client, people):
    a, b, *_ = people
    store(client, battle(a, b, reason="ko", kind="friend"))
    store(client, battle(a, b, kind="main"))

    assert points_of(weekly(client, a)) == {"우현": 5, "진영": 1}


def test_a_void_or_unfinished_battle_does_not_count(client, people):
    a, b, *_ = people
    for n, state in enumerate([OnlineBattle.VOID, OnlineBattle.ACTIVE]):
        OnlineBattle.objects.create(
            match_id=f"m-{n}",
            result_id=f"r-{n}",
            status=state,
            player_ids=[str(a.id), str(b.id)],
        )
        Match.objects.create(
            user_id=a.id,
            client_id=f"r-{n}",
            exercise="push_up",
            opponent_name=b.name,
            my_reps=10,
            opponent_reps=1,
            played_at=NOW,
            outcome="win",
            reason="ko",
        )

    assert weekly(client, a)["entries"] == []


def test_a_row_of_a_battle_i_was_not_in_does_not_count(client, people):
    a, b, c, _ = people
    store(client, battle(b, c))
    Match.objects.create(
        user_id=a.id,
        client_id=Match.objects.first().client_id,
        exercise="push_up",
        opponent_name=b.name,
        my_reps=30,
        opponent_reps=0,
        played_at=NOW,
        outcome="win",
        reason="ko",
    )

    assert "우현" not in points_of(weekly(client, a))


def test_equal_points_share_a_rank_and_the_next_rank_skips(client, people):
    a, b, c, d = people
    store(client, battle(a, d, reason="ko"))  # a 10, d 1
    store(client, battle(b, d, reason="ko"))  # b 10, d 2
    store(client, battle(c, d))  # c 5, d 3

    rows = weekly(client, d)["entries"]

    assert [(r["nickname"], r["rank"], r["points"]) for r in rows] == [
        ("우현", 1, 10),
        ("진영", 1, 10),
        ("상우", 3, 5),
        ("현우", 4, 3),
    ]


def test_global_lists_the_top_and_keeps_my_row_apart(client, people, monkeypatch):
    a, b, c, d = people
    monkeypatch.setattr(rankings, "GLOBAL_LIMIT", 2)
    store(client, battle(a, d, reason="ko"))
    store(client, battle(b, c))
    store(client, battle(c, d, outcomes=("draw", "draw")))  # c 4, d 4

    body = weekly(client, d, "global")

    assert [r["nickname"] for r in body["entries"]] == ["우현", "진영"]
    # Tied with 상우, so third as well, below the listed two.
    assert (body["me"]["nickname"], body["me"]["rank"]) == ("현우", 3)


def befriend(a, b, accepted=True):
    FriendRequest.objects.create(
        from_user_id=a.id,
        to_user_id=b.id,
        accepted_at=NOW if accepted else None,
    )


def test_friends_rank_the_same_weekly_points_among_me_and_my_friends(
    client, people
):
    a, b, c, d = people
    befriend(a, b)  # accepted, either way round
    befriend(c, a)
    befriend(a, d, accepted=False)  # still open: not a friend
    store(client, battle(b, d, reason="ko"))  # with a stranger: still counts
    store(client, battle(a, c))

    body = weekly(client, a, "friends")

    assert body["scope"] == "friends"
    assert [(r["nickname"], r["points"], r["rank"]) for r in body["entries"]] == [
        ("진영", 10, 1),
        ("우현", 5, 2),
        ("상우", 1, 3),
    ]
    assert body["me"]["nickname"] == "우현"


def test_friends_without_a_battle_this_week_show_with_zero(client, people):
    a, b, *_ = people
    befriend(a, b)

    body = weekly(client, a, "friends")

    assert [(r["nickname"], r["points"], r["rank"]) for r in body["entries"]] == [
        ("우현", 0, 1),
        ("진영", 0, 1),
    ]
    assert body["me"]["battles"] == 0


def test_an_unknown_scope_is_refused(client, people):
    a, *_ = people
    response = client.get("/matches/rankings/weekly?scope=week", **a.headers)
    assert response.status_code == 422


def test_rankings_need_a_login(client):
    assert client.get("/matches/rankings/weekly").status_code == 401


def test_a_deleted_friend_leaves_the_ranking(client, people):
    a, b, *_ = people
    befriend(a, b)
    User.objects.filter(id=b.id).delete()

    assert [r["nickname"] for r in weekly(client, a, "friends")["entries"]] == ["우현"]
