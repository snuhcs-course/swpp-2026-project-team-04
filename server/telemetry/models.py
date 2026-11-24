"""P17: the telemetry events of P6's event dictionary.

One row per event. The app sends six of them (tutorial, pose setup and
matching, each as a start and an end joined by attempt_id); the battle
server records battle_finished once per match. Only the dictionary's fields
are kept: never camera frames, joint coordinates or credentials.
"""

from django.conf import settings
from django.db import models

APP_EVENTS = (
    "tutorial_started",
    "tutorial_finished",
    "setup_started",
    "setup_finished",
    "matching_started",
    "matching_finished",
)
BATTLE_FINISHED = "battle_finished"


class TelemetryEvent(models.Model):
    # Made by whoever records the event; a resend of the same id is the
    # same event and is stored once.
    event_id = models.UUIDField(unique=True)
    event = models.CharField(max_length=32, db_index=True)
    # The signed-in sender of an app event; null for battle_finished.
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="+",
    )
    # A new random value every time the app starts.
    session_id = models.CharField(max_length=64, blank=True)
    # Joins a start to its end; empty for battle_finished.
    attempt_id = models.CharField(max_length=64, blank=True, db_index=True)
    # battle_finished only, and once per match.
    match_id = models.CharField(max_length=64, null=True, blank=True, unique=True)
    ts = models.DateTimeField()
    app_version = models.CharField(max_length=32, blank=True)
    # The event's own fields from the dictionary (result, duration_ms, ...).
    data = models.JSONField(default=dict)
    received_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["ts", "id"]
