#!/usr/bin/env python3
"""GymRats database backup off the server, run every 12 hours by gymrats-backup.timer.

`backup` takes an online SQLite backup (the API keeps serving), checks it with
`pragma integrity_check`, compresses it and uploads it with rclone to BACKUP_REMOTE
(an rclone remote outside the team server, e.g. `gymrats-offsite:gymrats-backups`).
The upload is retried; if every try fails the team chat webhook (ALERT_WEBHOOK_URL)
is told and the command exits 1. Local copies older than 30 days are removed.

`list` shows the copies off the server, and `fetch NAME DEST` downloads one, unpacks
it and checks its integrity, ready for the restore in docs/iteration-5/server-failover.md.

Settings come from /srv/gymrats/.env (DATABASE_URL, BACKUP_REMOTE, ALERT_WEBHOOK_URL;
rclone reads RCLONE_CONFIG). Standard library only.
"""

import argparse
import gzip
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parent))
from health_watch import log, notify  # noqa: E402

RETRY_DELAYS_S = (60, 300)  # 3 tries: now, after 1 min, after 5 more
RCLONE_TIMEOUT_S = 150  # per rclone call: 3 tries x 2 calls x 150 s + 360 s of waits = 21 min, under the unit's 25 min
KEEP_DAYS = 30


def _alert(send, webhook, message, log):
    if not send(webhook, message):
        log("alert not delivered (no webhook set, or the webhook refused it)")


def database_path(url):
    """The file of a `sqlite:///...` DATABASE_URL."""
    prefix = "sqlite:///"
    if not url.startswith(prefix):
        raise SystemExit("DATABASE_URL must be a sqlite:/// URL")
    return Path(url[len(prefix):])


def integrity(path):
    with sqlite3.connect(path) as db:
        return db.execute("pragma integrity_check").fetchone()[0]


