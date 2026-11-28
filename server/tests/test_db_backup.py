"""The 12-hour backup off the server (server/deploy/db_backup.py).

rclone is replaced by a fake that copies into a local folder standing for the storage
off the server; the webhook and the waits between tries are fakes too.
"""

import gzip
import json
import os
import shutil
import sqlite3
import stat
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "deploy"))
import db_backup  # noqa: E402

NOW = datetime(2026, 11, 28, 6, 0, tzinfo=timezone.utc)


class Done:
    def __init__(self, code=0, out="", err=""):
        self.returncode, self.stdout, self.stderr = code, out, err


class FakeRclone:
    """`remote:` paths live in a local folder; uploads can be made to fail."""

    def __init__(self, folder, fail_uploads=0, wrong_size=False):
        self.folder = Path(folder)
        self.fail_uploads = fail_uploads
        self.wrong_size = wrong_size
        self.calls = []

    def local(self, path):
        return self.folder / path.split(":", 1)[1].lstrip("/")

    def __call__(self, *args):
        self.calls.append(args)
        command, *rest = args
        if command == "copyto":
            source, target = rest
            if ":" in target:
                if self.fail_uploads:
                    self.fail_uploads -= 1
                    return Done(1, err="connection reset")
                self.local(target).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy(source, self.local(target))
            else:
                if not self.local(source).exists():
                    return Done(3, err="object not found")
                shutil.copy(self.local(source), target)
            return Done()
        if command == "lsf":
            return Done(0, out="".join(p.name + "\n" for p in sorted(self.local(rest[0]).iterdir())))
        if command == "lsjson":
            path = self.local(rest[0])
            if not path.exists():
                return Done(0, out="[]")
            size = path.stat().st_size + (1 if self.wrong_size else 0)
            return Done(0, out=json.dumps([{"Name": path.name, "Size": size}]))
        raise AssertionError(args)


class Recorder:
    def __init__(self):
        self.sent, self.slept, self.lines = [], [], []

    def send(self, webhook, text):
        self.sent.append(text)

    def sleep(self, seconds):
        self.slept.append(seconds)


@pytest.fixture
def database(tmp_path):
    path = tmp_path / "data" / "gymrats.db"
    path.parent.mkdir()
    with sqlite3.connect(path) as db:
        db.execute("create table matches_match (id integer primary key, my_reps integer)")
        db.executemany("insert into matches_match (my_reps) values (?)", [(10,), (11,), (12,)])
    return path


def run_backup(database, tmp_path, rclone, rec, remote="offsite:gymrats-backups"):
    return db_backup.backup(
        database, tmp_path / "backups", remote, "https://hooks.example/x", now=NOW,
        run=rclone, send=rec.send, sleep=rec.sleep, log=rec.lines.append,
    )


def reps(path):
    with sqlite3.connect(path) as db:
        return [r for (r,) in db.execute("select my_reps from matches_match order by id")]


def test_the_database_path_comes_from_a_sqlite_url():
    assert db_backup.database_path("sqlite:////srv/gymrats/data/gymrats.db") == Path(
        "/srv/gymrats/data/gymrats.db"
    )
    with pytest.raises(SystemExit):
        db_backup.database_path("postgres://db/gymrats")


def test_a_backup_is_checked_compressed_and_uploaded_off_the_server(database, tmp_path):
    rclone, rec = FakeRclone(tmp_path / "offsite"), Recorder()

    assert run_backup(database, tmp_path, rclone, rec) == 0

    name = "gymrats-20261128T060000Z-scheduled.db.gz"
    uploaded = tmp_path / "offsite" / "gymrats-backups" / name
    assert uploaded.exists() and (tmp_path / "backups" / name).exists()
    assert not (tmp_path / "backups" / name[:-3]).exists()  # only the compressed copy stays
    restored = tmp_path / "check.db"
    restored.write_bytes(gzip.decompress(uploaded.read_bytes()))
    assert reps(restored) == [10, 11, 12]
    assert rec.sent == [] and rec.slept == []


def test_the_backup_file_is_readable_by_owner_and_group_only(database, tmp_path):
    old = os.umask(0o002)
    try:
        run_backup(database, tmp_path, FakeRclone(tmp_path / "offsite"), Recorder())
    finally:
        os.umask(old)
    (packed,) = (tmp_path / "backups").iterdir()
    assert stat.S_IMODE(packed.stat().st_mode) == 0o640


