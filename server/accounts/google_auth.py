"""Checks a Google ID token from the app's Google sign-in.

The app sends the ID token Google gave it; the server checks its signature
against Google's published keys, that it was issued for one of this app's
client ids, and that it has not expired. Only the token's subject (the
account's stable id) is kept.
"""

from dataclasses import dataclass
from functools import lru_cache

import jwt
from django.conf import settings

_CERTS_URL = "https://www.googleapis.com/oauth2/v3/certs"
_ISSUERS = ("accounts.google.com", "https://accounts.google.com")


class SocialTokenInvalid(Exception):
    """The provider did not vouch for the token."""


class SocialLoginUnavailable(Exception):
    """The server has no client id for the provider, or cannot reach it."""


@dataclass(frozen=True)
class SocialIdentity:
    subject: str


@lru_cache(maxsize=1)
def _jwks_client():
    # Caches Google's keys; a new key id triggers one refetch.
    return jwt.PyJWKClient(_CERTS_URL, cache_keys=True, timeout=5)


def _signing_key(token: str):
    try:
        return _jwks_client().get_signing_key_from_jwt(token).key
    except jwt.PyJWKClientConnectionError as error:
        raise SocialLoginUnavailable from error
    except jwt.PyJWKClientError as error:
        raise SocialTokenInvalid from error


def verify_google_id_token(token: str) -> SocialIdentity:
    audiences = settings.GOOGLE_CLIENT_IDS
    if not audiences:
        raise SocialLoginUnavailable
    try:
        claims = jwt.decode(
            token,
            _signing_key(token),
            algorithms=["RS256"],
            audience=audiences,
            options={"require": ["exp", "iss", "aud", "sub"]},
        )
    except jwt.PyJWTError as error:
        raise SocialTokenInvalid from error
    if claims["iss"] not in _ISSUERS or not str(claims["sub"]):
        raise SocialTokenInvalid
    return SocialIdentity(subject=str(claims["sub"]))
