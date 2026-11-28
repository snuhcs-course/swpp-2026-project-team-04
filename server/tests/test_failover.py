"""P21: what the restore rehearsal relies on, on a test database.

The team server keeps SQLite; a backup is taken with SQLite's online backup
API (what `sqlite3 <db> ".backup <file>"` uses) while the API keeps serving,
and a restore writes such a file back over the database. These tests take a
backup of a live database, change it afterwards, restore the backup and check
that the restored data is exactly the backup's, passes the integrity check, and
serves the checks of the rehearsal: an existing account's history, its login, a
new sign-up, a result saved, and a battle cut by a restart left void.
"""

import sqlite3

import pytest
from django.db import connection

from accounts.models import User
from matches.models import Match, OnlineBattle

from .conftest import auth, match_body, sign_up
from .test_results import internal, result

pytestmark = pytest.mark.django_db(transaction=True)

BOOT = 1792022500000  # the restarted battle server's start, after every battle below


def _live():
    """The raw sqlite3 connection Django is using."""
    connection.ensure_connection()
    return connection.connection


def back_up(path):
    """An online backup of the live database to `path`, as on the server."""
    target = sqlite3.connect(path)
    try:
        _live().backup(target)
    finally:
        target.close()


def restore(path):
    """Writes the backup at `path` back over the live database."""
    source = sqlite3.connect(path)
    try:
        source.backup(_live())
    finally:
        source.close()


def integrity(path):
    with sqlite3.connect(path) as db:
        return db.execute("pragma integrity_check").fetchone()[0]


def login(client, password):
    return client.post(
        "/auth/login", {"login_id": "woohyun", "password": password}, format="json"
    )


def history(client, token):
    response = client.get("/matches", **auth(token))
    assert response.status_code == 200, response.content
    return response.json()["items"]


@pytest.fixture
def before(client):
    """Two accounts with history, as before the backup."""
    a = sign_up(client, login_id="woohyun", nickname="우현")
    b = sign_up(client, login_id="jinyoung", nickname="진영")
    for n in range(3):
        posted = client.post(
            "/matches", match_body(n, my_reps=10 + n), format="json", **auth(a["token"])
        )
        assert posted.status_code == 201, posted.content
    return a, b


def test_a_backup_of_the_live_database_passes_the_integrity_check(before, tmp_path):
    path = tmp_path / "backup.db"
    back_up(path)

    assert integrity(path) == "ok"
    with sqlite3.connect(path) as db:
        assert db.execute("select count(*) from matches_match").fetchone()[0] == 3
        assert db.execute("select count(*) from accounts_user").fetchone()[0] == 2


def test_a_restore_brings_back_the_backup_and_drops_what_came_after(client, before, tmp_path):
    a, _ = before
    path = tmp_path / "backup.db"
    back_up(path)
    # After the backup: one more battle and one more account, then the failure.
    client.post("/matches", match_body(9, my_reps=99), format="json", **auth(a["token"]))
    sign_up(client, login_id="newcomer", nickname="뉴비")
    assert Match.objects.count() == 4

    restore(path)

    assert Match.objects.count() == 3
    assert not User.objects.filter(login_id="newcomer").exists()
    # Newest first; the battle played after the backup (99 reps) is gone.
    assert [m["my_reps"] for m in history(client, a["token"])] == [12, 11, 10]


def test_after_a_restore_an_existing_account_logs_in_and_reads_its_history(client, before, tmp_path):
    a, _ = before
    path = tmp_path / "backup.db"
    back_up(path)
    # After the backup the account changes: a new password and one more battle.
    user = User.objects.get(login_id="woohyun")
    user.set_password("changed-after-backup")
    user.save()
    client.post("/matches", match_body(9, my_reps=99), format="json", **auth(a["token"]))
    assert login(client, "password1").status_code != 200

    restore(path)

    response = login(client, "password1")
    assert response.status_code == 200, response.content
    assert [m["my_reps"] for m in history(client, response.json()["token"])] == [12, 11, 10]


def test_after_a_restore_a_new_account_signs_up_and_a_result_is_saved(client, before, tmp_path):
    path = tmp_path / "backup.db"
    back_up(path)
    # Taken after the backup, so the restore frees the id again.
    sign_up(client, login_id="newcomer", nickname="뉴비")
    taken = client.post(
        "/auth/signup",
        {"login_id": "newcomer", "nickname": "뉴비", "password": "password1"},
        format="json",
    )
    assert taken.status_code == 409

    restore(path)

    new = sign_up(client, login_id="newcomer", nickname="뉴비")
    a = before[0]
    saved = internal(client, "results", result(a, new, result_id="after-restore"))
    assert saved.status_code == 201, saved.content
    assert saved.json()["saved"] == 2
    assert len(history(client, new["token"])) == 1
    assert len(history(client, a["token"])) == 4


def test_a_battle_running_at_the_backup_comes_back_active_and_the_restart_voids_it(
    client, before, tmp_path
):
    a, b = before
    started = internal(
        client,
        "battles/start",
        {
            "match_id": "running-0001",
            "player_ids": [str(a["user"]["id"]), str(b["user"]["id"])],
            "started_at_ms": BOOT - 10000,
        },
    )
    assert started.status_code == 201, started.content
    path = tmp_path / "backup.db"
    back_up(path)
    # After the backup the battle ended; the restore brings it back running.
    internal(client, "battles/void", {"match_id": "running-0001", "reason": "both_disconnected"})
    assert OnlineBattle.objects.get(match_id="running-0001").status == OnlineBattle.VOID

    restore(path)

    assert OnlineBattle.objects.get(match_id="running-0001").status == OnlineBattle.ACTIVE
    # The battle server on the restored machine starts and recovers.
    recovered = internal(client, "battles/recover", {"booted_at_ms": BOOT})

    assert recovered.status_code == 200, recovered.content
    assert [v["match_id"] for v in recovered.json()["voided"]] == ["running-0001"]
    battle = OnlineBattle.objects.get(match_id="running-0001")
    assert (battle.status, battle.reason) == (OnlineBattle.VOID, "server_restarted")
    # The cut battle leaves no row in anyone's history.
    assert len(history(client, a["token"])) == 3
    assert history(client, b["token"]) == []
