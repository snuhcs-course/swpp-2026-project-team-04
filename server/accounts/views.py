"""Sign-up, login (id and password, Google), and the logged-in user's
profile and body info."""

from django.contrib.auth import authenticate
from django.db import IntegrityError, transaction
from django.db.models import Max
from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from matches.models import Match

from .google_auth import (
    SocialLoginUnavailable,
    SocialTokenInvalid,
    verify_google_id_token,
)
from .models import User
from .serializers import (
    BodyInfoSerializer,
    GoogleLoginSerializer,
    LoginSerializer,
    ProfileSerializer,
    SignUpSerializer,
    auth_response,
)


class SignUpView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        body = SignUpSerializer(data=request.data)
        body.is_valid(raise_exception=True)
        data = body.validated_data
        try:
            with transaction.atomic():
                user = User.objects.create_user(
                    login_id=data["login_id"],
                    nickname=data["nickname"],
                    password=data["password"],
                )
        except IntegrityError:
            return Response(
                {"detail": "login_id_taken"}, status=status.HTTP_409_CONFLICT
            )
        return Response(auth_response(user), status=status.HTTP_201_CREATED)


class LoginView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        body = LoginSerializer(data=request.data)
        body.is_valid(raise_exception=True)
        # Django hashes a dummy password for an unknown id too, so the
        # response time does not tell which field was wrong.
        user = authenticate(
            request,
            login_id=body.validated_data["login_id"],
            password=body.validated_data["password"],
        )
        if user is None:
            # One answer for a wrong id and a wrong password.
            return Response(
                {"detail": "invalid_credentials"},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        return Response(auth_response(user))


class _SocialLoginView(APIView):
    """Logs in the account of a Google identity. 200 for an
    existing account. For a new one the user picks a nickname first: without
    "nickname" the answer is 404 "signup_required" and nothing is created;
    with it, the account is created
    (201, "created": true, so the app asks for the optional body info)."""

    authentication_classes = []
    permission_classes = [AllowAny]
    serializer_class = None
    token_field = ""
    provider_field = ""

    def verify(self, token):
        raise NotImplementedError

    def post(self, request):
        body = self.serializer_class(data=request.data)
        body.is_valid(raise_exception=True)
        try:
            identity = self.verify(body.validated_data[self.token_field])
        except SocialTokenInvalid:
            return Response(
                {"detail": "invalid_social_token"},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        except SocialLoginUnavailable:
            return Response(
                {"detail": "social_login_unavailable"},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        lookup = {self.provider_field: identity.subject}
        user = User.objects.filter(**lookup).first()
        created = False
        nickname = body.validated_data.get("nickname")
        if user is None and nickname is None:
            return Response(
                {"detail": "signup_required"}, status=status.HTTP_404_NOT_FOUND
            )
        if user is None:
            try:
                with transaction.atomic():
                    user = User.objects.create_social_user(
                        self.provider_field, identity.subject, nickname
                    )
                created = True
            except IntegrityError:
                # The same identity signed up at the same moment.
                user = User.objects.get(**lookup)
        return Response(
            {**auth_response(user), "created": created},
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class GoogleLoginView(_SocialLoginView):
    serializer_class = GoogleLoginSerializer
    token_field = "id_token"
    provider_field = "google_sub"

    def verify(self, token):
        return verify_google_id_token(token)



class BodyInfoView(APIView):
    """Saves the user's height and weight, only with their consent. POST, as
    the app's ApiClient sends no PATCH; each call replaces both values."""

    def post(self, request):
        body = BodyInfoSerializer(data=request.data)
        body.is_valid(raise_exception=True)
        user = request.user
        user.height_cm = round(body.validated_data["height_cm"], 1)
        user.weight_kg = round(body.validated_data["weight_kg"], 1)
        user.body_consent_at = timezone.now()
        user.save(update_fields=["height_cm", "weight_kg", "body_consent_at"])
        return Response({"height_cm": user.height_cm, "weight_kg": user.weight_kg})


class MeView(APIView):
    def get(self, request):
        user = request.user
        mine = Match.objects.filter(user=user)
        profile = {
            "id": user.id,
            "login_id": user.login_id,
            "nickname": user.nickname,
            # Only the user's own weight, saved with consent; the post-game
            # report's estimates use it (P14).
            "weight_kg": user.weight_kg,
            "best_reps": mine.aggregate(best=Max("my_reps"))["best"],
            # Max skips battles saved before points were kept.
            "bests": {
                row["exercise"]: {"score": row["score"], "reps": row["reps"]}
                for row in mine.values("exercise").annotate(
                    score=Max("my_score"), reps=Max("my_reps")
                )
            },
            "last_match": mine.order_by("-played_at", "-id").first(),
        }
        return Response(ProfileSerializer(profile).data)
