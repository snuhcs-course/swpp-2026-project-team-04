from datetime import timedelta

import pytest
from django.utils import timezone

from accounts.friends_views import INVITE_TTL, are_friends, friend_code
from accounts.models import FriendBattleInvite, FriendRequest, User

from .conftest import auth, sign_up


def _user(client, login_id, nickname):
    body = sign_up(client, login_id=login_id, nickname=nickname)
    return body["user"]["id"], auth(body["token"])


@pytest.fixture
def two(client):
    a = _user(client, "alice01", "쥐돌이")
    b = _user(client, "bobby01", "헬창")
    return a, b


def _code(user_id):
    user = User.objects.get(id=user_id)
    return friend_code(user)


def _request(client, me, code):
    return client.post("/friends/requests", {"code": code}, format="json", **me)


def _befriend(client, a, b):
    sent = _request(client, a[1], _code(b[0]))
    assert sent.status_code == 201, sent.content
    accepted = client.post(
        f"/friends/requests/{sent.json()['request_id']}/accept", **b[1]
    )
    assert accepted.status_code == 200


def _invite(client, me, friend_id, exercise="push_up"):
    return client.post(
        "/friends/invites",
        {"friend_id": friend_id, "exercise": exercise},
        format="json",
        **me,
    )


def test_friend_code_pads_the_account_id_to_four_digits(client):
    user_id, me = _user(client, "alice01", "쥐돌이")
    body = client.get("/friends", **me).json()
    assert body["code"] == f"쥐돌이#{user_id:04d}"
    user = User.objects.get(id=user_id)
    user.id = 12345
    assert friend_code(user) == "쥐돌이#12345"


def test_friends_need_a_login(client):
    assert client.get("/friends").status_code == 401
    assert client.post("/friends/requests", {}, format="json").status_code == 401


def test_request_then_accept_makes_both_friends(client, two):
    (a_id, a), (b_id, b) = two
    sent = _request(client, a, _code(b_id))
    assert sent.status_code == 201
    assert sent.json()["status"] == "requested"
    assert sent.json()["to"]["nickname"] == "헬창"

    assert client.get("/friends", **a).json()["outgoing"][0]["to"]["id"] == b_id
    incoming = client.get("/friends", **b).json()["incoming"]
    assert [r["from"]["id"] for r in incoming] == [a_id]

    accepted = client.post(
        f"/friends/requests/{incoming[0]['request_id']}/accept", **b
    )
    assert accepted.json() == {
        "status": "accepted",
        "friend": {"id": a_id, "nickname": "쥐돌이", "code": _code(a_id)},
    }
    for me, other in ((a, b_id), (b, a_id)):
        body = client.get("/friends", **me).json()
        assert [f["id"] for f in body["friends"]] == [other]
        assert body["incoming"] == [] and body["outgoing"] == []


def test_a_second_request_either_way_is_not_a_duplicate(client, two):
    (a_id, a), (b_id, b) = two
    assert _request(client, a, _code(b_id)).status_code == 201
    again = _request(client, a, _code(b_id))
    assert again.status_code == 409
    assert again.json() == {"detail": "already_requested"}
    # Asked back: that accepts the open request, not a second row.
    back = _request(client, b, _code(a_id))
    assert back.status_code == 200
    assert back.json()["status"] == "accepted"
    assert FriendRequest.objects.count() == 1
    assert are_friends(User.objects.get(id=a_id), User.objects.get(id=b_id))
    for me, other in ((a, b_id), (b, a_id)):
        repeat = _request(client, me, _code(other))
        assert repeat.status_code == 409
        assert repeat.json() == {"detail": "already_friends"}


@pytest.mark.parametrize(
    "code, status, detail",
    [
        (None, 400, "invalid_code"),
        (42, 400, "invalid_code"),
        ("헬창", 400, "invalid_code"),
        ("헬창#", 400, "invalid_code"),
        ("#0001", 400, "invalid_code"),
        ("헬창#00a1", 400, "invalid_code"),
        # Shorter than the four digits a code shows (Codex review).
        ("헬창#2", 400, "invalid_code"),
        ("헬창#002", 400, "invalid_code"),
        ("열세글자가넘는아주긴닉네임#0001", 400, "invalid_code"),
    ],
)
def test_a_malformed_code_is_refused(client, two, code, status, detail):
    (_, a), _ = two
    response = _request(client, a, code)
    assert response.status_code == status
    assert response.json() == {"detail": detail}


