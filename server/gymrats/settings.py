"""Settings for the GymRats API.

Every secret comes from the environment: on the team server systemd loads
/srv/gymrats/.env (keys as in .env.example). Nothing secret is in the repo.
"""

import os
from datetime import timedelta
from pathlib import Path

import dj_database_url
from django.core.exceptions import ImproperlyConfigured

BASE_DIR = Path(__file__).resolve().parent.parent


def _secret(name: str) -> str:
    """A required random value of 32+ characters; refuses placeholders."""
    value = os.environ.get(name, "")
    if len(value) < 32 or value == "change-me":
        raise ImproperlyConfigured(f"{name} must be a random value of 32+ characters")
    return value


SECRET_KEY = _secret("DJANGO_SECRET_KEY")
JWT_SECRET = _secret("JWT_SECRET")
DEBUG = os.environ.get("DJANGO_DEBUG") == "1"
ALLOWED_HOSTS = os.environ.get(
    "ALLOWED_HOSTS", "52.78.38.225,localhost,127.0.0.1,10.0.2.2"
).split(",")

INSTALLED_APPS = [
    "django.contrib.contenttypes",
    "django.contrib.auth",
    "rest_framework",
    "accounts",
    "matches",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.middleware.common.CommonMiddleware",
]

ROOT_URLCONF = "gymrats.urls"
WSGI_APPLICATION = "gymrats.wsgi.application"

# The app calls /auth/login, not /auth/login/.
APPEND_SLASH = False

DATABASES = {
    "default": dj_database_url.parse(
        os.environ.get("DATABASE_URL", f"sqlite:///{BASE_DIR / 'gymrats.db'}")
    )
}
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

AUTH_USER_MODEL = "accounts.User"
# bcrypt (SHA-256 first, so long passwords are not cut at 72 bytes).
PASSWORD_HASHERS = ["django.contrib.auth.hashers.BCryptSHA256PasswordHasher"]

USE_TZ = True
TIME_ZONE = "UTC"
USE_I18N = False

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],
    "DEFAULT_RENDERER_CLASSES": ["rest_framework.renderers.JSONRenderer"],
    "DEFAULT_PARSER_CLASSES": ["rest_framework.parsers.JSONParser"],
    "EXCEPTION_HANDLER": "gymrats.exceptions.api_exception_handler",
    "UNAUTHENTICATED_USER": None,
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(days=int(os.environ.get("TOKEN_DAYS", "30"))),
    "SIGNING_KEY": JWT_SECRET,
    "ALGORITHM": "HS256",
    "AUTH_HEADER_TYPES": ("Bearer",),
    "UPDATE_LAST_LOGIN": False,
}

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {"console": {"class": "logging.StreamHandler"}},
    "root": {"handlers": ["console"], "level": "WARNING"},
}