def test_a_failed_upload_is_tried_again_after_1_and_5_minutes(database, tmp_path):
    rclone, rec = FakeRclone(tmp_path / "offsite", fail_uploads=2), Recorder()

    assert run_backup(database, tmp_path, rclone, rec) == 0

    assert rec.slept == [60, 300]
    assert rec.sent == []
    assert "uploaded to offsite:gymrats-backups (try 3)" in rec.lines


def test_three_failed_tries_alert_the_team_and_fail(database, tmp_path):
    rclone, rec = FakeRclone(tmp_path / "offsite", fail_uploads=3), Recorder()

    assert run_backup(database, tmp_path, rclone, rec) == 1

    (text,) = rec.sent
    assert "FAILED" in text and "3 tries" in text and "connection reset" in text
    assert "gymrats-20261128T060000Z-scheduled.db.gz" in text  # the local copy to use


def test_a_copy_of_the_wrong_size_off_the_server_counts_as_failed(database, tmp_path):
    rclone, rec = FakeRclone(tmp_path / "offsite", wrong_size=True), Recorder()
    assert run_backup(database, tmp_path, rclone, rec) == 1
    assert "size off the server" in rec.sent[0]


def test_a_copy_that_is_not_listed_counts_as_failed(database, tmp_path):
    packed = tmp_path / "x.gz"
    packed.write_bytes(b"x")

    def run(*args):
        return Done(0, out="[]") if args[0] == "lsjson" else Done()

    assert db_backup.upload(packed, "offsite:b", run=run) == "the uploaded copy is not listed"


def test_without_a_remote_the_team_is_told_the_copy_stayed_on_the_server(database, tmp_path):
    rec = Recorder()
    assert run_backup(database, tmp_path, FakeRclone(tmp_path / "o"), rec, remote="") == 1
    assert "BACKUP_REMOTE is not set" in rec.sent[0]


def test_a_backup_that_cannot_be_taken_alerts_the_team(tmp_path):
    rec = Recorder()
    missing = tmp_path / "missing.db"
    assert run_backup(missing, tmp_path, FakeRclone(tmp_path / "o"), rec) == 1
    assert "FAILED before upload" in rec.sent[0]


def test_a_backup_that_fails_its_integrity_check_is_dropped(database, tmp_path, monkeypatch):
    monkeypatch.setattr(db_backup, "integrity", lambda path: "row 3 missing from index")
    rec = Recorder()
    assert run_backup(database, tmp_path, FakeRclone(tmp_path / "o"), rec) == 1
    assert "integrity check" in rec.sent[0]
    assert list((tmp_path / "backups").iterdir()) == []


def test_a_backup_that_fails_halfway_leaves_no_partial_copy(database, tmp_path, monkeypatch):
    class Broken:
        def __init__(self, real):
            self.real = real

        def backup(self, target):
            raise sqlite3.OperationalError("disk I/O error")

        def close(self):
            self.real.close()

    real_connect = sqlite3.connect
    monkeypatch.setattr(db_backup.sqlite3, "connect",
                        lambda path, **kw: Broken(real_connect(path, **kw)) if kw.get("uri") else real_connect(path, **kw))
    rec = Recorder()
    assert run_backup(database, tmp_path, FakeRclone(tmp_path / "o"), rec) == 1
    assert "disk I/O error" in rec.sent[0]
    assert list((tmp_path / "backups").iterdir()) == []


def test_a_backup_that_fails_while_compressing_leaves_no_partial_copy(database, tmp_path, monkeypatch):
    def full_disk(src, dst, *args):
        dst.write(b"partial")
        raise OSError(28, "No space left on device")

    monkeypatch.setattr(db_backup.shutil, "copyfileobj", full_disk)
    rec = Recorder()
    assert run_backup(database, tmp_path, FakeRclone(tmp_path / "o"), rec) == 1
    assert "No space left" in rec.sent[0]
    assert list((tmp_path / "backups").iterdir()) == []


def test_old_local_copies_are_removed_even_when_the_upload_fails(database, tmp_path):
    folder = tmp_path / "backups"
    folder.mkdir()
    old = folder / f"gymrats-{(NOW - timedelta(days=31)):%Y%m%dT%H%M%SZ}-scheduled.db.gz"
    old.write_bytes(b"x")
    rec = Recorder()
    assert run_backup(database, tmp_path, FakeRclone(tmp_path / "o", fail_uploads=3), rec) == 1
    assert not old.exists()
    assert [p.name for p in folder.iterdir()] == ["gymrats-20261128T060000Z-scheduled.db.gz"]