def test_a_code_needs_both_the_number_and_the_nickname(client, two):
    (a_id, a), (b_id, _) = two
    wrong_name = _request(client, a, f"쥐돌이#{b_id:04d}")
    assert wrong_name.status_code == 404
    assert wrong_name.json() == {"detail": "user_not_found"}
    assert _request(client, a, "헬창#9999").status_code == 404
    # Spaces around a pasted code are fine.
    assert _request(client, a, f"  {_code(b_id)} ").status_code == 201


def test_same_nicknames_are_told_apart_by_the_tag(client):
    _, me = _user(client, "alice01", "쥐돌이")
    first, _ = _user(client, "twin0001", "헬창")
    second, _ = _user(client, "twin0002", "헬창")
    sent = _request(client, me, _code(second))
    assert sent.json()["to"]["id"] == second != first


def test_i_cannot_add_myself(client):
    user_id, me = _user(client, "alice01", "쥐돌이")
    response = _request(client, me, _code(user_id))
    assert response.status_code == 400
    assert response.json() == {"detail": "cannot_add_self"}


def test_decline_deletes_the_request_and_only_the_one_asked_answers(client, two):
    (a_id, a), (b_id, b) = two
    request_id = _request(client, a, _code(b_id)).json()["request_id"]
    # The sender cannot accept their own request.
    own = client.post(f"/friends/requests/{request_id}/accept", **a)
    assert own.status_code == 404
    declined = client.post(f"/friends/requests/{request_id}/decline", **b)
    assert declined.json() == {"status": "declined"}
    assert FriendRequest.objects.count() == 0
    gone = client.post(f"/friends/requests/{request_id}/accept", **b)
    assert gone.json() == {"detail": "request_not_found"}
    # Declined: the sender may ask again.
    assert _request(client, a, _code(b_id)).status_code == 201


def test_an_accepted_request_cannot_be_declined(client, two):
    (a_id, a), (b_id, b) = two
    _befriend(client, (a_id, a), (b_id, b))
    request_id = FriendRequest.objects.get().id
    response = client.post(f"/friends/requests/{request_id}/decline", **b)
    assert response.status_code == 404
    assert are_friends(User.objects.get(id=a_id), User.objects.get(id=b_id))


def test_friends_are_listed_by_nickname(client):
    me_id, me = _user(client, "alice01", "쥐돌이")
    users = [_user(client, f"user000{n}", name) for n, name in enumerate("다가나")]
    for user in users:
        _befriend(client, (me_id, me), user)
    names = [f["nickname"] for f in client.get("/friends", **me).json()["friends"]]
    assert names == ["가", "나", "다"]


def test_invite_reaches_the_friend_and_accepting_opens_the_battle(client, two):
    (a_id, a), (b_id, b) = two
    _befriend(client, (a_id, a), (b_id, b))
    created = _invite(client, a, b_id, "squat")
    assert created.status_code == 201
    invite = created.json()
    assert invite["status"] == "pending"
    assert invite["exercise"] == "squat"
    assert invite["from"]["id"] == a_id and invite["to"]["id"] == b_id

    listed = client.get("/friends", **b).json()["invites"]
    assert [i["invite_id"] for i in listed] == [invite["invite_id"]]
    # The inviter does not see their own invite as one to answer.
    assert client.get("/friends", **a).json()["invites"] == []

    accepted = client.post(f"/friends/invites/{invite['invite_id']}/accept", **b)
    assert accepted.status_code == 200
    assert accepted.json()["status"] == "accepted"
    seen = client.get(f"/friends/invites/{invite['invite_id']}", **a).json()
    assert seen["status"] == "accepted"
    assert client.get("/friends", **b).json()["invites"] == []


def test_only_friends_can_be_invited(client, two):
    (_, a), (b_id, b) = two
    response = _invite(client, a, b_id)
    assert response.status_code == 403
    assert response.json() == {"detail": "not_friends"}
    # A request that is still open is not a friendship yet.
    _request(client, a, _code(b_id))
    assert _invite(client, a, b_id).status_code == 403
    assert _invite(client, a, 999999).status_code == 403


