"""Settings for the test suite: fixed throwaway secrets, in-memory DB."""

import os

os.environ.setdefault("DJANGO_SECRET_KEY", "test-django-secret-not-used-anywhere-else")
os.environ.setdefault("JWT_SECRET", "test-jwt-secret-not-used-anywhere-else-1")
os.environ.setdefault("RESULTS_SECRET", "test-results-secret-not-used-anywhere-else")
os.environ.setdefault("DATABASE_URL", "sqlite://:memory:")

from .settings import *  # noqa: E402,F403

# Fast hashing in tests; production keeps bcrypt (settings.PASSWORD_HASHERS).
PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]
