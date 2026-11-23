import json
import uuid
from datetime import UTC, datetime, timedelta

import jwt
import pytest
from django.conf import settings
from django.test import override_settings

from accounts.models import User

from .conftest import auth, sign_up


def _token(user_id, secret, exp):
    return jwt.encode(
        {"token_type": "access", "user_id": user_id, "jti": uuid.uuid4().hex, "exp": exp},
        secret,
        algorithm="HS256",
    )


def test_health(client):
    assert client.get("/health").json() == {"status": "ok"}


def test_sign_up_returns_a_token_and_the_user(client):
    body = sign_up(client)
    assert body["token"]
    assert body["user"]["login_id"] == "woohyun"
    assert body["user"]["nickname"] == "우현"
    assert "password" not in str(body)
    me = client.get("/users/me", **auth(body["token"]))
    assert me.status_code == 200
    assert me.json()["nickname"] == "우현"


@override_settings(
    PASSWORD_HASHERS=["django.contrib.auth.hashers.BCryptSHA256PasswordHasher"]
)
def test_password_is_stored_only_as_a_bcrypt_hash(client):
    sign_up(client, password="password1")
    user = User.objects.get()
    assert "password1" not in user.password
    assert user.password.startswith("bcrypt_sha256$")
    assert user.check_password("password1")


def test_production_settings_hash_with_bcrypt():
    from gymrats import settings as prod

    assert prod.PASSWORD_HASHERS == [
        "django.contrib.auth.hashers.BCryptSHA256PasswordHasher"
    ]


def test_duplicate_login_id_is_rejected_and_nothing_is_created(client):
    sign_up(client)
    response = client.post(
        "/auth/signup",
        {"login_id": "woohyun", "nickname": "다른사람", "password": "password2"},
        format="json",
    )
    assert response.status_code == 409
    assert response.json()["detail"] == "login_id_taken"
    assert User.objects.count() == 1


@pytest.mark.parametrize(
    "field,value",
    [
        ("login_id", "ab"),
        ("login_id", "Woohyun"),
        ("login_id", "woo hyun"),
        ("login_id", "a" * 21),
        ("nickname", ""),
        ("nickname", "   "),
        ("nickname", "가" * 13),
        ("password", "short1"),
        ("password", "x" * 65),
    ],
)
def test_sign_up_validates_fields(client, field, value):
    body = {"login_id": "woohyun", "nickname": "우현", "password": "password1"}
    body[field] = value
    assert client.post("/auth/signup", body, format="json").status_code == 422


def test_login_with_the_right_password(client):
    sign_up(client)
    response = client.post(
        "/auth/login", {"login_id": "woohyun", "password": "password1"}, format="json"
    )
    assert response.status_code == 200
    assert response.json()["user"]["nickname"] == "우현"


def test_wrong_password_and_unknown_id_get_the_same_answer(client):
    sign_up(client)
    wrong_password = client.post(
        "/auth/login", {"login_id": "woohyun", "password": "password2"}, format="json"
    )
    unknown_id = client.post(
        "/auth/login", {"login_id": "nobody", "password": "password1"}, format="json"
    )
    assert wrong_password.status_code == unknown_id.status_code == 401
    assert wrong_password.json() == unknown_id.json() == {"detail": "invalid_credentials"}


def test_login_ignores_a_stale_token_header(client):
    sign_up(client)
    response = client.post(
        "/auth/login",
        {"login_id": "woohyun", "password": "password1"},
        format="json",
        **auth("old-garbage"),
    )
    assert response.status_code == 200


@pytest.mark.parametrize(
    "headers",
    [
        {},
        {"HTTP_AUTHORIZATION": "Bearer not-a-token"},
        {"HTTP_AUTHORIZATION": "Basic d29vaHl1bjpwYXNzd29yZDE="},
    ],
)
def test_protected_endpoints_need_a_valid_token(client, headers):
    for method, path in [("get", "/users/me"), ("get", "/matches"), ("post", "/matches")]:
        response = getattr(client, method)(path, **headers)
        assert response.status_code == 401, (method, path)
        assert response.json() == {"detail": "invalid_token"}


def test_token_signed_with_another_secret_is_rejected(client):
    user = sign_up(client)["user"]
    forged = _token(user["id"], "another-secret", datetime.now(UTC) + timedelta(days=1))
    assert client.get("/users/me", **auth(forged)).status_code == 401


def test_expired_token_is_rejected(client):
    user = sign_up(client)["user"]
    expired = _token(user["id"], settings.JWT_SECRET, datetime.now(UTC) - timedelta(seconds=1))
    assert client.get("/users/me", **auth(expired)).status_code == 401


