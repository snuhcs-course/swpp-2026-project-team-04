import json

from rest_framework import serializers

from .models import OUTCOMES, REASONS, Match

# AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
# A 30 s round at 10 Hz is well under 100 KiB; nginx lets 1 MiB through.
MAX_REPORT_BYTES = 512 * 1024


class AwareDateTimeField(serializers.DateTimeField):
    """A time that must carry its time zone; stored and returned in UTC."""

    def enforce_timezone(self, value):
        if value.tzinfo is None:
            raise serializers.ValidationError("played_at needs a time zone")
        return super().enforce_timezone(value)


# AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
class FeedbackSummarySerializer(serializers.Serializer):
    """What a list row shows: made on the phone with FormAnalyzer."""

    valid_reps = serializers.IntegerField(min_value=0, max_value=1000)
    invalid_reps = serializers.IntegerField(min_value=0, max_value=1000)
    accuracy = serializers.FloatField(min_value=0, max_value=1, allow_null=True)
    top_issue = serializers.CharField(max_length=80, allow_null=True)
    issue_count = serializers.IntegerField(min_value=0, max_value=100)


# AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
class FeedbackInSerializer(serializers.Serializer):
    summary = FeedbackSummarySerializer()
    # The app's FormReport.toJson, stored as is so FeedbackScreen can be
    # rebuilt from it on any phone.
    report = serializers.JSONField()

    def validate_report(self, value):
        if not isinstance(value, dict):
            raise serializers.ValidationError("report must be an object")
        if not isinstance(value.get("version"), int) or any(
            not isinstance(value.get(key), list) for key in ("reps", "samples", "poses")
        ):
            raise serializers.ValidationError("not a form report")
        if len(json.dumps(value, separators=(",", ":"))) > MAX_REPORT_BYTES:
            raise serializers.ValidationError("report_too_large")
        return value


class MatchInSerializer(serializers.ModelSerializer):
    client_id = serializers.CharField(min_length=8, max_length=36)
    exercise = serializers.ChoiceField(choices=["push_up"])
    opponent_name = serializers.CharField(min_length=1, max_length=40)
    my_reps = serializers.IntegerField(min_value=0, max_value=1000)
    opponent_reps = serializers.IntegerField(min_value=0, max_value=1000)
    played_at = AwareDateTimeField()
    # Optional: the game's result. An app that sends none goes by the reps.
    outcome = serializers.ChoiceField(choices=OUTCOMES, required=False)
    reason = serializers.ChoiceField(choices=["time_up", "ko"], required=False)
    # Optional: the battle's form report, stored next to the match.
    feedback = FeedbackInSerializer(required=False)

    class Meta:
        model = Match
        fields = [
            "client_id",
            "exercise",
            "opponent_name",
            "my_reps",
            "opponent_reps",
            "played_at",
            "outcome",
            "reason",
            "feedback",
        ]
        # The (user, client_id) rule is handled by the view: a repeat
        # returns the stored battle instead of an error.
        validators = []


class MatchSerializer(serializers.ModelSerializer):
    class Meta:
        model = Match
        fields = [
            "id",
            "exercise",
            "opponent_name",
            "my_reps",
            "opponent_reps",
            "played_at",
            "outcome",
            "reason",
        ]


# AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
class OnlinePlayerSerializer(serializers.Serializer):
    player_id = serializers.RegexField(r"^[1-9][0-9]{0,18}$")
    display_name = serializers.CharField(min_length=1, max_length=80)
    valid_reps = serializers.IntegerField(min_value=0, max_value=1000)
    invalid_reps = serializers.IntegerField(min_value=0, max_value=1000)
    outcome = serializers.ChoiceField(choices=OUTCOMES)


# AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
class OnlineResultSerializer(serializers.Serializer):
    """match.finished as the battle server confirmed it (protocol §8)."""

    match_id = serializers.CharField(min_length=1, max_length=64)
    result_id = serializers.CharField(min_length=8, max_length=36)
    reason = serializers.ChoiceField(choices=REASONS)
    ended_at_ms = serializers.IntegerField(min_value=0, max_value=2**53)
    players = OnlinePlayerSerializer(many=True)

    def validate_players(self, value):
        if len(value) != 2 or value[0]["player_id"] == value[1]["player_id"]:
            raise serializers.ValidationError("two different players")
        outcomes = sorted(p["outcome"] for p in value)
        if outcomes not in (["draw", "draw"], ["loss", "win"]):
            raise serializers.ValidationError("outcomes do not match")
        return value


# AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
class OnlineStartSerializer(serializers.Serializer):
    match_id = serializers.CharField(min_length=1, max_length=64)
    started_at_ms = serializers.IntegerField(min_value=0, max_value=2**53)
    player_ids = serializers.ListField(
        child=serializers.CharField(max_length=20), min_length=2, max_length=2
    )


# AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
class OnlineVoidSerializer(serializers.Serializer):
    match_id = serializers.CharField(min_length=1, max_length=64)
    reason = serializers.CharField(min_length=1, max_length=30)


# AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
class OnlineRecoverSerializer(serializers.Serializer):
    # When the calling battle-server process started.
    booted_at_ms = serializers.IntegerField(min_value=0, max_value=2**53)
