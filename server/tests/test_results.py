# AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
"""P11: the battle server stores online results and voids lost battles."""

import pytest
from django.test import override_settings

from matches.models import Match, OnlineBattle

from .conftest import auth, sign_up

SECRET = "test-results-secret-not-used-anywhere-else"
# The restarted battle server booted after the battles in these tests began.
BOOT = 1792022440000


def internal(client, path, body, secret=SECRET, **extra):
    return client.post(
        f"/internal/{path}", body, format="json", HTTP_X_RESULTS_SECRET=secret, **extra
    )


@pytest.fixture
def players(client):
    a = sign_up(client, login_id="woohyun", nickname="우현")
    b = sign_up(client, login_id="jinyoung", nickname="진영")
    return a, b


def result(a, b, result_id="result-0001", reason="time_up", reps=(12, 10), outcomes=("win", "loss")):
    return {
        "match_id": "match-0001",
        "result_id": result_id,
        "reason": reason,
        "ended_at_ms": 1792022460000,
        "players": [
            {
                "player_id": str(a["user"]["id"]),
                "display_name": a["user"]["nickname"],
                "valid_reps": reps[0],
                "invalid_reps": 2,
                "outcome": outcomes[0],
            },
            {
                "player_id": str(b["user"]["id"]),
                "display_name": b["user"]["nickname"],
                "valid_reps": reps[1],
                "invalid_reps": 1,
                "outcome": outcomes[1],
            },
        ],
    }


def history(client, account):
    return client.get("/matches", **auth(account["token"])).json()["items"]


def test_result_stores_one_row_per_player(client, players):
    a, b = players
    response = internal(client, "results", result(a, b))
    assert response.status_code == 201
    assert response.json()["saved"] == 2
    [mine] = history(client, a)
    [theirs] = history(client, b)
    assert (mine["outcome"], mine["my_reps"], mine["opponent_reps"]) == ("win", 12, 10)
    assert mine["opponent_name"] == "진영"
    assert (theirs["outcome"], theirs["my_reps"], theirs["opponent_reps"]) == ("loss", 10, 12)
    assert theirs["opponent_name"] == "우현"
    assert mine["reason"] == theirs["reason"] == "time_up"
    assert mine["played_at"] == "2026-10-15T00:01:00Z"
    assert set(Match.objects.values_list("client_id", flat=True)) == {"result-0001"}


def test_same_result_twice_is_stored_once(client, players):
    a, b = players
    internal(client, "results", result(a, b))
    again = internal(client, "results", result(a, b))
    assert again.status_code == 200
    assert again.json()["saved"] == 0
    assert Match.objects.count() == 2


def test_forfeit_is_a_loss_whatever_the_reps(client, players):
    a, b = players
    body = result(a, b, reason="forfeit", reps=(20, 3), outcomes=("loss", "win"))
    internal(client, "results", body)
    [mine] = history(client, a)
    assert (mine["outcome"], mine["reason"], mine["my_reps"]) == ("loss", "forfeit", 20)


def test_draw_is_stored_for_both(client, players):
    a, b = players
    internal(client, "results", result(a, b, reps=(7, 7), outcomes=("draw", "draw")))
    assert [history(client, p)[0]["outcome"] for p in players] == ["draw", "draw"]


def test_feedback_uploaded_with_the_result_id_attaches_to_the_row(client, players):
    a, b = players
    from .test_feedback import feedback

    # The phone may upload before the battle server's call arrives.
    client.put("/matches/feedback/result-0001", feedback(), format="json", **auth(a["token"]))
    internal(client, "results", result(a, b))
    [mine] = history(client, a)
    [theirs] = history(client, b)
    assert mine["has_feedback"] is True
    assert theirs["has_feedback"] is False


def test_saver_needs_the_secret(client, players):
    a, b = players
    assert internal(client, "results", result(a, b), secret="wrong").status_code == 403
    assert internal(client, "results", result(a, b), secret="").status_code == 403
    assert Match.objects.count() == 0


def test_saver_refuses_anything_not_from_loopback(client, players):
    a, b = players
    far = internal(client, "results", result(a, b), REMOTE_ADDR="203.0.113.5")
    assert far.status_code == 403
    # Through nginx /api/ the address is loopback too, but nginx adds this.
    proxied = internal(client, "results", result(a, b), HTTP_X_FORWARDED_FOR="203.0.113.5")
    assert proxied.status_code == 403
    assert Match.objects.count() == 0


@override_settings(RESULTS_SECRET="")
def test_saver_is_closed_without_a_configured_secret(client, players):
    a, b = players
    assert internal(client, "results", result(a, b), secret="").status_code == 403


def test_user_token_does_not_open_the_saver(client, players):
    a, b = players
    response = client.post(
        "/internal/results", result(a, b), format="json", **auth(a["token"])
    )
    assert response.status_code == 403


def test_invalid_results_are_rejected(client, players):
    a, b = players
    one_player = result(a, b)
    one_player["players"] = one_player["players"][:1]
    same_player = result(a, b)
    same_player["players"][1] = dict(same_player["players"][0], outcome="loss")
    both_win = result(a, b, outcomes=("win", "win"))
    void_reason = result(a, b, reason="both_disconnected")
    bot_id = result(a, b)
    bot_id["players"][0]["player_id"] = "dev-user"
    for body in [one_player, same_player, both_win, void_reason, bot_id]:
        assert internal(client, "results", body).status_code == 422
    assert Match.objects.count() == 0


