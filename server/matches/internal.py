# AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
"""P11: the battle server's result storage (protocol §8).

Only the battle server on the same machine calls these. Every request needs
the shared RESULTS_SECRET from /srv/gymrats/.env and must come straight from
loopback: nginx sets X-Forwarded-For on what it proxies, so a request that
went through /api/ is refused even though it also arrives from 127.0.0.1.
"""

import hmac
from datetime import datetime, timezone

from django.conf import settings
from django.db import IntegrityError, transaction
from django.db.models import Q
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import User

from .models import Match, OnlineBattle
from .serializers import (
    OnlineRecoverSerializer,
    OnlineResultSerializer,
    OnlineStartSerializer,
    OnlineVoidSerializer,
)

LOOPBACK = {"127.0.0.1", "::1"}


def _from_battle_server(request) -> bool:
    secret = getattr(settings, "RESULTS_SECRET", "")
    if len(secret) < 32:
        return False  # Not configured: the saver stays closed.
    if request.META.get("REMOTE_ADDR") not in LOOPBACK:
        return False
    if "HTTP_X_FORWARDED_FOR" in request.META:
        return False
    given = request.META.get("HTTP_X_RESULTS_SECRET", "")
    return hmac.compare_digest(given.encode(), secret.encode())


def _time(ms: int) -> datetime:
    return datetime.fromtimestamp(ms / 1000, tz=timezone.utc)


class _InternalView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def handle(self, request):
        raise NotImplementedError

    def post(self, request):
        if not _from_battle_server(request):
            return Response({"detail": "forbidden"}, status=status.HTTP_403_FORBIDDEN)
        return self.handle(request)


class BattleStartView(_InternalView):
    """Records a battle when its start time is fixed, so a restart can void it."""

    def handle(self, request):
        body = OnlineStartSerializer(data=request.data)
        body.is_valid(raise_exception=True)
        data = body.validated_data
        try:
            with transaction.atomic():
                _, created = OnlineBattle.objects.get_or_create(
                    match_id=data["match_id"],
                    defaults={
                        "player_ids": data["player_ids"],
                        "started_at": _time(data["started_at_ms"]),
                    },
                )
        except IntegrityError:
            created = False
        return Response(
            {"match_id": data["match_id"]},
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class BattleVoidView(_InternalView):
    """A battle that ended without a result (e.g. both players lost)."""

    def handle(self, request):
        body = OnlineVoidSerializer(data=request.data)
        body.is_valid(raise_exception=True)
        data = body.validated_data
        with transaction.atomic():
            battle, _ = OnlineBattle.objects.get_or_create(match_id=data["match_id"])
            if battle.status == OnlineBattle.FINISHED:
                return Response(
                    {"detail": "already_finished"}, status=status.HTTP_409_CONFLICT
                )
            battle.status = OnlineBattle.VOID
            battle.reason = data["reason"]
            battle.ended_at = battle.ended_at or datetime.now(timezone.utc)
            battle.save()
        return Response({"match_id": battle.match_id, "status": battle.status})


class BattleRecoverView(_InternalView):
    """Called once when the battle server starts: every battle it still had
    running is lost, so it becomes void and never a result."""

    def handle(self, request):
        body = OnlineRecoverSerializer(data=request.data)
        body.is_valid(raise_exception=True)
        # Battles the new process started itself are not lost, even when
        # this call arrives late (Django slow at boot).
        booted = _time(body.validated_data["booted_at_ms"])
        with transaction.atomic():
            lost = list(
                OnlineBattle.objects.select_for_update().filter(
                    Q(started_at__lt=booted) | Q(started_at__isnull=True),
                    status=OnlineBattle.ACTIVE,
                )
            )
            OnlineBattle.objects.filter(id__in=[b.id for b in lost]).update(
                status=OnlineBattle.VOID,
                reason="server_restarted",
                ended_at=datetime.now(timezone.utc),
            )
        return Response(
            {
                "voided": [
                    {"match_id": b.match_id, "player_ids": b.player_ids} for b in lost
                ]
            }
        )


class ResultSaveView(_InternalView):
    """The P11 saver: one Match row per player, once per result_id."""

    def handle(self, request):
        body = OnlineResultSerializer(data=request.data)
        body.is_valid(raise_exception=True)
        data = body.validated_data
        try:
            with transaction.atomic():
                return self._save(data)
        except IntegrityError:
            if OnlineBattle.objects.filter(result_id=data["result_id"]).exists():
                # A retry raced with the first call; that one stored it.
                return Response({"result_id": data["result_id"], "saved": 0})
            raise

    def _save(self, data):
        result_id = data["result_id"]
        if OnlineBattle.objects.filter(result_id=result_id).exists():
            return Response({"result_id": result_id, "saved": 0})
        battle, _ = OnlineBattle.objects.select_for_update().get_or_create(
            match_id=data["match_id"]
        )
        if battle.status == OnlineBattle.VOID:
            # Voided by a restart; a late result must not revive it.
            return Response({"detail": "match_void"}, status=status.HTTP_409_CONFLICT)
        if battle.result_id is not None:
            return Response(
                {"detail": "result_conflict"}, status=status.HTTP_409_CONFLICT
            )
        players = data["players"]
        ended_at = _time(data["ended_at_ms"])
        battle.result_id = result_id
        battle.status = OnlineBattle.FINISHED
        battle.reason = data["reason"]
        battle.player_ids = [p["player_id"] for p in players]
        battle.ended_at = ended_at
        battle.save()

        users = User.objects.in_bulk([int(p["player_id"]) for p in players])
        saved = 0
        for me, other in ((players[0], players[1]), (players[1], players[0])):
            user = users.get(int(me["player_id"]))
            if user is None:
                continue  # Account deleted since the battle.
            # The server's numbers always win: a row an app posted itself
            # under this result_id (POST /matches) is overwritten.
            Match.objects.update_or_create(
                user=user,
                client_id=result_id,
                defaults={
                    "exercise": "push_up",
                    "opponent_name": other["display_name"][:40],
                    "my_reps": me["valid_reps"],
                    "opponent_reps": other["valid_reps"],
                    "played_at": ended_at,
                    "outcome": me["outcome"],
                    "reason": data["reason"],
                },
            )
            saved += 1
        return Response(
            {"result_id": result_id, "saved": saved}, status=status.HTTP_201_CREATED
        )