def test_a_valid_hand_made_token_works(client):
    # Guards the two tests above: the same token shape is accepted when valid.
    user = sign_up(client)["user"]
    good = _token(user["id"], settings.JWT_SECRET, datetime.now(UTC) + timedelta(days=1))
    assert client.get("/users/me", **auth(good)).status_code == 200


def test_token_of_a_deleted_user_is_rejected(client):
    token = sign_up(client)["token"]
    User.objects.all().delete()
    assert client.get("/users/me", **auth(token)).status_code == 401


@pytest.mark.parametrize("secret", ["", "change-me", "short-secret"])
def test_weak_secrets_are_refused(monkeypatch, secret):
    from django.core.exceptions import ImproperlyConfigured

    from gymrats.settings import _secret

    monkeypatch.setenv("SOME_SECRET", secret)
    with pytest.raises(ImproperlyConfigured):
        _secret("SOME_SECRET")


# AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
def test_unknown_path_answers_json_404(client):
    response = client.get("/nope")
    assert response.status_code == 404
    assert response["Content-Type"] == "application/json"
    assert response.json() == {"detail": "not_found"}


def test_server_error_answers_json_500(rf):
    from gymrats.urls import server_error

    response = server_error(rf.get("/"))
    assert response.status_code == 500
    assert json.loads(response.content) == {"detail": "server_error"}


# --- Google login, body info (P7) -------------------------------------------


from cryptography.hazmat.primitives.asymmetric import rsa  # noqa: E402

from accounts import google_auth  # noqa: E402
from accounts.google_auth import (  # noqa: E402
    SocialIdentity,
    SocialLoginUnavailable,
    SocialTokenInvalid,
)

GOOGLE_CLIENT = "web-client.apps.googleusercontent.com"
_KEY = rsa.generate_private_key(public_exponent=65537, key_size=2048)
_OTHER_KEY = rsa.generate_private_key(public_exponent=65537, key_size=2048)


def _google_token(key=_KEY, **overrides):
    claims = {
        "iss": "https://accounts.google.com",
        "aud": GOOGLE_CLIENT,
        "sub": "1234567890",
        "name": "송우현",
        "exp": datetime.now(UTC) + timedelta(minutes=5),
        **overrides,
    }
    claims = {k: v for k, v in claims.items() if v is not None}
    return jwt.encode(claims, key, algorithm="RS256")


@pytest.fixture
def google(monkeypatch, settings):
    settings.GOOGLE_CLIENT_IDS = [GOOGLE_CLIENT]
    monkeypatch.setattr(google_auth, "_signing_key", lambda token: _KEY.public_key())


def _post_google(client, token, nickname=None):
    body = {"id_token": token}
    if nickname is not None:
        body["nickname"] = nickname
    return client.post("/auth/google", body, format="json")


def test_google_new_account_needs_a_nickname_first(client, google):
    response = _post_google(client, _google_token())
    assert response.status_code == 404
    assert response.json() == {"detail": "signup_required"}
    assert User.objects.count() == 0


def test_google_creates_an_account_once_then_logs_it_in(client, google):
    first = _post_google(client, _google_token(), nickname=" 우현 ")
    assert first.status_code == 201
    body = first.json()
    assert body["created"] is True
    assert body["token"]
    assert body["user"]["nickname"] == "우현"
    assert body["user"]["login_id"].startswith("g_")
    again = _post_google(client, _google_token())
    assert again.status_code == 200
    assert again.json()["created"] is False
    assert again.json()["user"]["id"] == body["user"]["id"]
    assert User.objects.count() == 1
    me = client.get("/users/me", **auth(again.json()["token"]))
    assert me.status_code == 200


def test_google_account_cannot_log_in_with_a_password(client, google):
    login_id = _post_google(client, _google_token(), "우현").json()["user"]["login_id"]
    user = User.objects.get(login_id=login_id)
    assert not user.has_usable_password()
    response = client.post(
        "/auth/login", {"login_id": login_id, "password": "password1"}, format="json"
    )
    assert response.status_code == 401


@pytest.mark.parametrize("nickname", ["", "   ", "가나다라마바사아자차카타파"])
def test_google_refuses_a_bad_nickname(client, google, nickname):
    assert _post_google(client, _google_token(), nickname).status_code == 422
    assert User.objects.count() == 0


def test_existing_account_ignores_a_nickname(client, google):
    _post_google(client, _google_token(), "우현")
    again = _post_google(client, _google_token(), "다른이름")
    assert again.status_code == 200
    assert again.json()["user"]["nickname"] == "우현"


