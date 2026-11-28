"""The production health check (server/deploy/health_watch.py), with local HTTP servers.

No systemd and no real webhook: the restart and the alert are fakes, and the checked
services are small HTTP servers on 127.0.0.1 that answer 200, 500 or too late.
"""

import json
import socket
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "deploy"))
import health_watch  # noqa: E402


class Endpoint:
    """A local HTTP server whose answer the test can change."""

    def __init__(self):
        self.status = 200
        self.delay = 0.0
        self.posts = []
        self.agents = []
        endpoint = self

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                time.sleep(endpoint.delay)
                self.send_response(endpoint.status)
                self.end_headers()

            def do_POST(self):
                length = int(self.headers["Content-Length"])
                endpoint.agents.append(self.headers["User-Agent"])
                endpoint.posts.append(json.loads(self.rfile.read(length)))
                self.send_response(endpoint.status)
                self.end_headers()

            def log_message(self, *args):
                pass

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.server.daemon_threads = True
        self.url = f"http://127.0.0.1:{self.server.server_port}/health"
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    def close(self):
        self.server.shutdown()
        self.server.server_close()


@pytest.fixture
def api():
    endpoint = Endpoint()
    yield endpoint
    endpoint.close()


@pytest.fixture
def battle():
    endpoint = Endpoint()
    yield endpoint
    endpoint.close()


class Recorder:
    def __init__(self, restart_ok=True):
        self.restarted, self.sent, self.lines = [], [], []
        self.restart_ok = restart_ok

    def restart(self, unit):
        self.restarted.append(unit)
        return self.restart_ok

    def send(self, webhook, text):
        self.sent.append((webhook, text))
        return True


def run(services, state, rec):
    return health_watch.check_once(
        services, state, "https://hooks.example/x",
        restart_unit=rec.restart, send=rec.send, log=rec.lines.append,
    )


def test_a_service_that_answers_200_is_healthy(api):
    assert health_watch.healthy(api.url)


def test_an_error_status_is_unhealthy(api):
    api.status = 500
    assert not health_watch.healthy(api.url)


def test_an_answer_later_than_the_limit_is_unhealthy(api):
    api.delay = 0.5
    assert not health_watch.healthy(api.url, timeout=0.2)


def test_a_closed_port_is_unhealthy(api):
    url = api.url
    api.close()
    assert not health_watch.healthy(url, timeout=0.5)


def test_two_failures_in_a_row_do_not_restart(api, battle, tmp_path):
    rec, state = Recorder(), tmp_path / "state.json"
    api.status = 500
    services = {"gymrats-api": api.url, "gymrats-battle": battle.url}
    assert run(services, state, rec) == {"gymrats-api": 1, "gymrats-battle": 0}
    assert run(services, state, rec) == {"gymrats-api": 2, "gymrats-battle": 0}
    assert rec.restarted == [] and rec.sent == []


def test_the_third_failure_restarts_only_that_service_and_alerts(api, battle, tmp_path):
    rec, state = Recorder(), tmp_path / "state.json"
    battle.status = 503
    services = {"gymrats-api": api.url, "gymrats-battle": battle.url}
    for _ in range(3):
        counts = run(services, state, rec)

    assert rec.restarted == ["gymrats-battle"]
    assert counts == {"gymrats-api": 0, "gymrats-battle": 0}
    (webhook, text), = rec.sent
    assert webhook == "https://hooks.example/x"
    assert "gymrats-battle" in text and "3 health checks" in text and "restart requested" in text


def test_a_passing_check_clears_the_count(api, battle, tmp_path):
    rec, state = Recorder(), tmp_path / "state.json"
    services = {"gymrats-api": api.url, "gymrats-battle": battle.url}
    api.status = 500
    run(services, state, rec)
    run(services, state, rec)
    api.status = 200
    assert run(services, state, rec)["gymrats-api"] == 0
    api.status = 500
    run(services, state, rec)
    run(services, state, rec)
    assert rec.restarted == []