@pytest.mark.parametrize(
    "body, detail",
    [
        ({"friend_id": "2", "exercise": "push_up"}, "invalid_friend"),
        ({"friend_id": True, "exercise": "push_up"}, "invalid_friend"),
        ({"exercise": "push_up"}, "invalid_friend"),
        ({"friend_id": 2, "exercise": "plank"}, "invalid_exercise"),
        ({"friend_id": 2}, "invalid_exercise"),
    ],
)
def test_a_malformed_invite_is_refused(client, two, body, detail):
    (_, a), _ = two
    response = client.post("/friends/invites", body, format="json", **a)
    assert response.status_code == 400
    assert response.json() == {"detail": detail}


def test_an_invite_expires_after_a_minute(client, two):
    (a_id, a), (b_id, b) = two
    _befriend(client, (a_id, a), (b_id, b))
    invite_id = _invite(client, a, b_id).json()["invite_id"]
    FriendBattleInvite.objects.filter(id=invite_id).update(
        created_at=timezone.now() - INVITE_TTL - timedelta(seconds=1)
    )
    assert client.get("/friends", **b).json()["invites"] == []
    assert client.get(f"/friends/invites/{invite_id}", **a).json()["status"] == (
        "expired"
    )
    late = client.post(f"/friends/invites/{invite_id}/accept", **b)
    assert late.status_code == 410
    assert late.json() == {"detail": "invite_expired"}
    assert INVITE_TTL == timedelta(minutes=1)


def test_an_invite_just_inside_the_minute_is_still_open(client, two):
    (a_id, a), (b_id, b) = two
    _befriend(client, (a_id, a), (b_id, b))
    invite_id = _invite(client, a, b_id).json()["invite_id"]
    FriendBattleInvite.objects.filter(id=invite_id).update(
        created_at=timezone.now() - INVITE_TTL + timedelta(seconds=5)
    )
    assert len(client.get("/friends", **b).json()["invites"]) == 1
    assert client.post(f"/friends/invites/{invite_id}/accept", **b).status_code == 200


def test_decline_and_cancel_close_the_invite_once(client, two):
    (a_id, a), (b_id, b) = two
    _befriend(client, (a_id, a), (b_id, b))
    first = _invite(client, a, b_id).json()["invite_id"]
    declined = client.post(f"/friends/invites/{first}/decline", **b)
    assert declined.json()["status"] == "declined"
    assert client.get(f"/friends/invites/{first}", **a).json()["status"] == "declined"
    again = client.post(f"/friends/invites/{first}/accept", **b)
    assert again.status_code == 409
    assert again.json() == {"detail": "invite_closed"}

    second = _invite(client, a, b_id).json()["invite_id"]
    # Only the friend accepts or declines.
    assert client.post(f"/friends/invites/{second}/accept", **a).status_code == 404
    assert client.post(f"/friends/invites/{second}/decline", **a).status_code == 404
    cancelled = client.post(f"/friends/invites/{second}/cancel", **a)
    assert cancelled.json()["status"] == "cancelled"
    assert client.post(f"/friends/invites/{second}/accept", **b).status_code == 409
    assert client.post(f"/friends/invites/{second}/cancel", **a).status_code == 409


@pytest.mark.parametrize("leaver", ["inviter", "friend"])
def test_either_player_leaving_cancels_an_accepted_invite(client, two, leaver):
    (a_id, a), (b_id, b) = two
    _befriend(client, (a_id, a), (b_id, b))
    invite_id = _invite(client, a, b_id).json()["invite_id"]
    client.post(f"/friends/invites/{invite_id}/accept", **b)
    gone, stays = (a, b) if leaver == "inviter" else (b, a)
    left = client.post(f"/friends/invites/{invite_id}/cancel", **gone)
    assert left.status_code == 200
    seen = client.get(f"/friends/invites/{invite_id}", **stays).json()
    assert seen["status"] == "cancelled"


def test_the_friend_can_take_back_an_open_invite_too(client, two):
    (a_id, a), (b_id, b) = two
    _befriend(client, (a_id, a), (b_id, b))
    invite_id = _invite(client, a, b_id).json()["invite_id"]
    assert client.post(f"/friends/invites/{invite_id}/cancel", **b).status_code == 200


def test_an_expired_invite_cannot_be_cancelled(client, two):
    (a_id, a), (b_id, b) = two
    _befriend(client, (a_id, a), (b_id, b))
    invite_id = _invite(client, a, b_id).json()["invite_id"]
    FriendBattleInvite.objects.filter(id=invite_id).update(
        created_at=timezone.now() - INVITE_TTL
    )
    assert client.post(f"/friends/invites/{invite_id}/cancel", **a).status_code == 410


