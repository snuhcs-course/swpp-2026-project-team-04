"""Checks a Google ID token from the app's Google sign-in.

The app sends the ID token Google gave it; the server checks its signature
against Google's published keys, that it was issued for one of this app's
client ids, and that it has not expired. Only the token's subject (the
account's stable id) is kept.
"""

import threading
import time
from dataclasses import dataclass

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


# Google's keys are fetched at most once per interval. A token with a key id
# we do not know does not trigger another fetch inside it, so made-up key ids
# cannot keep the workers waiting on Google (Codex review, PR #93). Google
# publishes a new key well before it signs with it, so real tokens still pass.
_REFRESH_INTERVAL = 300.0
# After a failed fetch, try again sooner, so one network blip does not block
# Google login for the whole interval.
_RETRY_AFTER_FAILURE = 30.0
# Keys older than this are not trusted until fetched again, so a key Google
# retired stops working (Google's own cache lifetime is a few hours).
_MAX_KEY_AGE = 6 * 3600.0


class _GoogleKeys:
    """Google's public keys by key id, refreshed lazily and rarely."""

    def __init__(self, fetch=None, clock=time.monotonic):
        self._fetch = fetch or self._fetch_from_google
        self._clock = clock
        self._keys = {}
        self._fetched_at = None
        self._last_attempt = None
        self._failed = False
        self._lock = threading.Lock()

    @staticmethod
    def _fetch_from_google():
        client = jwt.PyJWKClient(_CERTS_URL, cache_keys=False, timeout=5)
        return client.fetch_data()

    def _usable(self, kid, now):
        if self._fetched_at is None or now - self._fetched_at >= _MAX_KEY_AGE:
            return None
        return self._keys.get(kid)

    def key_for(self, kid):
        key = self._usable(kid, self._clock())
        if key is not None:
            return key
        with self._lock:
            now = self._clock()
            key = self._usable(kid, now)
            if key is not None:
                return key
            wait = _RETRY_AFTER_FAILURE if self._failed else _REFRESH_INTERVAL
            if self._last_attempt is not None and now - self._last_attempt < wait:
                if self._failed:
                    raise SocialLoginUnavailable
                raise SocialTokenInvalid
            self._last_attempt = now
            try:
                jwks = jwt.PyJWKSet.from_dict(self._fetch())
                keys = {k.key_id: k.key for k in jwks.keys if k.key_id}
            except (
                jwt.PyJWKClientError,
                jwt.PyJWKSetError,
                jwt.PyJWKError,
                ValueError,
                TypeError,
                AttributeError,
            ) as error:
                # Unreachable, or an answer that is not a key set.
                self._failed = True
                raise SocialLoginUnavailable from error
            self._failed = False
            self._keys = keys
            self._fetched_at = now
        key = self._keys.get(kid)
        if key is None:
            raise SocialTokenInvalid
        return key


_google_keys = _GoogleKeys()


def _signing_key(token: str):
    try:
        kid = jwt.get_unverified_header(token).get("kid")
    except jwt.PyJWTError as error:
        raise SocialTokenInvalid from error
    if not kid:
        raise SocialTokenInvalid
    return _google_keys.key_for(kid)


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