def test_the_compressed_copy_is_640_while_it_is_written(database, tmp_path, monkeypatch):
    modes = []
    real = db_backup.shutil.copyfileobj

    def watch(src, dst, *args):
        modes.append(stat.S_IMODE(os.stat(tmp_path / "backups" / "gymrats-20261128T060000Z-scheduled.db.gz").st_mode))
        real(src, dst, *args)

    monkeypatch.setattr(db_backup.shutil, "copyfileobj", watch)
    old = os.umask(0o002)
    try:
        assert run_backup(database, tmp_path, FakeRclone(tmp_path / "offsite"), Recorder()) == 0
    finally:
        os.umask(old)
    assert modes == [0o640]


def test_local_copies_older_than_30_days_are_removed(database, tmp_path):
    folder = tmp_path / "backups"
    folder.mkdir()
    old = folder / f"gymrats-{(NOW - timedelta(days=31)):%Y%m%dT%H%M%SZ}-scheduled.db.gz"
    recent = folder / f"gymrats-{(NOW - timedelta(days=29)):%Y%m%dT%H%M%SZ}-scheduled.db.gz"
    deploy = folder / "gymrats-20261001T000000Z-pre-p11.db"  # made by a deploy: kept
    odd = folder / "gymrats-notadate-scheduled.db.gz"
    for path in (old, recent, deploy, odd):
        path.write_bytes(b"x")

    assert run_backup(database, tmp_path, FakeRclone(tmp_path / "offsite"), Recorder()) == 0

    assert not old.exists() and recent.exists() and deploy.exists() and odd.exists()


def test_the_copy_off_the_server_restores_the_database(database, tmp_path):
    rclone = FakeRclone(tmp_path / "offsite")
    run_backup(database, tmp_path, rclone, Recorder())
    shutil.rmtree(tmp_path / "backups")  # the machine is lost with its local copies
    database.unlink()

    lines = []
    code = db_backup.fetch("gymrats-20261128T060000Z-scheduled.db.gz", database,
                           "offsite:gymrats-backups", run=rclone, log=lines.append)

    assert code == 0
    assert lines == ["gymrats-20261128T060000Z-scheduled.db.gz: integrity ok", f"{database}: replaced"]
    assert reps(database) == [10, 11, 12]
    assert sorted(p.name for p in database.parent.iterdir()) == ["gymrats.db"]  # no temporary files
    assert stat.S_IMODE(database.stat().st_mode) == 0o640


def test_the_download_is_not_readable_by_others(database, tmp_path):
    rclone = FakeRclone(tmp_path / "offsite")
    run_backup(database, tmp_path, rclone, Recorder())
    seen = []

    def watching(*args):
        seen.append(os.umask(0o022))
        os.umask(seen[-1])
        return rclone(*args)

    old = os.umask(0o002)
    try:
        db_backup.fetch("gymrats-20261128T060000Z-scheduled.db.gz", tmp_path / "r.db",
                        "offsite:gymrats-backups", run=watching, log=lambda m: None)
        assert os.umask(old) == 0o002  # restored afterwards
    finally:
        os.umask(old)
    assert seen == [0o027]


def test_fetching_a_copy_that_is_not_there_fails(tmp_path):
    lines = []
    code = db_backup.fetch("nope.db.gz", tmp_path / "x.db", "offsite:b",
                           run=FakeRclone(tmp_path / "offsite"), log=lines.append)
    assert code == 1 and "object not found" in lines[0]


def test_a_damaged_copy_is_reported_and_does_not_replace_the_database(database, tmp_path):
    rclone = FakeRclone(tmp_path / "offsite")
    (tmp_path / "offsite" / "b").mkdir(parents=True)
    (tmp_path / "offsite" / "b" / "bad.db.gz").write_bytes(gzip.compress(b"x" * 4096))
    lines = []
    assert db_backup.fetch("bad.db.gz", database, "offsite:b", run=rclone, log=lines.append) == 1
    assert "not a database" in lines[0]
    assert reps(database) == [10, 11, 12]  # the database already there is kept
    assert sorted(p.name for p in database.parent.iterdir()) == ["gymrats.db"]