def test_a_new_invite_cancels_my_earlier_open_one(client):
    me_id, me = _user(client, "alice01", "쥐돌이")
    b = _user(client, "bobby01", "헬창")
    c = _user(client, "carol01", "근육")
    _befriend(client, (me_id, me), b)
    _befriend(client, (me_id, me), c)
    old = _invite(client, me, b[0]).json()["invite_id"]
    _invite(client, me, c[0])
    assert client.get(f"/friends/invites/{old}", **me).json()["status"] == "cancelled"
    assert client.get("/friends", **b[1]).json()["invites"] == []
    assert len(client.get("/friends", **c[1]).json()["invites"]) == 1


def test_an_invite_is_private_to_its_two_players(client, two):
    (a_id, a), (b_id, b) = two
    _befriend(client, (a_id, a), (b_id, b))
    invite_id = _invite(client, a, b_id).json()["invite_id"]
    _, stranger = _user(client, "carol01", "근육")
    for path in ("", "/accept", "/decline", "/cancel"):
        url = f"/friends/invites/{invite_id}{path}"
        call = client.get if path == "" else client.post
        response = call(url, **stranger)
        assert response.status_code == 404
        assert response.json() == {"detail": "invite_not_found"}
    assert client.get("/friends/invites/999999", **a).status_code == 404


def test_the_friends_list_shows_no_password_or_login_id(client, two):
    (a_id, a), (b_id, b) = two
    _befriend(client, (a_id, a), (b_id, b))
    _invite(client, a, b_id)
    text = str(client.get("/friends", **b).json())
    assert "alice01" not in text and "password" not in text


def test_only_the_invited_friend_accepts(client, two):
    (a_id, a), (b_id, b) = two
    _befriend(client, (a_id, a), (b_id, b))
    _, c = _user(client, "carol01", "근육")
    invite_id = _invite(client, a, b_id).json()["invite_id"]
    for someone in (a, c):
        response = client.post(f"/friends/invites/{invite_id}/accept", **someone)
        assert response.status_code == 404
    assert FriendBattleInvite.objects.get().status == FriendBattleInvite.PENDING
    assert client.post(f"/friends/invites/{invite_id}/accept", **b).status_code == 200


def test_accepting_twice_accepts_once(client, two):
    (a_id, a), (b_id, b) = two
    _befriend(client, (a_id, a), (b_id, b))
    invite_id = _invite(client, a, b_id).json()["invite_id"]
    first = client.post(f"/friends/invites/{invite_id}/accept", **b)
    second = client.post(f"/friends/invites/{invite_id}/accept", **b)
    assert first.status_code == 200
    assert second.status_code == 409
    assert second.json() == {"detail": "invite_closed"}
    assert FriendBattleInvite.objects.count() == 1
    assert FriendBattleInvite.objects.get().status == FriendBattleInvite.ACCEPTED


@pytest.mark.parametrize("closed", ["cancelled", "declined"])
def test_a_closed_invite_cannot_be_accepted(client, two, closed):
    (a_id, a), (b_id, b) = two
    _befriend(client, (a_id, a), (b_id, b))
    invite_id = _invite(client, a, b_id).json()["invite_id"]
    actor = a if closed == "cancelled" else b
    action = "cancel" if closed == "cancelled" else "decline"
    client.post(f"/friends/invites/{invite_id}/{action}", **actor)
    response = client.post(f"/friends/invites/{invite_id}/accept", **b)
    assert response.status_code == 409
    assert FriendBattleInvite.objects.get().status == closed


def test_tags_have_at_least_four_digits(client):
    user_id, _ = _user(client, "alice01", "쥐돌이")
    user = User.objects.get(id=user_id)
    for number, tag in ((42, "0042"), (7, "0007"), (10000, "10000"), (123456, "123456")):
        user.id = number
        assert friend_code(user) == f"쥐돌이#{tag}"


def test_the_database_keeps_one_request_per_pair_either_way(client, two):
    from django.db import IntegrityError, transaction

    (a_id, _), (b_id, _) = two
    a, b = User.objects.get(id=a_id), User.objects.get(id=b_id)
    FriendRequest.objects.create(from_user=a, to_user=b)
    # Two opposite requests that both passed the check at the same moment.
    with pytest.raises(IntegrityError), transaction.atomic():
        FriendRequest.objects.create(from_user=b, to_user=a)
    assert FriendRequest.objects.count() == 1


