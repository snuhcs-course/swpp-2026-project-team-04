#!/usr/bin/env python3
"""One health check of the GymRats services, run every 30 s by gymrats-health.timer.

Each service's /health must answer 200 within 5 s. A failure is counted in a small
state file; after 3 failed checks in a row only that service is restarted, the count
is cleared, and the team chat webhook (ALERT_WEBHOOK_URL) is told. A passing check
clears the count. The webhook URL is the only value read from the env file. Standard
library only, so it runs with the system Python.
"""

import argparse
import json
import os
import subprocess
import sys
import threading
import time
import urllib.request
from pathlib import Path

SERVICES = {
    "gymrats-api": "http://127.0.0.1:8000/health",
    "gymrats-battle": "http://127.0.0.1:8080/health",
}
TIMEOUT_S = 5.0
FAILURES_TO_RESTART = 3
USER_AGENT = "GymRats-ops/1.0"  # some webhook front ends refuse urllib's default agent


def log(message):
    print(message, flush=True)  # unbuffered, so journal times are the times of the events


def healthy(url, timeout=TIMEOUT_S):
    """True when `url` answers 200 within `timeout` seconds; any other outcome is False."""
    try:
        with urllib.request.urlopen(url, timeout=timeout) as response:
            return response.status == 200
    except Exception:  # refused, timeout, HTTP error, a broken answer: all unhealthy
        return False


def notify(webhook, text, timeout=5.0):
    """Posts `text` to a Discord or Slack style webhook; never raises."""
    if not webhook:
        return False
    body = json.dumps({"content": text, "text": text}).encode()
    request = urllib.request.Request(
        webhook, data=body, method="POST",
        headers={"Content-Type": "application/json", "User-Agent": USER_AGENT},
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return 200 <= response.status < 300
    except Exception:
        return False


def env_value(path, key):
    """`key`'s value from a KEY=value file, or "" (other keys are not read into memory)."""
    try:
        for line in Path(path).read_text().splitlines():
            name, sep, value = line.strip().partition("=")
            if sep and name == key:
                return value.strip().strip('"').strip("'")
    except OSError:
        pass
    return ""


def load_state(path):
    try:
        data = json.loads(Path(path).read_text())
        return {name: count for name, count in data.items() if isinstance(count, int)}
    except (OSError, ValueError, AttributeError):
        return {}


def save_state(path, state):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(state))
    os.replace(tmp, path)


def restart(unit):
    """Asks systemd to restart one unit without waiting for it; True if the job was queued.

    Not waiting keeps the check short even when the stop takes the unit's whole
    TimeoutStopSec; systemd carries the restart through on its own.
    """
    try:
        done = subprocess.run(["systemctl", "restart", "--no-block", unit],
                              capture_output=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return False
    return done.returncode == 0


def check_once(services, state_path, webhook, *, probe=healthy, restart_unit=restart,
               send=notify, host="team server", log=log, deadline=TIMEOUT_S):
    """Checks every service once (in parallel) and acts on 3 failures in a row.

    `deadline` bounds the whole check: the socket timeout in `healthy` applies to each
    read, so an answer that trickles in could take longer. A probe still running at the
    deadline counts as failed, and a late answer is ignored. Returns the new counts.
    """
    answers = {}

    def run(name, url):
        answers[name] = probe(url)

    threads = [threading.Thread(target=run, args=item, daemon=True) for item in services.items()]
    for thread in threads:
        thread.start()
    end = time.monotonic() + deadline
    for thread in threads:
        thread.join(max(0.0, end - time.monotonic()))
    results = {name: answers.get(name) is True for name in services}  # read once, at the deadline

    state = load_state(state_path)
    counts = {name: (0 if results[name] else state.get(name, 0) + 1) for name in services}
    due = [name for name, count in counts.items() if count >= FAILURES_TO_RESTART]
    for name, count in counts.items():
        if count:
            log(f"{name}: health check failed ({count} in a row)")
    for name in due:
        counts[name] = 0
    # Saved before acting, so a restart that is slow or a check that is killed
    # cannot leave the count at 3 and skip the alert next time.
    save_state(state_path, counts)
    for name in due:
        ok = restart_unit(name)
        message = (
            f"[GymRats] {name} on {host} failed {FAILURES_TO_RESTART} health checks in a row"
            f" ({TIMEOUT_S:.0f} s limit); restart {'requested' if ok else 'FAILED to start'}."
        )
        log(message)
        if not send(webhook, message):
            log("alert not delivered (no webhook set, or the webhook refused it)")
    return counts


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--state", default="/var/lib/gymrats-health/state.json")
    parser.add_argument("--env-file", default="/srv/gymrats/.env",
                        help="file holding ALERT_WEBHOOK_URL (only that key is read)")
    parser.add_argument(
        "--service", action="append", metavar="UNIT=URL",
        help="override the checked services (repeatable); default: API and battle server",
    )
    args = parser.parse_args(argv)
    services = SERVICES
    if args.service:
        services = dict(item.split("=", 1) for item in args.service)
    webhook = os.environ.get("ALERT_WEBHOOK_URL") or env_value(args.env_file, "ALERT_WEBHOOK_URL")
    check_once(services, args.state, webhook, host=os.uname().nodename)
    return 0


if __name__ == "__main__":
    sys.exit(main())
