# AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
"""Form feedback stored with a battle, and history rows that show it."""

from django.db import connection
from django.db.migrations.executor import MigrationExecutor

from matches.models import Match, MatchFeedback

from .conftest import auth, match_body, sign_up


def summary(top_issue="팔꿈치가 벌어져요", **overrides):
    value = {
        "valid_reps": 12,
        "invalid_reps": 2,
        "accuracy": 12 / 14,
        "top_issue": top_issue,
        "issue_count": 1 if top_issue else 0,
    }
    value.update(overrides)
    return value


def report(reps=3):
    return {
        "version": 1,
        "endedAt": 1792022460000,
        "opponentName": "RepBot",
        "roundMs": 30000,
        "reps": [{"index": i, "valid": True, "ms": 1000 * i} for i in range(reps)],
        "samples": [{"ms": 100, "depth": 0.7}],
        "poses": [],
        "leftFlarePose": None,
        "rightFlarePose": None,
        "handsPose": None,
        "headPose": None,
    }


def feedback(**overrides):
    return {"summary": summary(**overrides), "report": report()}


def post_match(client, token, body):
    return client.post("/matches", body, format="json", **auth(token))


def put_feedback(client, token, client_id, body):
    return client.put(
        f"/matches/feedback/{client_id}", body, format="json", **auth(token)
    )


def items(client, token, query=""):
    return client.get(f"/matches{query}", **auth(token)).json()["items"]


def detail(client, token, match_id):
    return client.get(f"/matches/{match_id}/feedback", **auth(token))


def test_bot_match_with_feedback_is_stored_and_listed(client):
    token = sign_up(client)["token"]
    response = post_match(client, token, {**match_body(1), "feedback": feedback()})
    assert response.status_code == 201
    saved = response.json()
    assert saved["outcome"] == "win"
    assert saved["reason"] == "time_up"
    [row] = items(client, token)
    assert row["has_feedback"] is True
    assert row["feedback_summary"]["top_issue"] == "팔꿈치가 벌어져요"
    # The list never carries the full report.
    assert "report" not in row
    got = detail(client, token, saved["id"])
    assert got.status_code == 200
    assert got.json()["report"] == report()
    assert got.json()["summary"]["valid_reps"] == 12


def test_bot_outcome_comes_from_the_reps(client):
    token = sign_up(client)["token"]
    post_match(client, token, match_body(1, my_reps=5, opponent_reps=9))
    post_match(client, token, match_body(2, my_reps=7, opponent_reps=7))
    assert [m["outcome"] for m in items(client, token)] == ["draw", "loss"]


def test_retried_upload_keeps_one_match_and_the_first_feedback(client):
    token = sign_up(client)["token"]
    first = post_match(client, token, {**match_body(3), "feedback": feedback()})
    again = post_match(
        client, token, {**match_body(3), "feedback": feedback(top_issue=None)}
    )
    assert again.status_code == 200
    assert again.json()["id"] == first.json()["id"]
    assert Match.objects.count() == 1
    assert MatchFeedback.objects.count() == 1
    assert items(client, token)[0]["feedback_summary"]["top_issue"] == "팔꿈치가 벌어져요"


def test_retry_adds_feedback_to_a_match_saved_without_it(client):
    token = sign_up(client)["token"]
    post_match(client, token, match_body(4))
    post_match(client, token, {**match_body(4), "feedback": feedback()})
    assert items(client, token)[0]["has_feedback"] is True


def test_match_saved_before_feedback_existed_reads_as_no_feedback(client):
    token = sign_up(client)["token"]
    saved = post_match(client, token, match_body(5)).json()
    [row] = items(client, token)
    assert row["has_feedback"] is False
    assert row["feedback_summary"] is None
    assert detail(client, token, saved["id"]).status_code == 404


def test_feedback_put_before_the_match_row_is_joined_on_read(client):
    token = sign_up(client)["token"]
    stored = put_feedback(client, token, "client-0006", feedback())
    assert stored.status_code == 201
    post_match(client, token, match_body(6))
    assert items(client, token)[0]["has_feedback"] is True


def test_feedback_put_after_the_match_row_and_again_replaces_it(client):
    token = sign_up(client)["token"]
    saved = post_match(client, token, match_body(7)).json()
    put_feedback(client, token, "client-0007", feedback())
    again = put_feedback(client, token, "client-0007", feedback(top_issue=None))
    assert again.status_code == 200
    assert MatchFeedback.objects.count() == 1
    assert detail(client, token, saved["id"]).json()["summary"]["top_issue"] is None


