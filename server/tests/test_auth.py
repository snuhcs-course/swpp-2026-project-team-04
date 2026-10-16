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
