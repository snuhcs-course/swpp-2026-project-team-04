"""Saving finished battles and reading them back, newest first."""

from django.db import IntegrityError, transaction
from django.db.models import Q
from rest_framework import serializers, status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Match, MatchFeedback, OnlineBattle, outcome_from_reps
from .serializers import FeedbackInSerializer, MatchInSerializer, MatchSerializer


class PageQuery(serializers.Serializer):
    limit = serializers.IntegerField(min_value=1, max_value=50, default=20)
    # next_before of the last page.
    before = serializers.IntegerField(required=False)


# AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
def _not_found():
    return Response({"detail": "not_found"}, status=status.HTTP_404_NOT_FOUND)


# AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
def _keep_first_feedback(user, client_id, feedback):
    """Stores feedback unless this battle already has some, so a retried
    upload never replaces or duplicates it."""
    try:
        with transaction.atomic():
            MatchFeedback.objects.get_or_create(
                user=user, client_id=client_id, defaults=feedback
            )
    except IntegrityError:
        pass  # A parallel upload of the same battle stored it first.


# AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
def _list_item(match, feedback):
    item = MatchSerializer(match).data
    item["has_feedback"] = feedback is not None
    item["feedback_summary"] = feedback.summary if feedback is not None else None
    return item


class MatchListView(APIView):
    def post(self, request):
        """Stores a battle. Sending the same client_id again returns the
        stored one with 200 instead of a copy, so the app can retry safely."""
        body = MatchInSerializer(data=request.data)
        body.is_valid(raise_exception=True)
        feedback = body.validated_data.pop("feedback", None)
        mine = Match.objects.filter(user=request.user)
        client_id = body.validated_data["client_id"]
        data = body.validated_data
        # An app that sends no result goes by the reps and time_up.
        outcome = data.get("outcome") or outcome_from_reps(
            data["my_reps"], data["opponent_reps"]
        )

        if OnlineBattle.objects.filter(result_id=client_id).exists():
            # Online results come only from the battle server (P11).
            return Response(
                {"detail": "online_result"}, status=status.HTTP_409_CONFLICT
            )
        created = False
        if (match := mine.filter(client_id=client_id).first()) is None:
            try:
                with transaction.atomic():
                    match = body.save(
                        user=request.user,
                        outcome=outcome,
                        reason=data.get("reason", "time_up"),
                    )
                    created = True
            except IntegrityError:
                # Two uploads of the same battle raced; the other one won.
                match = mine.get(client_id=client_id)
        if feedback is not None:
            _keep_first_feedback(request.user, client_id, feedback)
        return Response(
            MatchSerializer(match).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )

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
        # One query for the page's feedback; the reports stay in the DB.
        feedback = {
            f.client_id: f
            for f in MatchFeedback.objects.filter(
                user=request.user, client_id__in=[m.client_id for m in page]
            ).only("client_id", "summary")
        }
        return Response(
            {
                "items": [_list_item(m, feedback.get(m.client_id)) for m in page],
                "next_before": page[-1].id if len(rows) > limit else None,
            }
        )


# AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
class FeedbackUploadView(APIView):
    def put(self, request, client_id):
        """Stores the user's form report for a battle. Online battles use the
        battle server's result_id; the match row may not exist yet."""
        if not 8 <= len(client_id) <= 36:
            return _not_found()
        body = FeedbackInSerializer(data=request.data)
        body.is_valid(raise_exception=True)
        try:
            with transaction.atomic():
                _, created = MatchFeedback.objects.update_or_create(
                    user=request.user, client_id=client_id, defaults=body.validated_data
                )
        except IntegrityError:
            # A parallel upload created it; this one replaces it.
            MatchFeedback.objects.filter(
                user=request.user, client_id=client_id
            ).update(**body.validated_data)
            created = False
        return Response(
            {"client_id": client_id, "summary": body.validated_data["summary"]},
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


# AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
class MatchFeedbackView(APIView):
    def get(self, request, match_id):
        """The full report of one of the user's own battles."""
        match = Match.objects.filter(user=request.user, id=match_id).first()
        if match is None:
            return _not_found()
        feedback = MatchFeedback.objects.filter(
            user=request.user, client_id=match.client_id
        ).first()
        if feedback is None:
            return _not_found()
        return Response(
            {"match_id": match.id, "summary": feedback.summary, "report": feedback.report}
        )