def test_a_request_racing_the_reverse_one_says_already_requested(client, two, monkeypatch):
    import accounts.friends_views as views

    (a_id, a), (b_id, b) = two
    # The reverse request lands between the check and the insert.
    real_pair = views._pair

    def late_pair(x, y):
        found = real_pair(x, y)
        if found is None:
            FriendRequest.objects.create(
                from_user=User.objects.get(id=b_id), to_user=User.objects.get(id=a_id)
            )
        return found

    monkeypatch.setattr(views, "_pair", late_pair)
    response = _request(client, a, _code(b_id))
    assert response.status_code == 409
    assert response.json() == {"detail": "already_requested"}


@pytest.mark.parametrize("winner, loser", [("accept", "decline"), ("decline", "accept")])
def test_two_answers_to_a_request_at_once_only_the_first_counts(
    client, two, monkeypatch, winner, loser
):
    import accounts.friends_views as views

    (a_id, a), (b_id, b) = two
    request_id = _request(client, a, _code(b_id)).json()["request_id"]
    real = views._answer_request

    # The other phone's answer lands between this answer's look-up and its
    # write.
    def raced(rid, me, *, accept):
        real(rid, me, accept=winner == "accept")
        return real(rid, me, accept=accept)

    monkeypatch.setattr(views, "_answer_request", raced)
    response = client.post(f"/friends/requests/{request_id}/{loser}", **b)
    assert response.status_code == 404
    assert response.json() == {"detail": "request_not_found"}
    friends = are_friends(User.objects.get(id=a_id), User.objects.get(id=b_id))
    assert friends is (winner == "accept")
    assert FriendRequest.objects.count() == (1 if winner == "accept" else 0)


def test_asking_back_while_the_request_is_answered_elsewhere(client, two, monkeypatch):
    import accounts.friends_views as views

    (a_id, a), (b_id, b) = two
    _request(client, a, _code(b_id))
    real = views._answer_request

    def raced(rid, me, *, accept):
        real(rid, me, accept=False)  # declined on b's other phone meanwhile
        return real(rid, me, accept=accept)

    monkeypatch.setattr(views, "_answer_request", raced)
    response = _request(client, b, _code(a_id))
    assert response.status_code == 404
    assert FriendRequest.objects.count() == 0


@pytest.mark.parametrize(
    "winner, loser, status",
    [
        ("accept", "decline", "accepted"),
        ("decline", "accept", "declined"),
        ("cancel", "accept", "cancelled"),
    ],
)
def test_two_answers_to_an_invite_at_once_only_the_first_counts(
    client, two, monkeypatch, winner, loser, status
):
    import accounts.friends_views as views

    from django.db.models import Q

    (a_id, a), (b_id, b) = two
    _befriend(client, (a_id, a), (b_id, b))
    invite_id = _invite(client, a, b_id).json()["invite_id"]
    real = views._answer_invite

    def raced(iid, mine, action, **options):
        either = Q(from_user_id=a_id) | Q(to_user_id=b_id)
        real(iid, either, winner)
        return real(iid, mine, action, **options)

    monkeypatch.setattr(views, "_answer_invite", raced)
    response = client.post(f"/friends/invites/{invite_id}/{loser}", **b)
    assert response.status_code == 409
    assert response.json() == {"detail": "invite_closed"}
    assert FriendBattleInvite.objects.get().status == status


def test_a_code_with_fewer_than_four_digits_finds_nobody(client, two):
    (_, a), (b_id, _) = two
    assert b_id < 10
    short = _request(client, a, f"헬창#{b_id}")
    assert short.status_code == 400
    assert short.json() == {"detail": "invalid_code"}
    assert _request(client, a, _code(b_id)).status_code == 201


def _three_friends(client):
    me = _user(client, "alice01", "쥐돌이")
    b = _user(client, "bobby01", "헬창")
    c = _user(client, "carol01", "근육")
    _befriend(client, me, b)
    _befriend(client, me, c)
    return me, b, c


