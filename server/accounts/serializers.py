import math

from rest_framework import serializers
from rest_framework_simplejwt.tokens import AccessToken

from matches.serializers import MatchSerializer

from .models import User


class SignUpSerializer(serializers.Serializer):
    # The app checks the same rules (SignupRules).
    nickname = serializers.CharField(min_length=1, max_length=12, trim_whitespace=True)
    login_id = serializers.RegexField(r"^[a-z0-9_]{4,20}$", trim_whitespace=False)
    password = serializers.CharField(min_length=8, max_length=64, trim_whitespace=False)


class LoginSerializer(serializers.Serializer):
    login_id = serializers.CharField(trim_whitespace=False)
    password = serializers.CharField(trim_whitespace=False)


class _SocialLoginSerializer(serializers.Serializer):
    # Only for a new account; the same rule as SignUpSerializer.nickname.
    nickname = serializers.CharField(
        min_length=1, max_length=12, trim_whitespace=True, required=False
    )


class GoogleLoginSerializer(_SocialLoginSerializer):
    id_token = serializers.CharField(max_length=4096, trim_whitespace=False)



class BodyInfoSerializer(serializers.Serializer):
    # The app checks the same ranges (BodyInfoRules).
    height_cm = serializers.FloatField(min_value=100, max_value=250)
    weight_kg = serializers.FloatField(min_value=20, max_value=300)
    consent = serializers.BooleanField()

    # FloatField takes "NaN", which passes min/max; refuse it.
    def validate_height_cm(self, value):
        if not math.isfinite(value):
            raise serializers.ValidationError("not_a_number")
        return value

    validate_weight_kg = validate_height_cm

    def validate_consent(self, value):
        if not value:
            raise serializers.ValidationError("consent_required")
        return value


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["id", "login_id", "nickname"]


def auth_response(user: User) -> dict:
    """What sign-up and login return: a token and the account."""
    return {"token": str(AccessToken.for_user(user)), "user": UserSerializer(user).data}


class ProfileSerializer(UserSerializer):
    height_cm = serializers.FloatField(allow_null=True)
    weight_kg = serializers.FloatField(allow_null=True)
    best_reps = serializers.IntegerField(allow_null=True)
    # {exercise: {score, reps}}, for each exercise played.
    bests = serializers.DictField()
    last_match = MatchSerializer(allow_null=True)

    class Meta(UserSerializer.Meta):
        fields = UserSerializer.Meta.fields + [
            "height_cm",
            "weight_kg",
            "best_reps",
            "bests",
            "last_match",
        ]
