"""Finished battles, one row per user per battle."""

from django.conf import settings
from django.db import models


class Match(models.Model):
    """A finished battle, seen from the user's side."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="matches"
    )
    # Chosen by the app, so it can retry an upload without duplicating it.
    client_id = models.CharField(max_length=36)
    exercise = models.CharField(max_length=20)
    opponent_name = models.CharField(max_length=40)
    my_reps = models.PositiveIntegerField()
    opponent_reps = models.PositiveIntegerField()
    played_at = models.DateTimeField()

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["user", "client_id"], name="unique_match_per_client_id"
            )
        ]
        indexes = [models.Index(fields=["user", "-played_at", "-id"])]
