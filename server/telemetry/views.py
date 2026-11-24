"""P17: where the telemetry events are stored.

- POST /telemetry/events: the signed-in app sends a batch of its events.
  The server adds the account; the app never sends it.
- POST /internal/telemetry/battle: the battle server records battle_finished,
  with the same loopback-and-secret check as the P11 result saver.

Both store an event once: a resend of the same event_id, or a second
battle_finished for the same match_id, is a duplicate and changes nothing.
"""

from django.db import IntegrityError, transaction
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from matches.internal import _from_battle_server

from .models import TelemetryEvent
from .serializers import APP_SERIALIZERS, COLUMNS, Batch, BattleFinished


def _save(fields, user=None) -> bool:
    """Stores one validated event; False when it was already stored."""
    row = {k: v for k, v in fields.items() if k in COLUMNS}
    data = {k: v for k, v in fields.items() if k not in COLUMNS}
    try:
        with transaction.atomic():
            TelemetryEvent.objects.create(user=user, data=data, **row)
    except IntegrityError:
        return False
    return True


class EventBatchView(APIView):
    def post(self, request):
        batch = Batch(data=request.data)
        batch.is_valid(raise_exception=True)
        stored, duplicates, rejected = 0, 0, []
        for i, event in enumerate(batch.validated_data["events"]):
            serializer = APP_SERIALIZERS.get(event.get("event"))
            body = serializer(data=event) if serializer else None
            if body is None or not body.is_valid():
                # Dropped, not retried: the same event would fail again.
                rejected.append(i)
                continue
            if _save(body.validated_data, user=request.user):
                stored += 1
            else:
                duplicates += 1
        return Response(
            {"stored": stored, "duplicates": duplicates, "rejected": rejected}
        )


class BattleFinishedView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        if not _from_battle_server(request):
            return Response({"detail": "forbidden"}, status=status.HTTP_403_FORBIDDEN)
        body = BattleFinished(data=request.data)
        body.is_valid(raise_exception=True)
        fields = dict(body.validated_data)
        fields["scores"] = [dict(s) for s in fields["scores"]]
        created = _save(fields)
        return Response(
            {"match_id": fields["match_id"], "stored": created},
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )
