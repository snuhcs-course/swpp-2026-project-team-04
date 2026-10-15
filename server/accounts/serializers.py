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


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["id", "login_id", "nickname"]


def auth_response(user: User) -> dict:
    """What sign-up and login return: a token and the account."""
    return {"token": str(AccessToken.for_user(user)), "user": UserSerializer(user).data}


class ProfileSerializer(UserSerializer):
    best_reps = serializers.IntegerField(allow_null=True)
    last_match = MatchSerializer(allow_null=True)

    class Meta(UserSerializer.Meta):
        fields = UserSerializer.Meta.fields + ["best_reps", "last_match"]
