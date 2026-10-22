"""Saving finished battles and reading them back, newest first."""

from django.db import IntegrityError, transaction
from django.db.models import Q
from rest_framework import serializers, status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Match
from .serializers import MatchInSerializer, MatchSerializer


class PageQuery(serializers.Serializer):
    limit = serializers.IntegerField(min_value=1, max_value=50, default=20)
    # next_before of the last page.
    before = serializers.IntegerField(required=False)


class MatchListView(APIView):
    def post(self, request):
        """Stores a battle. Sending the same client_id again returns the
        stored one with 200 instead of a copy, so the app can retry safely."""
        body = MatchInSerializer(data=request.data)
        body.is_valid(raise_exception=True)
        mine = Match.objects.filter(user=request.user)
        client_id = body.validated_data["client_id"]

        if (match := mine.filter(client_id=client_id).first()) is not None:
            return Response(MatchSerializer(match).data)
        try:
            with transaction.atomic():
                match = body.save(user=request.user)
        except IntegrityError:
            # Two uploads of the same battle raced; the other one won.
            match = mine.get(client_id=client_id)
            return Response(MatchSerializer(match).data)
        return Response(MatchSerializer(match).data, status=status.HTTP_201_CREATED)

    def get(self, request):
        query = PageQuery(data=request.query_params)
        query.is_valid(raise_exception=True)
        limit = query.validated_data["limit"]
        before = query.validated_data.get("before")

        matches = Match.objects.filter(user=request.user)
        if before is not None:
            cursor = matches.filter(id=before).first()
            if cursor is None:
                # Unknown, or another user's match.
                return Response(
                    {"detail": "invalid_cursor"}, status=status.HTTP_400_BAD_REQUEST
                )
            matches = matches.filter(
                Q(played_at__lt=cursor.played_at)
                | Q(played_at=cursor.played_at, id__lt=cursor.id)
            )
        rows = list(matches.order_by("-played_at", "-id")[: limit + 1])
        page = rows[:limit]
        return Response(
            {
                "items": MatchSerializer(page, many=True).data,
                "next_before": page[-1].id if len(rows) > limit else None,
            }
        )
