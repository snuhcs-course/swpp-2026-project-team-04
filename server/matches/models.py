"""Finished battles, one row per user per battle."""

from django.conf import settings
from django.db import models


# AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
OUTCOMES = ["win", "loss", "draw"]
# Why a battle ended (protocol §8). Bot battles always run to time_up.
REASONS = ["time_up", "forfeit", "disconnect_timeout"]


class Match(models.Model):
    """A finished battle, seen from the user's side."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="matches"
    )
    # Chosen by the app, so it can retry an upload without duplicating it.
    # For online battles it is the battle server's result_id.
    client_id = models.CharField(max_length=36)
    exercise = models.CharField(max_length=20)
    opponent_name = models.CharField(max_length=40)
    my_reps = models.PositiveIntegerField()
    opponent_reps = models.PositiveIntegerField()
    played_at = models.DateTimeField()
    # A forfeit or disconnect is a loss whatever the reps, so the outcome is
    # stored instead of derived from them.
    outcome = models.CharField(max_length=8, default="draw")
    reason = models.CharField(max_length=20, default="time_up")

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["user", "client_id"], name="unique_match_per_client_id"
            )
        ]
        indexes = [models.Index(fields=["user", "-played_at", "-id"])]


# AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
def outcome_from_reps(my_reps: int, opponent_reps: int) -> str:
    if my_reps == opponent_reps:
        return "draw"
    return "win" if my_reps > opponent_reps else "loss"


# AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
class MatchFeedback(models.Model):
    """The form report the user's phone made for one battle.

    Keyed like Match by (user, client_id) and joined on read, so the report
    may arrive before or after the match row (online results come from the
    battle server, the report from the phone). Only derived measurements
    and normalized stick-figure poses; never camera frames or video.
    """

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="feedback"
    )
    client_id = models.CharField(max_length=36)
    # The one-line list summary: valid_reps, invalid_reps, accuracy,
    # top_issue, issue_count.
    summary = models.JSONField()
    # The full FormReport JSON, as the app's FormReport.toJson writes it.
    report = models.JSONField()
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["user", "client_id"], name="unique_feedback_per_client_id"
            )
        ]


# AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
class OnlineBattle(models.Model):
    """An online battle as the battle server reported it (P11).

    Recorded as active when it starts, so a battle-server restart can mark
    the ones it lost as void instead of guessing a result.
    """

    ACTIVE, FINISHED, VOID = "active", "finished", "void"

    match_id = models.CharField(max_length=64, unique=True)
    result_id = models.CharField(max_length=36, unique=True, null=True)
    status = models.CharField(max_length=10, default=ACTIVE)
    reason = models.CharField(max_length=30, blank=True, default="")
    # Battle-server player ids (Django user ids as strings).
    player_ids = models.JSONField(default=list)
    started_at = models.DateTimeField(null=True)
    ended_at = models.DateTimeField(null=True)
