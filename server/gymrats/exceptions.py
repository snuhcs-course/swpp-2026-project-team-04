"""Error bodies in the shape the app reads: {"detail": ...}."""

from rest_framework import status
from rest_framework.exceptions import (
    AuthenticationFailed,
    NotAuthenticated,
    ValidationError,
)
from rest_framework.response import Response
from rest_framework.views import exception_handler


def api_exception_handler(exc, context):
    if isinstance(exc, (NotAuthenticated, AuthenticationFailed)):
        # Missing, expired, forged, or for a deleted user: one answer.
        return Response(
            {"detail": "invalid_token"},
            status=status.HTTP_401_UNAUTHORIZED,
            headers={"WWW-Authenticate": "Bearer"},
        )
    if isinstance(exc, ValidationError):
        return Response(
            {"detail": exc.detail}, status=status.HTTP_422_UNPROCESSABLE_ENTITY
        )
    return exception_handler(exc, context)