def test_two_invites_at_once_from_two_phones_leave_one_open(client, monkeypatch):
    import accounts.friends_views as views

    (me_id, me), (b_id, _), (c_id, _) = _three_friends(client)
    real_cancel = views._cancel_open_invites
    cancels = []

    # The other phone's invite (to c) lands between this one's cancel and
    # its insert, once.
    def raced(user):
        real_cancel(user)
        cancels.append(user.id)
        if len(cancels) == 1:
            FriendBattleInvite.objects.create(
                from_user=user, to_user=User.objects.get(id=c_id), exercise="squat"
            )

    monkeypatch.setattr(views, "_cancel_open_invites", raced)
    response = _invite(client, me, b_id)
    assert response.status_code == 201
    assert cancels == [me_id, me_id]
    pending = FriendBattleInvite.objects.filter(status=FriendBattleInvite.PENDING)
    assert [(i.from_user_id, i.to_user_id) for i in pending] == [(me_id, b_id)]
    assert FriendBattleInvite.objects.get(to_user_id=c_id).status == "cancelled"


def test_an_invite_that_keeps_losing_the_race_gives_up(client, monkeypatch):
    import accounts.friends_views as views

    (_, me), (b_id, _), (c_id, _) = _three_friends(client)
    real_cancel = views._cancel_open_invites

    def always_raced(user):
        real_cancel(user)
        FriendBattleInvite.objects.create(
            from_user=user, to_user=User.objects.get(id=c_id), exercise="squat"
        )

    monkeypatch.setattr(views, "_cancel_open_invites", always_raced)
    response = _invite(client, me, b_id)
    assert response.status_code == 409
    assert response.json() == {"detail": "invite_busy"}
    assert FriendBattleInvite.objects.filter(status="pending").count() == 1


def test_the_database_keeps_one_open_invite_per_inviter(client):
    from django.db import IntegrityError, transaction

    (me_id, _), (b_id, _), (c_id, _) = _three_friends(client)
    me = User.objects.get(id=me_id)
    FriendBattleInvite.objects.create(
        from_user=me, to_user=User.objects.get(id=b_id), exercise="push_up"
    )
    with pytest.raises(IntegrityError), transaction.atomic():
        FriendBattleInvite.objects.create(
            from_user=me, to_user=User.objects.get(id=c_id), exercise="squat"
        )
    # Closed invites do not count.
    FriendBattleInvite.objects.update(status="declined")
    FriendBattleInvite.objects.create(
        from_user=me, to_user=User.objects.get(id=c_id), exercise="squat"
    )


def test_cancel_if_pending_leaves_an_accepted_invite(client, two):
    (a_id, a), (b_id, b) = two
    _befriend(client, (a_id, a), (b_id, b))
    invite_id = _invite(client, a, b_id).json()["invite_id"]
    client.post(f"/friends/invites/{invite_id}/accept", **b)
    # The inviter's cleanup after pairing has not seen the accept yet.
    response = client.post(
        f"/friends/invites/{invite_id}/cancel", {"if_pending": True}, format="json", **a
    )
    assert response.status_code == 409
    assert response.json() == {"detail": "invite_closed"}
    assert FriendBattleInvite.objects.get().status == "accepted"


def test_cancel_if_pending_takes_back_an_open_invite(client, two):
    (a_id, a), (b_id, b) = two
    _befriend(client, (a_id, a), (b_id, b))
    invite_id = _invite(client, a, b_id).json()["invite_id"]
    response = client.post(
        f"/friends/invites/{invite_id}/cancel", {"if_pending": True}, format="json", **a
    )
    assert response.status_code == 200
    assert response.json()["status"] == "cancelled"


def test_only_true_turns_on_if_pending(client, two):
    (a_id, a), (b_id, b) = two
    _befriend(client, (a_id, a), (b_id, b))
    invite_id = _invite(client, a, b_id).json()["invite_id"]
    client.post(f"/friends/invites/{invite_id}/accept", **b)
    response = client.post(
        f"/friends/invites/{invite_id}/cancel", {"if_pending": "yes"}, format="json", **a
    )
    assert response.status_code == 200
    assert FriendBattleInvite.objects.get().status == "cancelled"


@pytest.mark.parametrize("body", [[], [1, 2], "text", 3])
def test_an_odd_answer_body_is_ignored(client, two, body):
    (a_id, a), (b_id, b) = two
    _befriend(client, (a_id, a), (b_id, b))
    invite_id = _invite(client, a, b_id).json()["invite_id"]
    response = client.post(
        f"/friends/invites/{invite_id}/cancel", body, format="json", **a
    )
    assert response.status_code == 200
    assert response.json()["status"] == "cancelled"
