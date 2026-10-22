import pytest
from rest_framework.test import APIClient


@pytest.fixture
def client(db):
    return APIClient()


def sign_up(client, login_id="woohyun", nickname="우현", password="password1"):
    response = client.post(
        "/auth/signup",
        {"login_id": login_id, "nickname": nickname, "password": password},
        format="json",
    )
    assert response.status_code == 201, response.content
    return response.json()


def auth(token):
    return {"HTTP_AUTHORIZATION": f"Bearer {token}"}


def match_body(n=0, my_reps=24, opponent_reps=19, played_at=None):
    return {
        "client_id": f"client-{n:04d}",
        "exercise": "push_up",
        "opponent_name": "RepBot",
        "my_reps": my_reps,
        "opponent_reps": opponent_reps,
        "played_at": played_at or f"2026-10-15T12:{n % 60:02d}:00+09:00",
    }
