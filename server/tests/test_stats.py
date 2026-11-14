"""Statistics points (GET /matches/stats), issue codes in the summary, and
the online flag on history rows."""

from .conftest import auth, match_body, sign_up
from .test_feedback import feedback, post_match
from .test_results import internal, result


def stats(client, token, query=""):
    return client.get(f"/matches/stats{query}", **auth(token))


def test_new_user_has_no_points(client):
    token = sign_up(client)["token"]
    assert stats(client, token).json() == {"items": []}


def test_points_are_oldest_first_with_issue_codes(client):
    token = sign_up(client)["token"]
    later = match_body(2, my_reps=14)
    later["my_score"], later["opponent_score"] = 150, 90
    later["reason"] = "ko"
    later["outcome"] = "win"
    later["feedback"] = feedback(issues={"reject.insufficientDepth": 3, "elbow_flare": 1})
    post_match(client, token, later)
    post_match(client, token, match_body(1, my_reps=9))

    items = stats(client, token).json()["items"]
    assert [p["my_reps"] for p in items] == [9, 14]
    first, second = items
    assert first["issues"] is None and first["has_feedback"] is False
    assert first["my_score"] is None
    assert first["is_online"] is False
    assert second["issues"] == {"reject.insufficientDepth": 3, "elbow_flare": 1}
    assert second["has_feedback"] is True
    assert (second["my_score"], second["reason"], second["outcome"]) == (150, "ko", "win")
    assert second["played_at"] == "2026-10-15T03:02:00Z"
    assert set(second) == {
        "id",
        "exercise",
        "played_at",
        "my_reps",
        "my_score",
        "outcome",
        "reason",
        "is_online",
        "has_feedback",
        "issues",
    }


def test_feedback_from_an_older_app_has_no_codes(client):
    token = sign_up(client)["token"]
    body = match_body(1)
    body["feedback"] = feedback()
    post_match(client, token, body)
    [point] = stats(client, token).json()["items"]
    assert point["has_feedback"] is True
    assert point["issues"] is None


def test_points_filter_by_exercise_and_since(client):
    token = sign_up(client)["token"]
    post_match(client, token, match_body(1, played_at="2026-11-02T08:00:00+09:00"))
    squat = match_body(2, played_at="2026-11-10T08:00:00+09:00")
    squat["exercise"] = "squat"
    post_match(client, token, squat)
    post_match(client, token, match_body(3, played_at="2026-11-10T09:00:00+09:00"))

    def reps_of(query):
        return [p["exercise"] for p in stats(client, token, query).json()["items"]]

    assert reps_of("?exercise=push_up") == ["push_up", "push_up"]
    assert reps_of("?exercise=squat") == ["squat"]
    # Monday 2026-11-09 00:00 in Seoul; the 11-02 battle is left out.
    since = "?since=2026-11-09T00:00:00%2B09:00"
    assert reps_of(since) == ["squat", "push_up"]
    # A battle exactly at the start counts.
    assert reps_of("?since=2026-11-10T08:00:00%2B09:00") == ["squat", "push_up"]
    assert reps_of(since + "&exercise=push_up") == ["push_up"]


def test_points_are_uncapped(client):
    token = sign_up(client)["token"]
    for n in range(60):
        post_match(client, token, match_body(n))
    assert len(stats(client, token).json()["items"]) == 60


def test_bad_stats_queries_are_rejected(client):
    token = sign_up(client)["token"]
    for query in ["?exercise=plank", "?since=yesterday", "?since=2026-11-09T00:00:00"]:
        assert stats(client, token, query).status_code == 422, query


def test_stats_need_login(client):
    assert client.get("/matches/stats").status_code == 401


def test_stats_show_only_the_users_own_battles(client):
    mine = sign_up(client)["token"]
    other = sign_up(client, login_id="other", nickname="남")["token"]
    post_match(client, other, match_body(1))
    assert stats(client, mine).json()["items"] == []


def test_online_battles_are_flagged_in_history_and_stats(client):
    a = sign_up(client, login_id="woohyun", nickname="우현")
    b = sign_up(client, login_id="jinyoung", nickname="진영")
    assert internal(client, "results", result(a, b, reason="ko")).status_code == 201
    post_match(client, a["token"], match_body(1))

    rows = client.get("/matches", **auth(a["token"])).json()["items"]
    assert {(r["opponent_name"], r["is_online"]) for r in rows} == {
        ("진영", True),
        ("RepBot", False),
    }
    online = next(r for r in rows if r["is_online"])
    assert online["reason"] == "ko"
    points = stats(client, a["token"]).json()["items"]
    assert sorted(p["is_online"] for p in points) == [False, True]


def test_a_single_match_reads_its_online_flag(client):
    token = sign_up(client)["token"]
    saved = post_match(client, token, match_body(1)).json()
    assert saved["is_online"] is False
    me = client.get("/users/me", **auth(token)).json()
    assert me["last_match"]["is_online"] is False


def test_issue_codes_are_checked(client):
    token = sign_up(client)["token"]
    for n, issues in enumerate([
        {"reject.insufficientDepth": 0},
        {"Bad Code": 1},
        {"reject.": 1},
        {f"code_{chr(97 + i)}": 1 for i in range(26)} | {"x": 1, "y": 1, "z": 1, "w": 1, "v": 1},
        ["elbow_flare"],
    ]):
        body = match_body(n)
        body["feedback"] = feedback(issues=issues)
        response = post_match(client, token, body)
        assert response.status_code == 422, issues


def test_issue_codes_are_kept_in_the_list_summary(client):
    token = sign_up(client)["token"]
    body = match_body(1)
    body["feedback"] = feedback(issues={"head_lead": 1})
    post_match(client, token, body)
    [row] = client.get("/matches", **auth(token)).json()["items"]
    assert row["feedback_summary"]["issues"] == {"head_lead": 1}


def test_stats_and_history_use_a_fixed_number_of_queries(
    client, django_assert_max_num_queries
):
    token = sign_up(client)["token"]
    for n in range(5):
        body = match_body(n)
        body["feedback"] = feedback(issues={"head_lead": 1})
        post_match(client, token, body)
    # Auth, the battles with their online flag, the feedback summaries.
    with django_assert_max_num_queries(3):
        assert len(stats(client, token).json()["items"]) == 5
    with django_assert_max_num_queries(3):
        assert len(client.get("/matches", **auth(token)).json()["items"]) == 5