def test_a_failed_restart_is_reported(api, tmp_path):
    rec, state = Recorder(restart_ok=False), tmp_path / "state.json"
    api.status = 500
    for _ in range(3):
        run({"gymrats-api": api.url}, state, rec)
    assert "restart FAILED to start" in rec.sent[0][1]


def test_a_frozen_service_is_restarted_on_the_third_check(api, tmp_path):
    """A freeze right after a passing check: the 3rd check after it restarts the service.

    On the 30 s timer that is the check 90 s after the passing one, done within 95 s.
    """
    rec, state = Recorder(), tmp_path / "state.json"
    services = {"gymrats-api": api.url}
    health_watch.check_once(services, state, "", probe=lambda u: True,
                            restart_unit=rec.restart, send=rec.send, log=rec.lines.append)
    api.delay = 0.4  # frozen: the answer never comes within the limit
    timeouts = lambda url: health_watch.healthy(url, timeout=0.1)  # noqa: E731
    for check in (1, 2, 3):
        health_watch.check_once(services, state, "", probe=timeouts,
                                restart_unit=rec.restart, send=rec.send, log=rec.lines.append)
        assert rec.restarted == ([] if check < 3 else ["gymrats-api"])


def test_a_check_past_the_deadline_counts_as_failed(tmp_path):
    """The socket timeout is per read, so the whole check has its own deadline."""
    rec, state = Recorder(), tmp_path / "state.json"

    def trickles(url):
        time.sleep(1.0)  # still answering after the deadline
        return True

    started = time.monotonic()
    counts = health_watch.check_once({"gymrats-api": "x", "gymrats-battle": "y"}, state, "",
                                     probe=lambda u: trickles(u) if u == "x" else True,
                                     restart_unit=rec.restart, send=rec.send,
                                     log=rec.lines.append, deadline=0.2)
    assert time.monotonic() - started < 0.8
    assert counts == {"gymrats-api": 1, "gymrats-battle": 0}


def test_every_due_restart_is_requested_before_any_alert(api, battle, tmp_path):
    """A slow webhook must not hold up the second restart."""
    events = []
    state = tmp_path / "state.json"
    api.status = battle.status = 500
    services = {"gymrats-api": api.url, "gymrats-battle": battle.url}
    for _ in range(3):
        health_watch.check_once(services, state, "", restart_unit=lambda u: events.append(("restart", u)) or True,
                                send=lambda w, t: events.append(("alert", t.split()[1])) or True,
                                log=lambda m: None)
    assert events == [("restart", "gymrats-api"), ("restart", "gymrats-battle"),
                      ("alert", "gymrats-api"), ("alert", "gymrats-battle")]


def test_a_broken_state_file_counts_from_zero(api, tmp_path):
    rec, state = Recorder(), tmp_path / "state.json"
    state.write_text("not json")
    api.status = 500
    assert run({"gymrats-api": api.url}, state, rec) == {"gymrats-api": 1}
    state.write_text('["a list"]')
    assert run({"gymrats-api": api.url}, state, rec) == {"gymrats-api": 1}


def test_the_alert_is_posted_as_json(api):
    assert health_watch.notify(api.url, "hello")
    assert api.posts == [{"content": "hello", "text": "hello"}]
    assert api.agents == ["GymRats-ops/1.0"]


def test_no_webhook_or_a_failing_one_does_not_raise(api):
    assert not health_watch.notify("", "x")
    api.status = 500
    assert not health_watch.notify(api.url, "x")
    assert not health_watch.notify("http://127.0.0.1:1/none", "x", timeout=0.5)


def test_the_command_checks_the_given_services(api, tmp_path, monkeypatch):
    monkeypatch.delenv("ALERT_WEBHOOK_URL", raising=False)
    state = tmp_path / "state.json"
    api.status = 500
    assert health_watch.main(["--state", str(state), "--service", f"gymrats-api={api.url}"]) == 0
    assert json.loads(state.read_text()) == {"gymrats-api": 1}


