"""Sign-up, login, and the logged-in user's profile."""

from django.contrib.auth import authenticate
from django.db import IntegrityError, transaction
from django.db.models import Max
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from matches.models import Match

from .models import User
from .serializers import (
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


class MeView(APIView):
    def get(self, request):
        user = request.user
        mine = Match.objects.filter(user=user)
        profile = {
            "id": user.id,
            "login_id": user.login_id,
            "nickname": user.nickname,
            "best_reps": mine.aggregate(best=Max("my_reps"))["best"],
            "last_match": mine.order_by("-played_at", "-id").first(),
        }
        return Response(ProfileSerializer(profile).data)
