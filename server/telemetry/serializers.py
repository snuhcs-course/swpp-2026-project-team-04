"""The P6 event dictionary as validation rules.

Every event carries the common fields and exactly its own fields: an
unknown field is refused, so nothing outside the dictionary (a frame, a
joint, a token) can be stored by mistake.
"""

from rest_framework import serializers

from .models import APP_EVENTS, BATTLE_FINISHED

EXERCISES = ["push_up", "squat"]
SETUP_REASONS = [
    "no_person",
    "too_close",
    "too_far",
    "not_facing_forward",
    "missing_parts",
    "not_in_push_up",
    "not_standing",
    "phone_too_flat",
    "phone_shaky",
]
# A day: anything longer is a clock or client bug, not a measurement.
MAX_MS = 24 * 60 * 60 * 1000


def _ms():
    return serializers.IntegerField(min_value=0, max_value=MAX_MS)


def _id():
    return serializers.CharField(min_length=1, max_length=64)


class _Common(serializers.Serializer):
    event = serializers.ChoiceField(choices=[*APP_EVENTS, BATTLE_FINISHED])
    event_id = serializers.UUIDField()
    ts = serializers.DateTimeField()

    def validate(self, attrs):
        extra = set(self.initial_data) - set(self.fields)
        if extra:
            raise serializers.ValidationError(
                {"unknown_fields": sorted(extra)}
            )
        return attrs


class _AppCommon(_Common):
    session_id = _id()
    app_version = serializers.CharField(max_length=32, allow_blank=True)
    attempt_id = _id()


class TutorialStarted(_AppCommon):
    pages_total = serializers.IntegerField(min_value=1, max_value=100)


class TutorialFinished(_AppCommon):
    result = serializers.ChoiceField(choices=["completed", "skipped"])
    duration_ms = _ms()
    last_page = serializers.IntegerField(min_value=1, max_value=100)


class SetupStarted(_AppCommon):
    exercise = serializers.ChoiceField(choices=EXERCISES)
    mode = serializers.ChoiceField(choices=["bot", "main", "friend"])


class SetupFinished(_AppCommon):
    result = serializers.ChoiceField(choices=["ready", "timeout", "cancelled"])
    duration_ms = _ms()
    # Only the online setups have a time limit.
    limit_ms = serializers.IntegerField(min_value=0, max_value=MAX_MS, allow_null=True)
    # The last thing the checker asked for; null when it was never unready.
    last_reason = serializers.ChoiceField(choices=SETUP_REASONS, allow_null=True)


class MatchingStarted(_AppCommon):
    exercise = serializers.ChoiceField(choices=EXERCISES)
    kind = serializers.ChoiceField(choices=["main", "friend"])


class MatchingFinished(_AppCommon):
    result = serializers.ChoiceField(
        choices=["found", "cancelled", "timeout", "error"]
    )
    wait_ms = _ms()


class _Score(serializers.Serializer):
    player_id = _id()
    game_score = serializers.IntegerField()
    valid_reps = serializers.IntegerField(min_value=0)


class BattleFinished(_Common):
    match_id = _id()
    # The battle server's own end codes (docs/iteration-5/telemetry-events.md).
    end_reason = serializers.CharField(min_length=1, max_length=32)
    status = serializers.ChoiceField(choices=["finished", "cancelled", "void"])
    duration_ms = _ms()
    exercise = serializers.ChoiceField(choices=EXERCISES)
    kind = serializers.ChoiceField(choices=["main", "friend"])
    scores = _Score(many=True, allow_empty=True)

    def validate_scores(self, value):
        if len(value) > 2:
            raise serializers.ValidationError("two_players_at_most")
        return value


APP_SERIALIZERS = {
    "tutorial_started": TutorialStarted,
    "tutorial_finished": TutorialFinished,
    "setup_started": SetupStarted,
    "setup_finished": SetupFinished,
    "matching_started": MatchingStarted,
    "matching_finished": MatchingFinished,
}

# The fields kept as the row's columns; the rest go to `data`.
COLUMNS = {"event", "event_id", "ts", "session_id", "app_version", "attempt_id", "match_id"}


class Batch(serializers.Serializer):
    # Up to the app's batch size; a bigger body is refused whole.
    events = serializers.ListField(
        child=serializers.DictField(), min_length=1, max_length=100
    )
