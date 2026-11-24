"""P17: storing the P6 telemetry events, and counting them."""

import io
import json
import uuid

import pytest
from django.core.management import call_command
from django.core.management.base import CommandError

from telemetry.models import TelemetryEvent
from telemetry.summary import summarize

from .conftest import auth, sign_up

SECRET = "test-results-secret-not-used-anywhere-else"
TS = "2026-12-02T10:00:00+09:00"


def app_event(event, attempt="attempt-1", ts=TS, **fields):
    return {
        "event": event,
        "event_id": str(uuid.uuid4()),
        "ts": ts,
        "session_id": "session-1",
        "app_version": "1.0.0+5",
        "attempt_id": attempt,
        **fields,
    }


def send(client, token, *events):
    return client.post(
        "/telemetry/events", {"events": list(events)}, format="json", **auth(token)
    )


def battle(match_id="match-1", end_reason="time_up", status="finished", **fields):
    return {
        "event": "battle_finished",
        "event_id": str(uuid.uuid4()),
        "ts": TS,
        "match_id": match_id,
        "end_reason": end_reason,
        "status": status,
        "duration_ms": 30000,
        "exercise": "push_up",
        "kind": "main",
        "scores": [
            {"player_id": "1", "game_score": 120, "valid_reps": 12},
            {"player_id": "2", "game_score": 90, "valid_reps": 9},
        ],
        **fields,
    }


def internal(client, body, secret=SECRET, **extra):
    return client.post(
        "/internal/telemetry/battle",
        body,
        format="json",
        HTTP_X_RESULTS_SECRET=secret,
        **extra,
    )


@pytest.fixture
def token(client):
    return sign_up(client)["token"]


# --- the app's events -------------------------------------------------------


def test_every_app_event_of_the_dictionary_is_stored_with_its_account(client, token):
    events = [
        app_event("tutorial_started", "t", pages_total=12),
        app_event("tutorial_finished", "t", result="skipped", duration_ms=4100, last_page=3),
        app_event("setup_started", "s", exercise="squat", mode="friend"),
        app_event(
            "setup_finished",
            "s",
            result="timeout",
            duration_ms=10000,
            limit_ms=10000,
            last_reason="too_close",
        ),
        app_event("matching_started", "m", exercise="push_up", kind="main"),
        app_event("matching_finished", "m", result="found", wait_ms=2300),
    ]
    response = send(client, token, *events)
    assert response.status_code == 200
    assert response.json() == {"stored": 6, "duplicates": 0, "rejected": []}
    rows = list(TelemetryEvent.objects.order_by("id"))
    assert [r.event for r in rows] == [e["event"] for e in events]
    assert {r.user.login_id for r in rows} == {"woohyun"}
    setup = rows[3]
    assert setup.attempt_id == "s"
    assert setup.session_id == "session-1"
    assert setup.app_version == "1.0.0+5"
    assert setup.match_id is None
    assert setup.data == {
        "result": "timeout",
        "duration_ms": 10000,
        "limit_ms": 10000,
        "last_reason": "too_close",
    }


def test_a_bot_setup_has_no_limit_and_may_never_have_been_unready(client, token):
    event = app_event(
        "setup_finished", result="ready", duration_ms=800, limit_ms=None, last_reason=None
    )
    assert send(client, token, event).json()["stored"] == 1


def test_a_resent_event_is_stored_once(client, token):
    event = app_event("matching_started", exercise="push_up", kind="main")
    assert send(client, token, event).json()["stored"] == 1
    again = send(client, token, event, event).json()
    assert again == {"stored": 0, "duplicates": 2, "rejected": []}
    assert TelemetryEvent.objects.count() == 1


@pytest.mark.parametrize(
    "event",
    [
        # Outside the dictionary: never stored, whatever the reason.
        app_event("tutorial_started", pages_total=3, frame="base64-jpeg"),
        app_event("setup_finished", result="ready", duration_ms=1, limit_ms=None,
                  last_reason=None, landmarks=[[0.1, 0.2]]),
        app_event("matching_started", exercise="push_up", kind="main", token="abc"),
        app_event("matching_started", exercise="push_up", kind="main", email="a@b.c"),
        # Wrong values.
        app_event("tutorial_finished", result="closed", duration_ms=1, last_page=1),
        app_event("setup_started", exercise="plank", mode="bot"),
        app_event("setup_finished", result="ready", duration_ms=-1, limit_ms=None,
                  last_reason=None),
        app_event("setup_finished", result="ready", duration_ms=1, limit_ms=None,
                  last_reason="ready"),
        app_event("matching_finished", result="found"),
        app_event("matching_finished", result="found", wait_ms=1, ts="yesterday"),
        {**app_event("matching_started", exercise="push_up", kind="main"),
         "event_id": "not-a-uuid"},
        # Only the battle server records the end of a battle.
        battle(),
        app_event("bot_battle_finished"),
    ],
)
def test_an_event_outside_the_dictionary_is_rejected_and_the_rest_kept(
    client, token, event
):
    good = app_event("matching_started", exercise="squat", kind="friend")
    response = send(client, token, event, good)
    assert response.status_code == 200
    assert response.json() == {"stored": 1, "duplicates": 0, "rejected": [0]}
    assert list(TelemetryEvent.objects.values_list("event", flat=True)) == [
        "matching_started"
    ]


def test_the_account_comes_from_the_token_not_the_body(client, token):
    event = app_event("matching_started", exercise="push_up", kind="main", user=99)
    assert send(client, token, event).json()["rejected"] == [0]


