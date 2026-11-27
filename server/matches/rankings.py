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

Friend battles never count (OnlineBattle.kind). The friends scope takes the
same weekly points and ranks only me and my friends.
"""

from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from django.db.models import OuterRef, Q, Subquery
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
    """A battle's weekly points for the player whose [outcome] it is."""
    if outcome == "win":
        return KO_WIN if reason == "ko" else WIN
    if outcome == "draw":
        return DRAW
    return LEFT if reason in ("forfeit", "disconnect_timeout") else LOSS


def _tally(start, end, exercise, user_ids=None):
    """{user_id: tally} of the [exercise]'s online battles played in
    [start, end)."""
    battles = OnlineBattle.objects.filter(
        result_id=OuterRef("client_id"),
        status=OnlineBattle.FINISHED,
        kind=OnlineBattle.MAIN,
    )
    rows = Match.objects.filter(
        played_at__gte=start, played_at__lt=end, exercise=exercise
    )
    if user_ids is not None:
        rows = rows.filter(user_id__in=user_ids)
    rows = rows.annotate(players=Subquery(battles.values("player_ids")[:1])).filter(
        players__isnull=False
    )
    tallies = {}
    for user_id, outcome, reason, players in rows.values_list(
        "user_id", "outcome", "reason", "players"
    ):
        # The saver names every player; a row of someone else's battle is not
        # this player's to count.
        if str(user_id) not in players:
            continue
        t = tallies.setdefault(
            user_id, {"points": 0, "battles": 0, "wins": 0, "ko_wins": 0}
        )
        t["points"] += points(outcome, reason)
        t["battles"] += 1
        if outcome == "win":
            t["wins"] += 1
            if reason == "ko":
                t["ko_wins"] += 1
    return tallies


def _friend_ids(me):
    pairs = FriendRequest.objects.filter(
        Q(from_user=me) | Q(to_user=me), accepted_at__isnull=False
    ).values_list("from_user_id", "to_user_id")
    return {b if a == me.id else a for a, b in pairs}


def _ranked(people, tallies, me_id):
    """Rows by points, then nickname and id; equal points share a rank
    (1, 1, 3)."""
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
        if scope == "friends":
            # Me and every friend, with or without a battle this week.
            ids = _friend_ids(me) | {me.id}
            tallies = _tally(start, end, exercise, ids)
            rows = _ranked(User.objects.filter(id__in=ids), tallies, me.id)
            mine = next(r for r in rows if r["is_me"])
        else:
            # Only players with a battle this week.
            tallies = _tally(start, end, exercise)
            rows = _ranked(User.objects.filter(id__in=tallies), tallies, me.id)
            mine = next((r for r in rows if r["is_me"]), None)
            rows = rows[:GLOBAL_LIMIT]
        return Response(
            {
                "scope": scope,
                "exercise": exercise,
                "week_start": start.isoformat(),
                "week_end": end.isoformat(),
                "entries": rows,
                "me": mine,
            }
        )