def test_the_restart_runs_systemctl(monkeypatch):
    calls = []

    class Done:
        returncode = 0

    monkeypatch.setattr(health_watch.subprocess, "run", lambda cmd, **kw: calls.append(cmd) or Done())
    assert health_watch.restart("gymrats-api")
    assert calls == [["systemctl", "restart", "--no-block", "gymrats-api"]]


def test_a_restart_that_cannot_run_or_hangs_is_a_failed_restart(monkeypatch):
    def hangs(cmd, **kw):
        raise health_watch.subprocess.TimeoutExpired(cmd, kw["timeout"])

    monkeypatch.setattr(health_watch.subprocess, "run", hangs)
    assert not health_watch.restart("gymrats-api")

    def missing(cmd, **kw):
        raise FileNotFoundError("systemctl")

    monkeypatch.setattr(health_watch.subprocess, "run", missing)
    assert not health_watch.restart("gymrats-api")


def test_a_broken_http_answer_is_unhealthy_and_the_other_service_is_still_checked(battle, tmp_path):
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    listener.listen()

    def garbage():
        conn, _ = listener.accept()
        conn.recv(1024)
        conn.sendall(b"garbage\r\n\r\n")
        conn.close()

    threading.Thread(target=garbage, daemon=True).start()
    broken = f"http://127.0.0.1:{listener.getsockname()[1]}/health"
    rec, state = Recorder(), tmp_path / "state.json"
    battle.status = 500
    counts = run({"gymrats-api": broken, "gymrats-battle": battle.url}, state, rec)
    listener.close()
    assert counts == {"gymrats-api": 1, "gymrats-battle": 1}


def test_the_count_is_saved_before_the_restart(api, tmp_path):
    """A restart that is slow (or a check killed during it) must not leave the count at 3."""
    state = tmp_path / "state.json"
    seen = []
    rec = Recorder()

    def slow_restart(unit):
        seen.append(json.loads(state.read_text()))
        return True

    api.status = 500
    for _ in range(3):
        health_watch.check_once({"gymrats-api": api.url}, state, "", restart_unit=slow_restart,
                                send=rec.send, log=rec.lines.append)
    assert seen == [{"gymrats-api": 0}]


def test_an_alert_that_is_not_delivered_is_logged(api, tmp_path):
    rec, state = Recorder(), tmp_path / "state.json"
    api.status = 500
    for _ in range(3):
        health_watch.check_once({"gymrats-api": api.url}, state, "", restart_unit=rec.restart,
                                send=lambda w, t: False, log=rec.lines.append)
    assert rec.lines[-1].startswith("alert not delivered")


def test_only_the_webhook_is_read_from_the_env_file(tmp_path):
    env = tmp_path / ".env"
    env.write_text("JWT_SECRET=s3cret\n# note\nALERT_WEBHOOK_URL='https://hooks.example/a'\n")
    assert health_watch.env_value(env, "ALERT_WEBHOOK_URL") == "https://hooks.example/a"
    assert health_watch.env_value(env, "MISSING") == ""
    assert health_watch.env_value(tmp_path / "none", "ALERT_WEBHOOK_URL") == ""


def test_the_command_alerts_through_the_webhook_in_the_env_file(api, tmp_path, monkeypatch):
    monkeypatch.delenv("ALERT_WEBHOOK_URL", raising=False)
    hook = Endpoint()
    env = tmp_path / ".env"
    env.write_text(f"ALERT_WEBHOOK_URL={hook.url}\n")
    monkeypatch.setattr(health_watch, "restart", lambda unit: True)
    api.status = 500
    args = ["--state", str(tmp_path / "s.json"), "--env-file", str(env),
            "--service", f"gymrats-api={api.url}"]
    for _ in range(3):
        health_watch.main(args)
    hook.close()
    assert len(hook.posts) == 1 and "gymrats-api" in hook.posts[0]["content"]


def test_the_timer_runs_every_30_seconds_on_the_clock():
    timer = (Path(health_watch.__file__).parent / "gymrats-health.timer").read_text()
    assert "OnCalendar=*-*-* *:*:00/30" in timer
    assert health_watch.TIMEOUT_S == 5.0 and health_watch.FAILURES_TO_RESTART == 3
