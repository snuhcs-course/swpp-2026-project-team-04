"""Friends and friend battle invites (Iteration 5, P9).

A user is found by their friend code, "<nickname>#<tag>", where the tag is
their account id padded to four digits ("쥐돌이#0042"). Nicknames repeat, so
the id tells them apart; the nickname must match too, so a mistyped or
guessed number finds nobody.

A battle invite is open for INVITE_TTL. The inviter's app waits in the
battle server's queue for the friend and reads the invite's status; the
friend sees it in GET /friends and accepts it, then joins the queue for the
inviter. The battle server pairs only two players who named each other.
"""

import re
from datetime import timedelta

from django.db import IntegrityError, transaction
from django.db.models import Q
from django.utils import timezone
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import FriendBattleInvite, FriendRequest, User

INVITE_TTL = timedelta(minutes=1)

# The tag as friend_code shows it: at least four digits ("#0042", "#10000").
# Any nickname sign-up allows, line breaks included (DOTALL), so every
# shown code can be read back.
_CODE = re.compile(r"\A(?P<nickname>.{1,12})#(?P<tag>[0-9]{4,10})\Z", re.DOTALL)


def friend_code(user):
    return f"{user.nickname}#{user.id:04d}"


def _person(user):
    return {"id": user.id, "nickname": user.nickname, "code": friend_code(user)}


def _error(detail, code):
    return Response({"detail": detail}, status=code)


def _expires_at(invite):
    return invite.created_at + INVITE_TTL


def _invite_status(invite):
    if invite.status == FriendBattleInvite.PENDING and timezone.now() >= _expires_at(
        invite
    ):
        return "expired"
    return invite.status


def _invite(invite):
    return {
        "invite_id": invite.id,
        "from": _person(invite.from_user),
        "to": _person(invite.to_user),
        "exercise": invite.exercise,
        "status": _invite_status(invite),
        "expires_at": _expires_at(invite).isoformat(),
    }


def _pair(a, b):
    """The request between [a] and [b], either way; None when there is none."""
    return FriendRequest.objects.filter(
        Q(from_user=a, to_user=b) | Q(from_user=b, to_user=a)
    ).first()


def are_friends(a, b):
    request = _pair(a, b)
    return request is not None and request.accepted_at is not None


class FriendsView(APIView):
    """GET /friends: my code, friends, open requests and invites to me."""

    def get(self, request):
        me = request.user
        requests = FriendRequest.objects.filter(
            Q(from_user=me) | Q(to_user=me)
        ).select_related("from_user", "to_user")
        friends, incoming, outgoing = [], [], []
        for r in requests.order_by("created_at"):
            other = r.to_user if r.from_user_id == me.id else r.from_user
            if r.accepted_at is not None:
                friends.append(_person(other))
            elif r.to_user_id == me.id:
                incoming.append({"request_id": r.id, "from": _person(other)})
            else:
                outgoing.append({"request_id": r.id, "to": _person(other)})
        friends.sort(key=lambda p: (p["nickname"], p["id"]))
        open_since = timezone.now() - INVITE_TTL
        invites = (
            FriendBattleInvite.objects.filter(
                to_user=me,
                status=FriendBattleInvite.PENDING,
                created_at__gt=open_since,
            )
            .select_related("from_user", "to_user")
            .order_by("-created_at")
        )
        return Response(
            {
                "code": friend_code(me),
                "friends": friends,
                "incoming": incoming,
                "outgoing": outgoing,
                "invites": [_invite(i) for i in invites],
            }
        )


class FriendRequestsView(APIView):
    """POST /friends/requests {"code"}: asks the code's owner to be friends.
    When they already asked me, this accepts their request instead."""

    def post(self, request):
        me = request.user
        code = request.data.get("code")
        match = _CODE.match(code.strip()) if isinstance(code, str) else None
        if match is None:
            return _error("invalid_code", status.HTTP_400_BAD_REQUEST)
        other = User.objects.filter(
            id=int(match["tag"]), nickname=match["nickname"]
        ).first()
        # Exactly the code shown, padding included: "헬창#00002" is not
        # "헬창#0002".
        if other is None or code.strip() != friend_code(other):
            return _error("user_not_found", status.HTTP_404_NOT_FOUND)
        if other.id == me.id:
            return _error("cannot_add_self", status.HTTP_400_BAD_REQUEST)
        with transaction.atomic():
            existing = _pair(me, other)
            if existing is not None:
                if existing.accepted_at is not None:
                    return _error("already_friends", status.HTTP_409_CONFLICT)
                if existing.from_user_id == me.id:
                    return _error("already_requested", status.HTTP_409_CONFLICT)
                # Their open request: accept it, unless another answer got
                # there first (one conditional write, see _answer_request).
                if not _answer_request(existing.id, me, accept=True):
                    return _error("request_not_found", status.HTTP_404_NOT_FOUND)
                return Response({"status": "accepted", "friend": _person(other)})
            try:
                with transaction.atomic():
                    created = FriendRequest.objects.create(
                        from_user=me, to_user=other
                    )
            # The same pair either way round, sent at the same moment.
            except IntegrityError:
                return _error("already_requested", status.HTTP_409_CONFLICT)
        return Response(
            {"status": "requested", "request_id": created.id, "to": _person(other)},
            status=status.HTTP_201_CREATED,
        )