def test_unknown_player_is_skipped(client, players):
    a, b = players
    body = result(a, b)
    body["players"][1]["player_id"] = "999999"
    response = internal(client, "results", body)
    assert response.json()["saved"] == 1
    assert len(history(client, a)) == 1


def test_start_is_recorded_once(client, players):
    a, b = players
    body = {"match_id": "match-0001", "started_at_ms": 1792022430000, "player_ids": ["1", "2"]}
    assert internal(client, "battles/start", body).status_code == 201
    assert internal(client, "battles/start", body).status_code == 200
    battle = OnlineBattle.objects.get()
    assert battle.status == OnlineBattle.ACTIVE
    assert battle.player_ids == ["1", "2"]


def test_started_battle_becomes_finished_with_its_result(client, players):
    a, b = players
    internal(
        client,
        "battles/start",
        {"match_id": "match-0001", "started_at_ms": 1792022430000, "player_ids": ["1", "2"]},
    )
    internal(client, "results", result(a, b))
    battle = OnlineBattle.objects.get()
    assert (battle.status, battle.result_id, battle.reason) == ("finished", "result-0001", "time_up")
    # Nothing is left to void after a restart.
    assert internal(client, "battles/recover", {"booted_at_ms": BOOT}).json() == {"voided": []}


def test_restart_voids_active_battles_and_stores_no_result(client, players):
    a, b = players
    internal(
        client,
        "battles/start",
        {"match_id": "match-0001", "started_at_ms": 1792022430000, "player_ids": ["1", "2"]},
    )
    recovered = internal(client, "battles/recover", {"booted_at_ms": BOOT})
    assert recovered.status_code == 200
    assert recovered.json() == {"voided": [{"match_id": "match-0001", "player_ids": ["1", "2"]}]}
    battle = OnlineBattle.objects.get()
    assert (battle.status, battle.reason) == ("void", "server_restarted")
    # A late result for the lost battle must not appear in either history.
    late = internal(client, "results", result(a, b))
    assert late.status_code == 409
    assert history(client, a) == history(client, b) == []
    # A second restart has nothing new to void.
    assert internal(client, "battles/recover", {"booted_at_ms": BOOT}).json() == {"voided": []}


def test_void_battle_is_recorded_without_a_result(client, players):
    body = {"match_id": "match-0002", "reason": "both_disconnected"}
    assert internal(client, "battles/void", body).status_code == 200
    battle = OnlineBattle.objects.get()
    assert (battle.status, battle.reason) == ("void", "both_disconnected")
    assert Match.objects.count() == 0


def test_finished_battle_cannot_be_voided(client, players):
    a, b = players
    internal(client, "results", result(a, b))
    body = {"match_id": "match-0001", "reason": "both_disconnected"}
    assert internal(client, "battles/void", body).status_code == 409
    assert OnlineBattle.objects.get().status == "finished"


def test_second_result_for_the_same_battle_conflicts(client, players):
    a, b = players
    internal(client, "results", result(a, b))
    other = internal(client, "results", result(a, b, result_id="result-0002"))
    assert other.status_code == 409
    assert Match.objects.count() == 2


def test_internal_start_void_and_recover_need_the_secret(client):
    for path in ["battles/start", "battles/void", "battles/recover"]:
        assert internal(client, path, {}, secret="wrong").status_code == 403


def test_app_cannot_pre_post_an_online_result(client, players):
    a, b = players
    from .conftest import match_body

    # B learns the result_id from match.finished and races the saver.
    forged = {**match_body(1, my_reps=50, opponent_reps=0), "client_id": "result-0001"}
    assert client.post("/matches", forged, format="json", **auth(b["token"])).status_code == 201
    saved = internal(client, "results", result(a, b))
    assert saved.status_code == 201
    assert saved.json()["saved"] == 2
    [theirs] = history(client, b)
    assert (theirs["outcome"], theirs["my_reps"], theirs["opponent_name"]) == ("loss", 10, "우현")
    assert len(history(client, a)) == 1
    # Once stored, the app cannot post under that result_id at all.
    again = client.post("/matches", forged, format="json", **auth(b["token"]))
    assert again.status_code == 409
    assert history(client, b)[0]["outcome"] == "loss"


def test_late_recover_spares_battles_the_new_process_started(client, players):
    old = {"match_id": "old-match", "started_at_ms": BOOT - 5000, "player_ids": ["1", "2"]}
    new = {"match_id": "new-match", "started_at_ms": BOOT + 5000, "player_ids": ["3", "4"]}
    internal(client, "battles/start", old)
    internal(client, "battles/start", new)
    recovered = internal(client, "battles/recover", {"booted_at_ms": BOOT})
    assert [b["match_id"] for b in recovered.json()["voided"]] == ["old-match"]
    assert OnlineBattle.objects.get(match_id="new-match").status == OnlineBattle.ACTIVE


def test_recover_needs_the_boot_time(client):
    assert internal(client, "battles/recover", {}).status_code == 422