@pytest.mark.parametrize(
    "token",
    [
        _google_token(aud="someone-else.apps.googleusercontent.com"),
        _google_token(iss="https://evil.example.com"),
        _google_token(exp=datetime.now(UTC) - timedelta(minutes=5)),
        _google_token(sub=None),
        _google_token(key=_OTHER_KEY),
        "not-a-jwt",
    ],
    ids=["audience", "issuer", "expired", "no-subject", "signature", "garbage"],
)
def test_google_refuses_a_token_google_did_not_issue_for_us(client, google, token):
    response = _post_google(client, token)
    assert response.status_code == 401
    assert response.json() == {"detail": "invalid_social_token"}
    assert User.objects.count() == 0


def test_google_needs_an_id_token(client, google):
    assert client.post("/auth/google", {}, format="json").status_code == 422


def test_google_unconfigured_answers_503(client, settings):
    settings.GOOGLE_CLIENT_IDS = []
    response = _post_google(client, _google_token())
    assert response.status_code == 503
    assert response.json() == {"detail": "social_login_unavailable"}


class _FakeJwks:
    def __init__(self, error=None):
        self.error = error

    def get_signing_key_from_jwt(self, token):
        if self.error:
            raise self.error

        class Key:
            key = _KEY.public_key()

        return Key()


@pytest.mark.parametrize(
    ("error", "expected"),
    [
        (None, None),
        (jwt.PyJWKClientConnectionError("down"), SocialLoginUnavailable),
        (jwt.PyJWKClientError("unknown kid"), SocialTokenInvalid),
    ],
)
def test_google_signing_key_lookup(monkeypatch, error, expected):
    monkeypatch.setattr(google_auth, "_jwks_client", lambda: _FakeJwks(error))
    if expected is None:
        assert google_auth._signing_key("t").public_numbers() == _KEY.public_key().public_numbers()
    else:
        with pytest.raises(expected):
            google_auth._signing_key("t")


def test_google_jwks_client_points_at_googles_keys():
    google_auth._jwks_client.cache_clear()
    assert google_auth._jwks_client().uri == "https://www.googleapis.com/oauth2/v3/certs"
    assert google_auth._jwks_client() is google_auth._jwks_client()


def test_social_sign_up_race_logs_in_the_account_made_first(client, google, monkeypatch):
    # Another request made the account between this one's lookup and insert.
    first = User.objects.create_social_user("google_sub", "1234567890", "먼저")
    real_filter = User.objects.filter

    class Missed:
        def first(self):
            return None

    monkeypatch.setattr(User.objects, "filter", lambda **lookup: Missed())
    response = _post_google(client, _google_token(), "나중")
    monkeypatch.setattr(User.objects, "filter", real_filter)
    assert response.json()["user"]["id"] == first.id
    assert response.status_code == 200
    assert response.json()["created"] is False
    assert User.objects.count() == 1


def _post_body(client, token, **body):
    return client.post("/users/me/body", body, format="json", **auth(token))


def test_body_info_is_saved_with_consent(client):
    token = sign_up(client)["token"]
    response = _post_body(client, token, height_cm=175.44, weight_kg=70, consent=True)
    assert response.status_code == 200
    assert response.json() == {"height_cm": 175.4, "weight_kg": 70.0}
    user = User.objects.get(login_id="woohyun")
    assert (user.height_cm, user.weight_kg) == (175.4, 70.0)
    assert user.body_consent_at is not None


@pytest.mark.parametrize(
    "body",
    [
        {"height_cm": 175, "weight_kg": 70, "consent": False},
        {"height_cm": 175, "weight_kg": 70},
        {"height_cm": 99, "weight_kg": 70, "consent": True},
        {"height_cm": 251, "weight_kg": 70, "consent": True},
        {"height_cm": 175, "weight_kg": 19, "consent": True},
        {"height_cm": 175, "weight_kg": 301, "consent": True},
        {"weight_kg": 70, "consent": True},
        {"height_cm": "NaN", "weight_kg": 70, "consent": True},
        {"height_cm": 175, "weight_kg": "NaN", "consent": True},
        {"height_cm": "Infinity", "weight_kg": 70, "consent": True},
    ],
)
def test_body_info_needs_consent_and_sane_values(client, body):
    token = sign_up(client)["token"]
    assert _post_body(client, token, **body).status_code == 422
    user = User.objects.get(login_id="woohyun")
    assert user.height_cm is None and user.body_consent_at is None


def test_body_info_needs_a_login(client):
    response = client.post(
        "/users/me/body", {"height_cm": 175, "weight_kg": 70, "consent": True}, format="json"
    )
    assert response.status_code == 401


def test_social_identity_is_plain_data():
    assert SocialIdentity("1") == SocialIdentity(subject="1")