def _answer_request(request_id, me, *, accept):
    """Accepts or declines the open request [request_id] to [me] in one
    conditional write, so of two answers at the same moment (two phones)
    only one changes it; False when it is not open any more."""
    still_open = FriendRequest.objects.filter(
        id=request_id, to_user=me, accepted_at__isnull=True
    )
    if accept:
        return still_open.update(accepted_at=timezone.now()) == 1
    deleted, _ = still_open.delete()
    return deleted == 1


class FriendRequestAnswerView(APIView):
    """POST /friends/requests/<id>/accept|decline, by the one asked. Only
    an open request changes; a second answer finds it gone (404)."""

    accept = True

    def post(self, request, request_id):
        sender = (
            FriendRequest.objects.filter(id=request_id, to_user=request.user)
            .select_related("from_user")
            .first()
        )
        if sender is None or not _answer_request(
            request_id, request.user, accept=self.accept
        ):
            return _error("request_not_found", status.HTTP_404_NOT_FOUND)
        if not self.accept:
            return Response({"status": "declined"})
        return Response({"status": "accepted", "friend": _person(sender.from_user)})


def _cancel_open_invites(user):
    """Cancels [user]'s open invites, before a new one."""
    FriendBattleInvite.objects.filter(
        from_user=user, status=FriendBattleInvite.PENDING
    ).update(status=FriendBattleInvite.CANCELLED)


class FriendInvitesView(APIView):
    """POST /friends/invites {"friend_id", "exercise"}: invites a friend to
    a battle. My earlier open invites are cancelled: one wait at a time."""

    def post(self, request):
        me = request.user
        friend_id, exercise = request.data.get("friend_id"), request.data.get(
            "exercise"
        )
        if not isinstance(friend_id, int) or isinstance(friend_id, bool):
            return _error("invalid_friend", status.HTTP_400_BAD_REQUEST)
        if exercise not in {"push_up", "squat"}:
            return _error("invalid_exercise", status.HTTP_400_BAD_REQUEST)
        friend = User.objects.filter(id=friend_id).first()
        if friend is None or not are_friends(me, friend):
            return _error("not_friends", status.HTTP_403_FORBIDDEN)
        # The database keeps one open invite per inviter; when another
        # phone's invite got in between, cancel that one too and try again,
        # so the latest invite is the open one.
        for _ in range(3):
            _cancel_open_invites(me)
            try:
                with transaction.atomic():
                    invite = FriendBattleInvite.objects.create(
                        from_user=me, to_user=friend, exercise=exercise
                    )
                break
            except IntegrityError:
                continue
        else:
            return _error("invite_busy", status.HTTP_409_CONFLICT)
        return Response(_invite(invite), status=status.HTTP_201_CREATED)


class FriendInviteView(APIView):
    """GET /friends/invites/<id>: the invite as either player sees it."""

    def get(self, request, invite_id):
        invite = (
            FriendBattleInvite.objects.filter(id=invite_id)
            .filter(Q(from_user=request.user) | Q(to_user=request.user))
            .select_related("from_user", "to_user")
            .first()
        )
        if invite is None:
            return _error("invite_not_found", status.HTTP_404_NOT_FOUND)
        return Response(_invite(invite))


def _answer_invite(invite_id, mine, action, *, if_pending=False):
    """Closes the invite [invite_id] by [action] in one conditional write, so
    of two answers at the same moment only the one that still finds it open
    changes it: accept and decline need it open and within its minute;
    cancel also takes an accepted one, unless [if_pending]. False when
    nothing changed."""
    still_open = Q(
        status=FriendBattleInvite.PENDING,
        created_at__gt=timezone.now() - INVITE_TTL,
    )
    if action == "cancel" and not if_pending:
        still_open |= Q(status=FriendBattleInvite.ACCEPTED)
    to = {
        "accept": FriendBattleInvite.ACCEPTED,
        "decline": FriendBattleInvite.DECLINED,
        "cancel": FriendBattleInvite.CANCELLED,
    }[action]
    return (
        FriendBattleInvite.objects.filter(mine, id=invite_id)
        .filter(still_open)
        .update(status=to)
        == 1
    )


class FriendInviteActionView(APIView):
    """POST /friends/invites/<id>/accept|decline, by the friend, while the
    invite is open; an expired one is 410. POST .../cancel, by either player
    leaving the waiting room: an open or an accepted invite, so the other
    one's waiting room learns that nobody is coming. With {"if_pending":
    true} it takes back only an invite still open (409 once accepted): the
    app's cleanup after two crossed invites met, which must not undo an
    accept it has not seen yet."""

    action = "accept"

    def post(self, request, invite_id):
        me = request.user
        mine = (
            Q(from_user=me) | Q(to_user=me)
            if self.action == "cancel"
            else Q(to_user=me)
        )
        body = request.data if isinstance(request.data, dict) else {}
        if_pending = body.get("if_pending") is True
        changed = _answer_invite(
            invite_id, mine, self.action, if_pending=if_pending
        )
        invite = (
            FriendBattleInvite.objects.filter(mine, id=invite_id)
            .select_related("from_user", "to_user")
            .first()
        )
        if invite is None:
            return _error("invite_not_found", status.HTTP_404_NOT_FOUND)
        if not changed:
            if _invite_status(invite) == "expired":
                return _error("invite_expired", status.HTTP_410_GONE)
            return _error("invite_closed", status.HTTP_409_CONFLICT)
        return Response(_invite(invite))