def snapshot(database, folder, now):
    """An online backup of `database`, checked and gzipped; returns the .gz path."""
    folder = Path(folder)
    folder.mkdir(parents=True, exist_ok=True)
    name = f"gymrats-{now.strftime('%Y%m%dT%H%M%SZ')}-scheduled.db"
    raw = folder / name
    raw.touch(mode=0o600)
    packed = folder / (name + ".gz")
    try:
        source = sqlite3.connect(f"file:{database}?mode=ro", uri=True)
        target = sqlite3.connect(raw)
        try:
            source.backup(target)
        finally:
            target.close()
            source.close()
        result = integrity(raw)
        if result != "ok":
            raise RuntimeError(f"integrity check of the new backup: {result}")
        # Created 640 from the start (not after writing), whatever the umask.
        fd = os.open(packed, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        os.fchmod(fd, 0o640)
        with open(raw, "rb") as src, open(fd, "wb") as out, gzip.GzipFile(fileobj=out, mode="wb") as dst:
            shutil.copyfileobj(src, dst)
    except BaseException:
        # A partial or unchecked copy is never pruned (only .db.gz is), so remove it.
        packed.unlink(missing_ok=True)
        raise
    finally:
        raw.unlink(missing_ok=True)
    return packed


def rclone(*args, timeout=RCLONE_TIMEOUT_S):
    try:
        return subprocess.run(["rclone", *args], capture_output=True, text=True, timeout=timeout)
    except OSError as error:  # rclone not installed
        return subprocess.CompletedProcess(["rclone", *args], 127, "", str(error))
    except subprocess.TimeoutExpired:
        return subprocess.CompletedProcess(["rclone", *args], 124, "", f"rclone {args[0]} timed out after {timeout} s")


def upload(path, remote, *, run=None):
    """Copies `path` to `remote` and checks the size there; returns an error or None."""
    run = run or rclone
    target = f"{remote.rstrip('/')}/{Path(path).name}"
    done = run("copyto", str(path), target)
    if done.returncode != 0:
        return (done.stderr or "rclone copyto failed").strip()[-300:]
    listed = run("lsjson", target)
    try:
        size = json.loads(listed.stdout)[0]["Size"]
    except (ValueError, IndexError, KeyError, TypeError):
        return "the uploaded copy is not listed"
    if size != Path(path).stat().st_size:
        return f"size off the server {size} != {Path(path).stat().st_size}"
    return None


def prune(folder, now, keep_days=KEEP_DAYS):
    """Removes local scheduled backups older than `keep_days`; returns their names."""
    removed = []
    for path in sorted(Path(folder).glob("gymrats-*-scheduled.db.gz")):
        stamp = path.name.split("-")[1]
        try:
            taken = datetime.strptime(stamp, "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
        except ValueError:
            continue
        if now - taken > timedelta(days=keep_days):
            path.unlink()
            removed.append(path.name)
    return removed


def backup(database, folder, remote, webhook, *, now=None, run=None, send=notify,
           sleep=time.sleep, delays=RETRY_DELAYS_S, host="team server", log=log):
    """One scheduled backup; returns 0 when the copy off the server is in place.

    Any error, expected or not, ends in an alert and exit 1, never a silent failure.
    """
    try:
        return _backup(database, folder, remote, webhook, now=now, run=run, send=send,
                       sleep=sleep, delays=delays, host=host, log=log)
    except Exception as error:  # a bug or an unexpected system error
        message = f"[GymRats] DB backup on {host} FAILED: {type(error).__name__}: {error}"
        log(message)
        _alert(send, webhook, message, log)
        return 1


def _backup(database, folder, remote, webhook, *, now, run, send, sleep, delays, host, log):
    now = now or datetime.now(timezone.utc)
    try:
        return _take_and_upload(database, folder, remote, webhook, now=now, run=run, send=send,
                                sleep=sleep, delays=delays, host=host, log=log)
    finally:
        # Also when the upload fails: a long outage must not keep old copies for good.
        # The newest copy is never older than 30 days, so it is always kept.
        for name in prune(folder, now):
            log(f"removed old local backup {name}")


def _take_and_upload(database, folder, remote, webhook, *, now, run, send, sleep, delays, host, log):
    try:
        packed = snapshot(database, folder, now)
    except (sqlite3.Error, OSError, RuntimeError) as error:
        message = f"[GymRats] DB backup on {host} FAILED before upload: {error}"
        log(message)
        _alert(send, webhook, message, log)
        return 1
    log(f"backup {packed.name}: integrity ok, {packed.stat().st_size} bytes")
    if not remote:
        message = f"[GymRats] DB backup on {host} kept only on the server: BACKUP_REMOTE is not set"
        log(message)
        _alert(send, webhook, message, log)
        return 1
    error = None
    for attempt, delay in enumerate((0, *delays), start=1):
        if delay:
            sleep(delay)
        error = upload(packed, remote, run=run)
        if error is None:
            log(f"uploaded to {remote} (try {attempt})")
            return 0
        log(f"upload try {attempt} failed: {error}")
    message = (
        f"[GymRats] DB backup on {host} FAILED to reach {remote} after"
        f" {len(delays) + 1} tries: {error}. Local copy: {packed.name}"
    )
    log(message)
    _alert(send, webhook, message, log)
    return 1


def fetch(name, dest, remote, *, run=None, log=log):
    """Downloads one copy from `remote`, unpacks it next to `dest` and checks it.

    `dest` is replaced only when the copy passes the integrity check, so a bad copy
    never overwrites a database that is already there.
    """
    run = run or rclone
    dest = Path(dest)
    packed = dest.with_name(f".{dest.name}.fetch.gz")
    unpacked = dest.with_name(f".{dest.name}.fetch")
    # Run by hand, not by the unit: rclone's download must not be readable by others either.
    old_umask = os.umask(0o027)
    try:
        done = run("copyto", f"{remote.rstrip('/')}/{name}", str(packed))
        if done.returncode != 0:
            log((done.stderr or "rclone copyto failed").strip()[-300:])
            return 1
        fd = os.open(unpacked, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        os.fchmod(fd, 0o640)  # password hashes inside: owner and group (the API runs as jinyoung:gymrats)
        with gzip.open(packed, "rb") as src, open(fd, "wb") as dst:
            shutil.copyfileobj(src, dst)
        try:
            result = integrity(unpacked)
        except sqlite3.DatabaseError as error:  # not a database at all
            result = str(error)
        log(f"{name}: integrity {result}")
        if result != "ok":
            return 1
        os.replace(unpacked, dest)
        log(f"{dest}: replaced")
        return 0
    finally:
        os.umask(old_umask)
        packed.unlink(missing_ok=True)
        unpacked.unlink(missing_ok=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("backup")
    sub.add_parser("list")
    get = sub.add_parser("fetch")
    get.add_argument("name")
    get.add_argument("dest")
    parser.add_argument("--folder", default="/srv/gymrats/data/backups")
    args = parser.parse_args(argv)
    remote = os.environ.get("BACKUP_REMOTE", "")
    if args.command == "backup":
        webhook, host = os.environ.get("ALERT_WEBHOOK_URL", ""), os.uname().nodename
        try:
            database = database_path(os.environ.get("DATABASE_URL", ""))
        except SystemExit as error:
            message = f"[GymRats] DB backup on {host} FAILED: {error}"
            log(message)
            _alert(notify, webhook, message, log)
            return 1
        return backup(database, args.folder, remote, webhook, host=host)
    if not remote:
        raise SystemExit("BACKUP_REMOTE is not set")
    if args.command == "list":
        listed = rclone("lsf", remote)
        print(listed.stdout, end="")
        return listed.returncode
    return fetch(args.name, args.dest, remote)


if __name__ == "__main__":
    sys.exit(main())
