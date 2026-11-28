"""Weekly rankings (Iteration 5, P11).

GET /matches/rankings/weekly?scope=global|friends&exercise=push_up|squat ranks
players by the points of this week's online battles of that exercise (push-ups
and squats are ranked apart): a KO win 10, any other win 5 (an opponent's
forfeit or disconnect included), a draw 3, a loss 1, and 0 for a loss by
one's own forfeit or disconnect. A week starts on Monday 00:00 KST.

Only battles the battle server stored count (their client_id is a finished
main OnlineBattle's result_id that names this player), so a battle an app posts
itself, against the AI or in the arcade, never does. A simulated opponent
keeps no row (P10), so only the real player of such a battle scores.

Friend battles never count (OnlineBattle.kind), nor do battles of unknown
kind (stored before kinds, or by an older battle server). The database sums
and ranks the points, so a request reads the top rows only. The friends scope
takes the same weekly points and ranks only me and my friends.
"""

from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from django.db.models import (
    Case,
    CharField,
    Count,
    Exists,
    F,
    OuterRef,
    Q,
    Sum,
    TextField,
    Value,
    When,
    Window,
)
from django.db.models.functions import Cast, Concat, Rank
from django.utils import timezone
from rest_framework import serializers
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import FriendRequest, User

from .models import Match, OnlineBattle

WEEK_ZONE = ZoneInfo("Asia/Seoul")
KO_WIN, WIN, DRAW, LOSS, LEFT = 10, 5, 3, 1, 0
# How many rows the global scope lists; my own row comes apart from them.
GLOBAL_LIMIT = 50


class RankingQuery(serializers.Serializer):
    scope = serializers.ChoiceField(choices=["global", "friends"], default="global")
    exercise = serializers.ChoiceField(choices=["push_up", "squat"], default="push_up")


def week_bounds(now):
    """The KST week holding [now]: Monday 00:00 up to the next Monday."""
    local = now.astimezone(WEEK_ZONE)
    start = datetime(local.year, local.month, local.day, tzinfo=WEEK_ZONE) - timedelta(
        days=local.weekday()
    )
    return start, start + timedelta(days=7)


def points(outcome, reason):
    """A battle's weekly points for the player whose [outcome] it is.

    The database sums the same rule as _POINTS; change both together."""
    if outcome == "win":
        return KO_WIN if reason == "ko" else WIN
    if outcome == "draw":
        return DRAW
    return LEFT if reason in ("forfeit", "disconnect_timeout") else LOSS


def _counted(start, end, exercise):
    """This week's Match rows of [exercise] that score: each is a player's
    row of a finished main battle the battle server stored and that names
    this player (a row of someone else's battle is not theirs to count)."""
    me_quoted = Concat(Value('"'), Cast(OuterRef("user_id"), CharField()), Value('"'))
    battles = (
        OnlineBattle.objects.filter(
            result_id=OuterRef("client_id"),
            status=OnlineBattle.FINISHED,
            kind=OnlineBattle.MAIN,
        )
        # player_ids is a JSON list of id strings: ["3", "7"].
        .annotate(ids=Cast("player_ids", TextField()))
        .filter(ids__contains=me_quoted)
    )
    return Match.objects.filter(
        played_at__gte=start, played_at__lt=end, exercise=exercise
    ).filter(Exists(battles))


# points() as SQL, so the database sums a week's points; change both together.
_POINTS = Case(
    When(outcome="win", reason="ko", then=Value(KO_WIN)),
    When(outcome="win", then=Value(WIN)),
    When(outcome="draw", then=Value(DRAW)),
    When(reason__in=["forfeit", "disconnect_timeout"], then=Value(LEFT)),
    default=Value(LOSS),
)


def _tallies(rows):
    """Per player: points, battles, wins and KO wins, summed by the database."""
    return rows.values("user_id", nickname=F("user__nickname")).annotate(
        points=Sum(_POINTS),
        battles=Count("id"),
        wins=Count("id", filter=Q(outcome="win")),
        ko_wins=Count("id", filter=Q(outcome="win", reason="ko")),
    )


def _row(tally, rank, me_id):
    return {
        "user_id": tally["user_id"],
        "nickname": tally["nickname"],
        "points": tally["points"],
        "battles": tally["battles"],
        "wins": tally["wins"],
        "ko_wins": tally["ko_wins"],
        "rank": rank,
        "is_me": tally["user_id"] == me_id,
    }


def _friend_ids(me):
    pairs = FriendRequest.objects.filter(
        Q(from_user=me) | Q(to_user=me), accepted_at__isnull=False
    ).values_list("from_user_id", "to_user_id")
    return {b if a == me.id else a for a, b in pairs}


def _ranked(people, tallies, me_id):
    """Rows of [people] by points, then nickname and id; equal points share
    a rank (1, 1, 3). Those without a tally have 0."""
    empty = {"points": 0, "battles": 0, "wins": 0, "ko_wins": 0}
    rows = sorted(
        (
            {"user_id": u.id, "nickname": u.nickname, **tallies.get(u.id, empty)}
            for u in people
        ),
        key=lambda r: (-r["points"], r["nickname"], r["user_id"]),
    )
    rank, last = 0, None
    for i, row in enumerate(rows, start=1):
        if row["points"] != last:
            rank, last = i, row["points"]
        row["rank"] = rank
        row["is_me"] = row["user_id"] == me_id
    return rows


class WeeklyRankingView(APIView):
    def get(self, request):
        query = RankingQuery(data=request.query_params)
        query.is_valid(raise_exception=True)
        scope = query.validated_data["scope"]
        exercise = query.validated_data["exercise"]
        me = request.user
        start, end = week_bounds(timezone.now())
        rows = _counted(start, end, exercise)
        if scope == "friends":
            # Me and every friend, with or without a battle this week.
            ids = _friend_ids(me) | {me.id}
            keys = ("points", "battles", "wins", "ko_wins")
            tallies = {
                t["user_id"]: {k: t[k] for k in keys}
                for t in _tallies(rows.filter(user_id__in=ids))
            }
            entries = _ranked(User.objects.filter(id__in=ids), tallies, me.id)
            mine = next(r for r in entries if r["is_me"])
        else:
            # Only players with a battle this week; the database ranks them
            # and hands over the top only.
            tallies = _tallies(rows)
            top = tallies.annotate(
                rank=Window(Rank(), order_by=F("points").desc())
            ).order_by("-points", "nickname", "user_id")[:GLOBAL_LIMIT]
            entries = [_row(t, t["rank"], me.id) for t in top]
            mine = next((r for r in entries if r["is_me"]), None)
            if mine is None:
                own = next(iter(tallies.filter(user_id=me.id)), None)
                if own is not None:
                    ahead = tallies.filter(points__gt=own["points"]).count()
                    mine = _row(own, ahead + 1, me.id)
        return Response(
            {
                "scope": scope,
                "exercise": exercise,
                "week_start": start.isoformat(),
                "week_end": end.isoformat(),
                "entries": entries,
                "me": mine,
            }
        )