def test_events_need_a_login(client):
    response = client.post(
        "/telemetry/events",
        {"events": [app_event("tutorial_started", pages_total=3)]},
        format="json",
    )
    assert response.status_code == 401
    assert TelemetryEvent.objects.count() == 0


@pytest.mark.parametrize(
    "body",
    [{}, {"events": []}, {"events": "x"}, {"events": [app_event("x")] * 101}],
)
def test_a_malformed_batch_is_refused_whole(client, token, body):
    response = client.post("/telemetry/events", body, format="json", **auth(token))
    assert response.status_code == 422
    assert TelemetryEvent.objects.count() == 0


# --- battle_finished from the battle server --------------------------------


def test_the_battle_server_records_a_battle_once_per_match(client):
    first = internal(client, battle())
    assert first.status_code == 201
    assert first.json() == {"match_id": "match-1", "stored": True}
    # A retry, or a second report of the same match, changes nothing.
    again = internal(client, battle(end_reason="disconnect_timeout"))
    assert again.status_code == 200
    assert again.json()["stored"] is False
    row = TelemetryEvent.objects.get()
    assert row.event == "battle_finished"
    assert row.user is None
    assert row.match_id == "match-1"
    assert row.data["end_reason"] == "time_up"
    assert row.data["scores"][0] == {"player_id": "1", "game_score": 120, "valid_reps": 12}


def test_a_cancelled_battle_has_no_scores(client):
    response = internal(
        client, battle(end_reason="setup_timeout", status="cancelled", scores=[])
    )
    assert response.status_code == 201


@pytest.mark.parametrize(
    "extra",
    [
        {"REMOTE_ADDR": "10.0.0.5"},
        {"HTTP_X_FORWARDED_FOR": "1.2.3.4"},
    ],
)
def test_only_the_battle_server_on_this_machine_may_record_a_battle(client, extra):
    assert internal(client, battle(), **extra).status_code == 403
    assert internal(client, battle(), secret="wrong" * 10).status_code == 403
    assert TelemetryEvent.objects.count() == 0


@pytest.mark.parametrize(
    "body",
    [
        battle(status="paused"),
        battle(kind="ranked"),
        battle(scores=[{"player_id": "1", "game_score": 1, "valid_reps": 1}] * 3),
        battle(landmarks=[1, 2]),
        {k: v for k, v in battle().items() if k != "match_id"},
    ],
)
def test_a_malformed_battle_is_refused(client, body):
    assert internal(client, body).status_code == 422
    assert TelemetryEvent.objects.count() == 0


# --- counting (P6 rules) ----------------------------------------------------


def test_starts_are_the_denominator_and_a_missing_end_is_unobserved(client, token):
    send(
        client,
        token,
        app_event("setup_started", "a", exercise="push_up", mode="main"),
        app_event("setup_finished", "a", result="ready", duration_ms=4000,
                  limit_ms=10000, last_reason="too_far"),
        app_event("setup_started", "b", exercise="push_up", mode="main"),
        app_event("setup_finished", "b", result="timeout", duration_ms=10000,
                  limit_ms=10000, last_reason="too_close"),
        app_event("setup_started", "c", exercise="squat", mode="bot"),
        app_event("setup_finished", "c", result="ready", duration_ms=2000,
                  limit_ms=None, last_reason=None),
        # Closed mid-way: no end.
        app_event("setup_started", "d", exercise="squat", mode="bot"),
        # An end whose start never arrived.
        app_event("setup_finished", "e", result="cancelled", duration_ms=1,
                  limit_ms=None, last_reason=None),
        app_event("tutorial_started", "t", pages_total=12),
        app_event("tutorial_finished", "t", result="completed", duration_ms=60000,
                  last_page=12),
        app_event("matching_started", "m", exercise="push_up", kind="main"),
    )
    internal(client, battle("match-1"))
    internal(client, battle("match-1"))
    internal(client, battle("match-2", end_reason="setup_timeout", status="cancelled",
                            duration_ms=12000, scores=[]))
    summary = summarize()
    assert summary["setup"] == {
        "started": 4,
        "results": {"ready": 2, "timeout": 1, "unobserved": 1},
        "times": {
            "ready": {"mean_ms": 3000, "median_ms": 3000.0},
            "timeout": {"mean_ms": 10000, "median_ms": 10000},
        },
        "ends_without_start": 1,
    }
    assert summary["tutorial"]["results"] == {"completed": 1}
    assert summary["matching"] == {
        "started": 1,
        "results": {"unobserved": 1},
        "times": {},
        "ends_without_start": 0,
    }
    assert summary["battle"]["finished"] == 2
    assert summary["battle"]["end_reasons"] == {"setup_timeout": 1, "time_up": 1}


def test_the_summary_command_prints_the_counts_since_a_time(client, token):
    send(
        client,
        token,
        app_event("tutorial_started", "old", ts="2026-11-30T10:00:00+09:00", pages_total=3),
        app_event("tutorial_started", "new", pages_total=3),
    )
    out = io.StringIO()
    call_command("telemetry_summary", "--since", "2026-12-01T00:00:00+09:00", stdout=out)
    assert json.loads(out.getvalue())["tutorial"]["started"] == 1
    out = io.StringIO()
    call_command("telemetry_summary", stdout=out)
    assert json.loads(out.getvalue())["tutorial"]["started"] == 2
    with pytest.raises(CommandError):
        call_command("telemetry_summary", "--since", "2026-12-01")
