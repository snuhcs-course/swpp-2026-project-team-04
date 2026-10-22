from rest_framework import serializers

from .models import Match


class AwareDateTimeField(serializers.DateTimeField):
    """A time that must carry its time zone; stored and returned in UTC."""

    def enforce_timezone(self, value):
        if value.tzinfo is None:
            raise serializers.ValidationError("played_at needs a time zone")
        return super().enforce_timezone(value)


class MatchInSerializer(serializers.ModelSerializer):
    client_id = serializers.CharField(min_length=8, max_length=36)
    exercise = serializers.ChoiceField(choices=["push_up"])
    opponent_name = serializers.CharField(min_length=1, max_length=40)
    my_reps = serializers.IntegerField(min_value=0, max_value=1000)
    opponent_reps = serializers.IntegerField(min_value=0, max_value=1000)
    played_at = AwareDateTimeField()

    class Meta:
        model = Match
        fields = [
            "client_id",
            "exercise",
            "opponent_name",
            "my_reps",
            "opponent_reps",
            "played_at",
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
        ]
