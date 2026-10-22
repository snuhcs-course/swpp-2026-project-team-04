from django.http import JsonResponse
from django.urls import include, path
from rest_framework.decorators import (
    api_view,
    authentication_classes,
    permission_classes,
)
from rest_framework.permissions import AllowAny
from rest_framework.response import Response


@api_view(["GET"])
@authentication_classes([])
@permission_classes([AllowAny])
def health(request):
    return Response({"status": "ok"})


urlpatterns = [
    path("health", health),
    path("auth/", include("accounts.urls")),
    path("users/", include("accounts.me_urls")),
    path("matches", include("matches.urls")),
]


# AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
# Unknown paths and crashes answer in the API's {"detail": ...} shape, not
# Django's HTML pages, so the app can read every error.
def not_found(request, exception=None):
    return JsonResponse({"detail": "not_found"}, status=404)


def server_error(request):
    return JsonResponse({"detail": "server_error"}, status=500)


handler404 = not_found
handler500 = server_error
