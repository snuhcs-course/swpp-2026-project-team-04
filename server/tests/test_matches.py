from .conftest import auth, match_body, sign_up


def post_match(client, token, body):
    return client.post("/matches", body, format="json", **auth(token))


def get(client, token, path):
    return client.get(path, **auth(token))


def test_new_user_has_no_record(client):
    token = sign_up(client)["token"]
    me = get(client, token, "/users/me").json()
    assert me["best_reps"] is None
    assert me["last_match"] is None
    assert get(client, token, "/matches").json() == {"items": [], "next_before": None}


def test_saved_match_is_returned_with_utc_time(client):
    token = sign_up(client)["token"]
    response = post_match(client, token, match_body())
    assert response.status_code == 201
    saved = response.json()
    assert saved["my_reps"] == 24
    assert saved["opponent_reps"] == 19
    assert saved["opponent_name"] == "RepBot"
    assert saved["exercise"] == "push_up"
    # 12:00 in Seoul is 03:00 UTC.
    assert saved["played_at"] == "2026-10-15T03:00:00Z"


def test_profile_has_the_best_reps_and_the_latest_match(client):
    token = sign_up(client)["token"]
    post_match(client, token, match_body(1, my_reps=30))
    post_match(client, token, match_body(3, my_reps=12))
    # Saved last but played earlier, e.g. an upload that was retried later.
    post_match(client, token, match_body(2, my_reps=40))
    me = get(client, token, "/users/me").json()
    assert me["best_reps"] == 40
    assert me["last_match"]["my_reps"] == 12


def test_same_client_id_is_saved_once(client):
    token = sign_up(client)["token"]
    first = post_match(client, token, match_body(7))
    again = post_match(client, token, match_body(7))
    assert first.status_code == 201
    assert again.status_code == 200
    assert again.json()["id"] == first.json()["id"]
    assert len(get(client, token, "/matches").json()["items"]) == 1


def test_history_is_newest_first_and_pages(client):
    token = sign_up(client)["token"]
    for n in [5, 1, 4, 2, 3]:
        post_match(client, token, match_body(n, my_reps=n))

    first = get(client, token, "/matches?limit=2").json()
    assert [m["my_reps"] for m in first["items"]] == [5, 4]
    second = get(client, token, f"/matches?limit=2&before={first['next_before']}").json()
    assert [m["my_reps"] for m in second["items"]] == [3, 2]
    last = get(client, token, f"/matches?limit=2&before={second['next_before']}").json()
    assert [m["my_reps"] for m in last["items"]] == [1]
    assert last["next_before"] is None


def test_matches_played_at_the_same_time_keep_a_stable_order(client):
    token = sign_up(client)["token"]
    same_time = "2026-10-15T12:00:00+09:00"
    for n in range(3):
        post_match(client, token, match_body(n, my_reps=n, played_at=same_time))
    first = get(client, token, "/matches?limit=2").json()
    rest = get(client, token, f"/matches?limit=2&before={first['next_before']}").json()
    assert [m["my_reps"] for m in first["items"] + rest["items"]] == [2, 1, 0]


def test_another_users_matches_are_not_visible(client):
    mine = sign_up(client, login_id="woohyun")["token"]
    theirs = sign_up(client, login_id="jinyoung", nickname="진영")["token"]
    saved = post_match(client, theirs, match_body(1)).json()

    assert get(client, mine, "/matches").json()["items"] == []
    me = get(client, mine, "/users/me").json()
    assert me["best_reps"] is None and me["last_match"] is None
    # Their match id cannot be used as my cursor either.
    assert get(client, mine, f"/matches?before={saved['id']}").status_code == 400


def test_same_client_id_from_two_users_is_two_matches(client):
    mine = sign_up(client, login_id="woohyun")["token"]
    theirs = sign_up(client, login_id="jinyoung", nickname="진영")["token"]
    assert post_match(client, mine, match_body(1)).status_code == 201
    assert post_match(client, theirs, match_body(1)).status_code == 201


def test_match_body_is_validated(client):
    token = sign_up(client)["token"]
    bad = [
        {"my_reps": -1},
        {"my_reps": 1001},
        {"exercise": "plank"},
        {"opponent_name": ""},
        {"played_at": "2026-10-15T12:00:00"},  # no time zone
        {"client_id": "x"},
    ]
    for change in bad:
        response = post_match(client, token, match_body() | change)
        assert response.status_code == 422, change


def test_bot_upload_keeps_the_game_outcome_and_reason(client):
    token = sign_up(client)["token"]
    body = match_body(1, my_reps=5, opponent_reps=6) | {
        "outcome": "win",
        "reason": "ko",
    }
    saved = post_match(client, token, body)
    assert saved.status_code == 201
    assert (saved.json()["outcome"], saved.json()["reason"]) == ("win", "ko")
    [listed] = get(client, token, "/matches").json()["items"]
    assert (listed["outcome"], listed["reason"]) == ("win", "ko")
    assert get(client, token, "/users/me").json()["last_match"]["outcome"] == "win"


def test_bot_upload_without_them_goes_by_the_reps_and_time_up(client):
    token = sign_up(client)["token"]
    saved = post_match(client, token, match_body(1, my_reps=5, opponent_reps=6))
    assert (saved.json()["outcome"], saved.json()["reason"]) == ("loss", "time_up")


