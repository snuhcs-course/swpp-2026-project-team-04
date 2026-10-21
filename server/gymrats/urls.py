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
    # Battle server only (P11); nginx does not forward /api/internal/.
    path("internal/", include("matches.internal_urls")),
]