def test_another_users_feedback_is_not_found(client):
    mine = sign_up(client, login_id="woohyun")["token"]
    theirs = sign_up(client, login_id="jinyoung", nickname="진영")["token"]
    saved = post_match(client, mine, {**match_body(8), "feedback": feedback()}).json()
    assert detail(client, theirs, saved["id"]).status_code == 404
    # Their own upload with the same client_id stays separate.
    put_feedback(client, theirs, "client-0008", feedback(top_issue=None))
    assert detail(client, mine, saved["id"]).json()["summary"]["top_issue"] is not None


def test_unknown_match_feedback_is_not_found(client):
    token = sign_up(client)["token"]
    assert detail(client, token, 9999).status_code == 404


def test_feedback_needs_login(client):
    assert client.put("/matches/feedback/client-0001", feedback(), format="json").status_code == 401
    assert client.get("/matches/1/feedback").status_code == 401


def test_invalid_feedback_is_rejected(client):
    token = sign_up(client)["token"]
    bad_bodies = [
        {"summary": summary(accuracy=1.5), "report": report()},
        {"summary": summary(valid_reps=-1), "report": report()},
        {"summary": {"valid_reps": 1}, "report": report()},
        {"summary": summary(), "report": [1, 2]},
        {"summary": summary(), "report": {"version": 1, "reps": []}},
        {"summary": summary(), "report": {**report(), "version": "1"}},
    ]
    for body in bad_bodies:
        assert put_feedback(client, token, "client-0010", body).status_code == 422, body
        assert post_match(client, token, {**match_body(10), "feedback": body}).status_code == 422
    assert Match.objects.count() == 0
    assert MatchFeedback.objects.count() == 0


def test_too_large_report_is_rejected(client):
    token = sign_up(client)["token"]
    big = report()
    big["samples"] = [{"ms": i, "depth": 0.123456789} for i in range(20000)]
    response = put_feedback(client, token, "client-0011", {"summary": summary(), "report": big})
    assert response.status_code == 422
    assert "report_too_large" in str(response.json())


def test_bad_client_id_in_the_path_is_not_found(client):
    token = sign_up(client)["token"]
    assert put_feedback(client, token, "short", feedback()).status_code == 404
    assert put_feedback(client, token, "x" * 37, feedback()).status_code == 404


def test_limit_three_returns_the_newest_three_with_summaries(client):
    token = sign_up(client)["token"]
    for n in range(1, 6):
        post_match(client, token, {**match_body(n, my_reps=n), "feedback": feedback()})
    rows = items(client, token, "?limit=3")
    assert [m["my_reps"] for m in rows] == [5, 4, 3]
    assert all(m["feedback_summary"] is not None for m in rows)


def test_profile_last_match_has_the_outcome(client):
    token = sign_up(client)["token"]
    post_match(client, token, match_body(1, my_reps=3, opponent_reps=9))
    me = client.get("/users/me", **auth(token)).json()
    assert me["last_match"]["outcome"] == "loss"


def test_migration_backfills_the_outcome_of_old_rows(transactional_db):
    executor = MigrationExecutor(connection)
    executor.migrate([("matches", "0001_initial")])
    old_apps = executor.loader.project_state([("matches", "0001_initial")]).apps
    User = old_apps.get_model("accounts", "User")
    OldMatch = old_apps.get_model("matches", "Match")
    user = User.objects.create(login_id="olduser", nickname="old", password="x")
    for n, (mine, theirs) in enumerate([(9, 3), (2, 8), (5, 5)]):
        OldMatch.objects.create(
            user=user,
            client_id=f"old-{n:04d}",
            exercise="push_up",
            opponent_name="RepBot",
            my_reps=mine,
            opponent_reps=theirs,
            played_at="2026-10-15T03:00:00Z",
        )
    executor = MigrationExecutor(connection)
    executor.loader.build_graph()
    executor.migrate(executor.loader.graph.leaf_nodes())
    outcomes = dict(Match.objects.values_list("client_id", "outcome"))
    assert outcomes == {"old-0000": "win", "old-0001": "loss", "old-0002": "draw"}
    assert set(Match.objects.values_list("reason", flat=True)) == {"time_up"}