def test_a_copy_that_fails_its_check_does_not_replace_the_database(database, tmp_path, monkeypatch):
    rclone = FakeRclone(tmp_path / "offsite")
    run_backup(database, tmp_path, rclone, Recorder())
    monkeypatch.setattr(db_backup, "integrity", lambda path: "row 3 missing from index")
    with sqlite3.connect(database) as db:
        db.execute("insert into matches_match (my_reps) values (13)")
    lines = []
    assert db_backup.fetch("gymrats-20261128T060000Z-scheduled.db.gz", database,
                           "offsite:gymrats-backups", run=rclone, log=lines.append) == 1
    assert reps(database) == [10, 11, 12, 13]


def test_list_and_fetch_need_a_remote(monkeypatch):
    monkeypatch.delenv("BACKUP_REMOTE", raising=False)
    with pytest.raises(SystemExit):
        db_backup.main(["list"])


def test_the_command_backs_up_the_configured_database(database, tmp_path, monkeypatch):
    monkeypatch.setenv("DATABASE_URL", f"sqlite:///{database}")
    monkeypatch.setenv("BACKUP_REMOTE", "offsite:gymrats-backups")
    monkeypatch.delenv("ALERT_WEBHOOK_URL", raising=False)
    fake = FakeRclone(tmp_path / "offsite")
    monkeypatch.setattr(db_backup, "rclone", fake)

    class Clock(datetime):
        @classmethod
        def now(cls, tz=None):
            return NOW

    monkeypatch.setattr(db_backup, "datetime", Clock)
    name = "gymrats-20261128T060000Z-scheduled.db.gz"

    assert db_backup.main(["--folder", str(tmp_path / "backups"), "backup"]) == 0
    assert db_backup.main(["list"]) == 0
    assert db_backup.main(["fetch", name, str(tmp_path / "restored.db")]) == 0
    assert reps(tmp_path / "restored.db") == [10, 11, 12]


def test_a_missing_rclone_is_a_failed_upload(monkeypatch, tmp_path):
    def missing(cmd, **kw):
        raise FileNotFoundError("rclone")

    monkeypatch.setattr(db_backup.subprocess, "run", missing)
    packed = tmp_path / "x.gz"
    packed.write_bytes(b"x")
    assert "rclone" in db_backup.upload(packed, "offsite:b")


def test_an_rclone_call_that_hangs_is_a_failed_upload(monkeypatch, tmp_path):
    def hangs(cmd, **kw):
        raise db_backup.subprocess.TimeoutExpired(cmd, kw["timeout"])

    monkeypatch.setattr(db_backup.subprocess, "run", hangs)
    packed = tmp_path / "x.gz"
    packed.write_bytes(b"x")
    assert "timed out after 150 s" in db_backup.upload(packed, "offsite:b")


def test_an_unexpected_error_still_alerts_the_team(database, tmp_path, monkeypatch):
    def broken(*args, **kwargs):
        raise KeyError("surprise")

    monkeypatch.setattr(db_backup, "snapshot", broken)
    rec = Recorder()
    assert run_backup(database, tmp_path, FakeRclone(tmp_path / "o"), rec) == 1
    assert "FAILED: KeyError" in rec.sent[0]


def test_a_wrong_database_setting_alerts_the_team(monkeypatch):
    sent = []
    monkeypatch.setenv("DATABASE_URL", "postgres://db/gymrats")
    monkeypatch.setattr(db_backup, "notify", lambda webhook, text: sent.append(text) or True)
    assert db_backup.main(["backup"]) == 1
    assert "sqlite" in sent[0]


def test_an_alert_that_is_not_delivered_is_logged(database, tmp_path):
    lines = []
    db_backup.backup(database, tmp_path / "b", "", "", now=NOW, run=FakeRclone(tmp_path / "o"),
                     send=lambda w, t: False, log=lines.append)
    assert lines[-1].startswith("alert not delivered")


def test_the_rclone_helper_runs_rclone(monkeypatch):
    calls = []
    monkeypatch.setattr(db_backup.subprocess, "run", lambda cmd, **kw: calls.append(cmd) or Done())
    db_backup.rclone("lsf", "offsite:b")
    assert calls == [["rclone", "lsf", "offsite:b"]]


def test_the_timer_runs_every_12_hours():
    timer = (Path(db_backup.__file__).parent / "gymrats-backup.timer").read_text()
    assert "OnCalendar=*-*-* 03,15:00:00 Asia/Seoul" in timer and "Persistent=true" in timer