def test_bot_upload_refuses_other_outcomes_and_reasons(client):
    token = sign_up(client)["token"]
    for change in [
        {"outcome": "victory"},
        {"reason": "unknown"},
        {"reason": "forfeit"},
        {"reason": "disconnect_timeout"},
    ]:
        response = post_match(client, token, match_body() | change)
        assert response.status_code == 422, change


def test_retried_bot_upload_keeps_the_first_outcome(client):
    token = sign_up(client)["token"]
    body = match_body(1, my_reps=5, opponent_reps=6)
    post_match(client, token, body | {"outcome": "win", "reason": "ko"})
    again = post_match(client, token, body | {"outcome": "loss", "reason": "time_up"})
    assert again.status_code == 200
    assert (again.json()["outcome"], again.json()["reason"]) == ("win", "ko")


def test_upload_keeps_the_points_beside_the_reps(client):
    token = sign_up(client)["token"]
    body = match_body(1, my_reps=7, opponent_reps=9) | {
        "my_score": 150,
        "opponent_score": 90,
        "outcome": "win",
    }
    saved = post_match(client, token, body).json()
    assert (saved["my_score"], saved["opponent_score"]) == (150, 90)
    assert (saved["my_reps"], saved["opponent_reps"]) == (7, 9)
    [listed] = get(client, token, "/matches").json()["items"]
    assert (listed["my_score"], listed["opponent_score"]) == (150, 90)
    last = get(client, token, "/users/me").json()["last_match"]
    assert (last["my_score"], last["opponent_score"]) == (150, 90)


def test_old_app_upload_has_no_points(client):
    token = sign_up(client)["token"]
    saved = post_match(client, token, match_body(1))
    assert saved.status_code == 201
    assert (saved.json()["my_score"], saved.json()["opponent_score"]) == (None, None)
    [listed] = get(client, token, "/matches").json()["items"]
    assert (listed["my_score"], listed["opponent_score"]) == (None, None)


def test_zero_points_are_points(client):
    token = sign_up(client)["token"]
    body = match_body(1) | {"my_score": 0, "opponent_score": 0}
    saved = post_match(client, token, body).json()
    assert (saved["my_score"], saved["opponent_score"]) == (0, 0)


def test_the_most_points_are_accepted(client):
    token = sign_up(client)["token"]
    body = match_body(1) | {"my_score": 100_000, "opponent_score": 100_000}
    assert post_match(client, token, body).status_code == 201


def test_points_come_together_and_in_range(client):
    token = sign_up(client)["token"]
    for change in [
        {"my_score": 150},
        {"opponent_score": 90},
        {"my_score": None, "opponent_score": None},
        {"my_score": -1, "opponent_score": 90},
        {"my_score": 150, "opponent_score": 100_001},
    ]:
        response = post_match(client, token, match_body() | change)
        assert response.status_code == 422, change
    assert get(client, token, "/matches").json()["items"] == []


def test_retried_upload_keeps_the_first_points(client):
    token = sign_up(client)["token"]
    post_match(client, token, match_body(1) | {"my_score": 150, "opponent_score": 90})
    again = post_match(client, token, match_body(1) | {"my_score": 1, "opponent_score": 2})
    assert again.status_code == 200
    assert (again.json()["my_score"], again.json()["opponent_score"]) == (150, 90)


def test_new_user_has_no_bests(client):
    token = sign_up(client)["token"]
    assert get(client, token, "/users/me").json()["bests"] == {}


def test_each_exercise_has_its_own_best(client):
    token = sign_up(client)["token"]
    squat = {"exercise": "squat"}
    points = lambda mine: {"my_score": mine, "opponent_score": 0}
    # The most reps and the most points need not be the same battle.
    post_match(client, token, match_body(1, my_reps=14) | points(150))
    post_match(client, token, match_body(2, my_reps=20) | points(90))
    post_match(client, token, match_body(3, my_reps=9) | points(60) | squat)
    me = get(client, token, "/users/me").json()
    assert me["bests"] == {
        "push_up": {"score": 150, "reps": 20},
        "squat": {"score": 60, "reps": 9},
    }
    assert me["best_reps"] == 20


def test_battles_with_no_points_still_count_their_reps(client):
    token = sign_up(client)["token"]
    post_match(client, token, match_body(1, my_reps=32))
    post_match(client, token, match_body(2, my_reps=5) | {"exercise": "squat"})
    post_match(
        client,
        token,
        match_body(3, my_reps=5) | {"exercise": "squat", "my_score": 60, "opponent_score": 0},
    )
    assert get(client, token, "/users/me").json()["bests"] == {
        "push_up": {"score": None, "reps": 32},
        "squat": {"score": 60, "reps": 5},
    }


def test_bests_are_only_my_own(client):
    mine = sign_up(client, login_id="woohyun")["token"]
    theirs = sign_up(client, login_id="jinyoung", nickname="진영")["token"]
    post_match(client, theirs, match_body(1) | {"my_score": 150, "opponent_score": 0})
    assert get(client, mine, "/users/me").json()["bests"] == {}


def test_limit_is_bounded(client):
    token = sign_up(client)["token"]
    assert get(client, token, "/matches?limit=0").status_code == 422
    assert get(client, token, "/matches?limit=51").status_code == 422
