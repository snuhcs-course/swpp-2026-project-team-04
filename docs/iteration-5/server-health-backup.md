# Production health check and backup off the server (P21 follow-up)

Owner: ishlove77 · 2026-11-28 · branch `feat/iter5-failover` · requested by the PM after #114 (relayed by the user)

The PM confirmed the beta targets: **RTO 30 min** (from detection to the app working again) and **RPO 24 h**
(data loss at most). The PM then asked for:

1. a production health check every 30 s, 5 s answer limit, restarting only the failing service after 3 failed
   checks in a row, and a check in an isolated environment that a freeze right after a passing check is recovered
   within 3 min;
2. a database backup off the server every 12 h, with a failure alert, retries, and a restore from the copy off the
   server.

Both are built and checked in an isolated environment. **Neither is installed on production yet**: the install
waits for this PR's merge and the user's OK (user decision), and the backup also needs storage off the server that
only the team admin can create (below).

## What was added

| File | What it does |
|---|---|
| `server/deploy/health_watch.py` | One check of both services (in parallel): `GET /health`, 200 within 5 s; any other outcome (refused, late, error status, a broken answer) is a failure. Counts failures per service in `/var/lib/gymrats-health/state.json`; on the 3rd in a row it saves the cleared count, asks systemd to restart that service only (`systemctl restart --no-block`, so a slow stop cannot hold up the check) and posts to the team chat webhook. A passing check clears the count. Reads only `ALERT_WEBHOOK_URL` from `/srv/gymrats/.env`; an alert that is not delivered is logged. |
| `server/deploy/gymrats-health.service`, `.timer` | Runs the check at :00 and :30 of every minute on the clock (`OnCalendar=*-*-* *:*:00/30`, `AccuracySec=1s`), as root so it can restart the units. The script runs from a root-owned copy in `/usr/local/lib/gymrats/`, not from the group-writable `/srv/gymrats` tree, and the unit loads no env file. |
| `server/deploy/gymrats-api.service` | `TimeoutStopSec=10` (was the 90 s default, as the battle server already has 10 s): a hung API that ignores SIGTERM is killed after 10 s, so the restart fits the 3 min target. |
| `server/deploy/db_backup.py` | `backup`: SQLite online backup (the API keeps serving), `pragma integrity_check`, gzip, file mode 640, upload with rclone to `BACKUP_REMOTE`, size check of the copy off the server; each rclone call is limited to 150 s; 3 tries (now, +1 min, +5 min), then a webhook alert and exit 1. Any other error (a wrong `DATABASE_URL`, an unexpected exception) also alerts. The compressed copy is mode 640 from the moment it is created (and the unit sets `UMask=0027`). Local scheduled copies older than 30 days are removed after every run, also when the upload fails (deploy backups are kept). `list` and `fetch NAME DEST` (download and unpack into a temporary file at mode 640, integrity check, and only then replace `DEST`, so a bad copy never overwrites a database already there) for the restore. A copy's name is the time it was **taken**, not how new its data is (see finding 4). |
| `server/deploy/gymrats-backup.service`, `.timer` | Runs `backup` at 03:00 and 15:00 KST (`Persistent=true`, so a run missed while the machine was off starts at boot), as `jinyoung`, with `/srv/gymrats/.env`, `UMask=0027`, a 25 min limit and `TimeoutStopSec=30`: at the limit systemd sends SIGTERM, which the script turns into a failure that cleans up and alerts. |

Only the Python standard library and rclone are used.

## Isolated environment (team server, 2026-11-28 14:45–15:00 UTC, user's OK)

`/srv/gymrats/rehearsal-health/` on the team server (deleted afterwards):

- **Code and data:** a copy of the deployed API code, with the latest DB backup
  (`gymrats-20261128T052914Z-pre-p11.db`) restored into its own file and migrated with the procedure's command.
- **Services:** gunicorn on `127.0.0.1:8100` and the deployed battle server binary on `127.0.0.1:8180`. Both ran as
  transient systemd units (`gymrats-rh-api`, `gymrats-rh-battle`) so that `systemctl restart` works as on
  production.
- **Health check:** the new script on a 30 s timer (`gymrats-rh-health`), checking those two units only.
- **Alerts:** a stand-in webhook on `127.0.0.1:8199` that logs every POST.
- **Backup tools:** rclone v1.68.2 downloaded into the folder (SHA256 checked against rclone's `SHA256SUMS`), not
  installed with apt.

What was not changed:

- No port was opened.
- nginx, the production database and the production services were not changed. After the cleanup, `gymrats-api` and
  `gymrats-battle` were active with `NRestarts=0`, and `https://52.78.38.225/api/health` returned 200.

### Health check: freeze right after a passing check

Each service was frozen with `systemctl kill -s SIGSTOP <unit>` (every process of the unit) within 25 ms of a check
that had just passed. The time was measured until `/health` answered 200 again.

| | API (`:8100`) | Battle server (`:8180`) |
|---|---|---|
| Passing check ended | 14:49:00.971Z | 14:51:00.971Z |
| Frozen | 14:49:00.991Z | 14:51:00.991Z |
| Failed checks (journal) | 14:49:35.9, 14:50:05.9, 14:50:36.2 | 14:51:35.9, 14:52:05.9, 14:52:35.96 |
| Restart and alert | 14:50:36.18Z, "restart done" | 14:52:35.95Z, "restart done" |
| Healthy again | 14:50:36.671Z | 14:52:36.457Z |
| **Frozen → healthy** | **95.7 s** | **95.5 s** |
| Target (PM) | 3 min | 3 min |

The restart and alert times are from the stand-in webhook's clock. The journal times are when the script's output
was flushed, at its exit, which is why the third failure shows a few ms after the restart. The script now logs
unbuffered, so later runs show the real order.

- Only the frozen unit was restarted; the other unit's count stayed 0 throughout.
- A first, unplanned run gave the same result for the API: frozen 14:47:00.964Z, restarted 14:48:36.2Z.
  - That run happened because the measuring script stopped early on its own bug (a failing `curl` under `pipefail`).
- A freeze right after a passing check is the worst case for **detection**:
  - the check that follows comes 30 s later, and the next one 60 s later, without waiting for a slow check;
  - each failure takes the 5 s limit;
  - so the restart starts about 95 s after the freeze.
- **Recovery** also depends on how fast the frozen process stops:
  - SIGSTOP is the friendly case: systemd sends SIGCONT with its SIGTERM, so the stop took under 1 s.
  - A process that ignores SIGTERM is killed after the unit's `TimeoutStopSec`. That is now 10 s for both units
    (the API had the 90 s default, which would have made about 185 s, over the target).
  - So the worst case is about 95 + 10 s plus the start (under 1 s here), about 1 min 46 s.
  - Not rehearsed: a process ignoring SIGTERM, and the new `--no-block` restart. The run used the earlier version,
    which waited for the restart; both behave the same for a stop that answers SIGTERM.

### Backup off the server

The copy "off the server" went to an rclone local folder (`:local:.../offsite`) inside the rehearsal folder, because
the real storage does not exist yet. This checks the script, rclone, the retries, the alert and the restore path. It
does not check a real bucket or the network.

| Check | Result |
|---|---|
| Backup with the upload working | 14:53:04Z: integrity ok, 2,483,127 bytes compressed, uploaded on try 1, size matched; 1.4 s in all |
| Upload failing (target `:local:/proc/...`, which cannot be written) | tries at 14:53:07, 14:54:07 (+1 min), 14:59:07 (+5 min); after the 3rd, the alert arrived at 14:59:07.679Z with the error and the name of the local copy; exit 1 |
| File mode | the first run left the copy at 664 under the server's umask 0002 (the database has password hashes) → fixed to 640; rerun gave `-rw-r----- jinyoung gymrats` |
| Restore from the copy off the server | account A signed up before the backup and account B after it. After the backup: local backups deleted, health timer and both services stopped, then `fetch` (integrity ok), the file put in place, `test -w` as `jinyoung` ok, `migrate --check` clean, services started. Account A: login 200, `GET /matches` 200. Account B: login 401 (it came after the backup). |

The time from "loss" to both services healthy was about 12 s. That is not a clean number: the transient units are
removed when stopped, so the first start failed and the units were created again by hand.

## Findings

1. **The restore must stop the health check first.**
   - During a restore the services are stopped on purpose. The health check would count them as failed and restart
     them after about 95 s.
   - `server-failover.md` (section 5, steps 2 and 4) now stops both timers (`gymrats-health.timer` and
     `gymrats-backup.timer`, finding 3) with the services and starts them again after both services are up.
2. **Backup files need mode 640.**
   - The new script now sets it.
   - The backups made before deploys in `/srv/gymrats/data/backups` are 644, so every user on the machine can read
     them, password hashes included. Who makes them (the deploy steps) should set 640 too. Not changed here: those
     files belong to the deploy procedure.
3. **The restore must also stop the backup timer.**
   - On a replacement booted from a snapshot, `Persistent=true` makes the missed backup run at boot.
   - That run would upload the snapshot's old data under a new time, and it would then look like the newest copy.
   - `server-failover.md` step 2 now stops `gymrats-backup.timer` too, and step 4 starts it again.
4. **A copy's name is when it was taken.** Before a restore, pick by the data in it, not only by the name.
   - `fetch` checks integrity.
   - Look at the newest `played_at` in the fetched file before using it.
5. **No storage off the server exists yet.**
   - Until the team admin creates a Lightsail bucket and a key for it, RPO 24 h is met only while the machine
     survives.
   - Backups before deploys sit on the same disk as the database (P21 finding 3).

## Installing on production (after merge, with the user's OK; each step stated before it runs)

The team admin creates, in the Lightsail console:

- a bucket (Seoul);
- an access key for that bucket only.

Then, on the server:

1. Install rclone (`sudo apt-get install -y rclone`, or the checked binary used here in `/usr/local/bin`), and the
   health script root-owned: `sudo install -D -m 755 -o root -g root server/deploy/health_watch.py
   /usr/local/lib/gymrats/health_watch.py`.
2. Write `/srv/gymrats/rclone.conf` (mode 640, group `gymrats`) with an S3 remote `gymrats-offsite` for the bucket
   (provider AWS, region `ap-northeast-2`). Put the key there, never in chat or the repo.
3. Add to `/srv/gymrats/.env`; check names only:
   - `RCLONE_CONFIG=/srv/gymrats/rclone.conf`
   - `BACKUP_REMOTE=gymrats-offsite:<bucket>/gymrats-backups`
   - `ALERT_WEBHOOK_URL=<team chat webhook>`
4. Copy `server/` into `/srv/gymrats/backend` as in a deploy, so `deploy/health_watch.py` and `deploy/db_backup.py`
   are there.
5. Install and start the timers:

   ```sh
   sudo install -m 644 server/deploy/gymrats-health.service server/deploy/gymrats-health.timer \
     server/deploy/gymrats-backup.service server/deploy/gymrats-backup.timer \
     server/deploy/gymrats-api.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable --now gymrats-health.timer gymrats-backup.timer
   ```

6. Check everything works (`sudo -u jinyoung test -w /srv/gymrats/data/backups` first):
   - `sudo systemctl start gymrats-backup.service`, then `journalctl -u gymrats-backup` shows "uploaded … (try 1)",
     and `db_backup.py list` shows the copy.
   - `journalctl -u gymrats-health` shows no failures.
   - Post one test message through the same code:
     `sudo python3 -c 'import sys; sys.path.insert(0, "/usr/local/lib/gymrats"); import health_watch as h; print(h.notify(h.env_value("/srv/gymrats/.env", "ALERT_WEBHOOK_URL"), "[GymRats] test"))'`
     prints `True`.
   - Then restore one copy off the server in an isolated folder, as above.

## Automated checks

```sh
cd server
.venv/bin/python -m pytest tests/test_health_watch.py tests/test_db_backup.py -q
.venv/bin/python -m pytest tests/test_health_watch.py tests/test_db_backup.py --cov=deploy --cov-report=term-missing
```

The tests use local HTTP servers for the services and the webhook, and a fake rclone that copies into a local folder.
`health_watch.py` and `db_backup.py` are each 99% covered; the line not covered in each is the `sys.exit(main())`
entry.
