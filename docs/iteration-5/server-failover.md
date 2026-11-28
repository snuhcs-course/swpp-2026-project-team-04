# Server restart, backup restoration and failover rehearsal (P21)

Owner: ishlove77 · 2026-11-28 · branch `feat/iter5-failover` · plan: P6 "GymRats P6 텔레메트리·서버 복구 계획"
(shared doc, 2026-11-24 draft: RTO 30 min and RPO 24 h are drafts until P3 confirms them)

The task: from the P6 plan, restart the API and battle processes, rehearse a backup restoration and a manual
failover in a separate environment, and record the detection and recovery times, the time of the restored data,
and whether existing history, a new login, matching and result saving work. The results go to the PM before beta.

## What was run where

| # | Rehearsal (P6 checklist) | Where | Decided by |
|---|---|---|---|
| 1 | API restart | team server, production `gymrats-api`, 0 live connections | user, 2026-11-28 |
| 2 | Battle server restart | team server, production `gymrats-battle`, 0 live connections | user |
| 3 | Unresponsive process detection | separate environment on the team server (below) | user (no Lightsail console access for a temporary instance) |
| 4 | DB backup restoration, then history, login, matching, results, a battle cut by a crash | separate environment on the team server | user |
| 5 | Static IP failover | not run: needs the Lightsail console (team admin only); procedure and estimate below | user |

**Separate environment:** `/srv/gymrats/rehearsal-p21/` on the team server: a copy of the deployed API code
(`/srv/gymrats/backend`, same virtualenv), the latest DB backup restored into its own SQLite file, gunicorn on
`127.0.0.1:8100` (2 workers, as production) and the deployed battle server binary on `127.0.0.1:8180`, wired to
each other as production is (`BATTLE_AUTH_URL`, `BATTLE_RESULTS_URL`). Secrets came from `/srv/gymrats/.env`
in the shell only (never printed); `DATABASE_URL` pointed at the rehearsal file, and the script stopped unless
Django reported that file. No port was opened; nginx, the production database and the production services were not
changed. Test accounts and battles were written to the rehearsal database only. The folder was deleted afterwards.
It shares the machine, so it does not show a machine failure; that is rehearsal 5.

## 1–2. Restarts on the team server (2026-11-28 08:26 UTC)

| | API `gymrats-api` | Battle server `gymrats-battle` |
|---|---:|---:|
| Restart issued | 08:26:43.134Z | 08:26:54.650Z |
| `systemctl restart` returned | 255 ms | 31 ms |
| Healthy again on the machine | 756 ms (`:8000/health`) | 153 ms (`:8080/health`) |
| Healthy through nginx | 772 ms (`/api/health`) | 167 ms (wss without a token → 401) |
| After | active, `NRestarts` 0; `https://52.78.38.225/api/health` 200 from outside | active, `NRestarts` 0 |
| Target (P6 draft) | 5 min | 5 min, a cut battle must not break records |

Live connections before each restart: 0. What a restart does to a battle in progress was checked in the separate
environment (4), not on production, so no test battle was left in the production database.

## 3. Unresponsive process detection

Production has no detector for a process that is alive but does not answer: both units restart only when the
process exits (`Restart=on-failure`, 3 s), and the P6 health-check timer is not installed (the PM decides whether
it goes on production). The rehearsal froze the separate environment's API (SIGSTOP on the gunicorn master and
both workers) and ran a watcher that follows the P6 rule: `GET /health` with a 5 s limit, then 60 s of sleep (so failed checks came 65 s
apart), and after 3 failures in a row it restarts only that service.

| Time (UTC) | Event |
|---|---|
| 08:59:13.155 | API frozen; `/health` no longer answers (curl 000) |
| 08:59:22.187 | check 1 failed |
| 09:00:27.200 | check 2 failed |
| 09:01:32.213 | check 3 failed → API restarted |
| 09:01:33.216 | API healthy again |

Frozen → healthy: **2 min 20 s** (P6 draft target: 3 min). The watcher started 4 s after the freeze. With the same
loop running all along, a freeze just after a passing check is found at +65, +130 and +195 s and the restart takes
about 1 s, so the worst case is about **3 min 16 s**, above the 3 min draft. A systemd timer firing every 60 s
regardless of the check's length would make it about 3 min. The
watcher was a script in the rehearsal folder, not a systemd timer; it was deleted with the folder.

## 4. Backup restoration (separate environment, 2026-11-28 08:42 UTC)

Backup used: `/srv/gymrats/data/backups/gymrats-20261128T052914Z-pre-p11.db` (the latest; taken before the P11
deploy at 05:29:15 UTC). Restored data time: 05:29:15 UTC, about 3 h 13 min before the rehearsal; the newest
battle in it was played at 2026-11-26 06:49:34 UTC.

| Step (from the assumed failure, 08:42:16.086Z) | Elapsed |
|---|---:|
| Code copied | 0.06 s |
| Database restored (SQLite online backup API), `pragma integrity_check` = ok; 65 accounts, 184 battles, 22 online battles | 0.16 s |
| `migrate` (the backup predates `accounts.0006`, `matches.0004`, `matches.0005`), then `migrate --check` clean | 1.55 s |
| API healthy (`:8100/health`) | 2.03 s |
| Battle server healthy (`:8180/health`) | 2.15 s |

Checks on the restored environment:

| Check | Result |
|---|---|
| Existing account's history | the account with the most battles: `GET /matches` 200, 15 items = its 15 rows, 43 ms |
| New sign-up and login | 2 new accounts: sign-up 201, login 200 |
| Matching (main queue, two real accounts) | `match.found` 1 ms after both joined |
| Result saving | 30 s round ended `time_up`; each account's history 200 with 1 row; online battle `finished`, +2 battle rows |
| Battle cut by a crash | battle server killed (SIGKILL) right after the round started (4 s after `match.found`): both clients see the socket close; the online battle stays `active`. Started again (healthy after 0.12 s), it marked the battle `void`, reason `server_restarted`; no battle row was added (the test accounts have 10 rows = 5 finished battles × 2) |

The check script was run four times: the first three stopped on bugs in the script's own client (no keep-alive
ping, no answer to the server's pings while reading the other socket, reused request ids); the numbers above are
the fourth run's. Not checked: Google sign-in (the app's address is fixed to the production IP, so a phone cannot reach the separate
environment; sign-in by id and password was checked instead), friend battles, and the app on a phone.

## 5. Static IP failover (not run)

Moving a static IP and creating an instance from a snapshot need the Lightsail console, which only the team admin
can use, so this was not run and its 30 min target (P6 draft: from detection to an app request succeeding on the
replacement) is **not verified**. What the rehearsal does measure is the part after the machine exists: restoring
the database, migrating and starting both services took 2.2 s (4). Not measured: making a snapshot, creating an
instance from it, attaching the static IP, and the app reaching the new machine.

Procedure for the admin (P6, unchanged), with what this rehearsal adds:
1. Announce the switch in the team chat.
2. Create an instance from the latest snapshot (or a fresh instance with the code and a DB backup restored as in 4).
   On a snapshot both services start at boot (`gymrats-battle` is enabled by `install-battle.sh` and pulls in
   `gymrats-api`), so as soon as it is up run `sudo systemctl stop gymrats-battle gymrats-api` and check both are
   inactive; after any reboot before step 4, stop them again. Otherwise the battle server's one-time start-up
   recovery runs against the snapshot's database, and a newer backup restored after it brings back `active` battles
   that are never voided; the API's open connections would also overlap the restore.
   **A fresh instance first needs what the snapshot would bring:** nginx and `python3-venv` installed; the `gymrats`
   group and the `jinyoung` and `sangwoo` users the units run as, both members of `gymrats`; `/srv/gymrats` with the
   group; the API code in `/srv/gymrats/backend` with its `.venv` and requirements;
   `server/deploy/gymrats-api.service` installed and `daemon-reload` (not started);
   `server/deploy/nginx-gymrats-http.conf` installed as `/etc/nginx/sites-available/gymrats`, linked into
   `sites-enabled`, `sites-enabled/default` removed (both claim `default_server`), then `nginx -t` and a reload.
   `install-https.sh` in step 5 expects that site to exist.
3. Put `.env` back (it is not in backups; group `gymrats`, mode 640, as the battle server reads it as `sangwoo`;
   check key names only, and that `DATABASE_URL` is `sqlite:////srv/gymrats/data/gymrats.db`, which is not a
   secret: without it Django falls back to an empty database in the backend folder). **Bring the API up to the
   release in production** if the snapshot is older than the last deploy (the commit is in the deploy notes): copy
   that commit's `server/` into `/srv/gymrats/backend`, install its requirements, reinstall `gymrats-api.service`
   and `daemon-reload` if the unit changed, without starting the service. With both services stopped, restore the
   newest DB backup if it is newer than the snapshot and run `pragma integrity_check`.
   The API runs as `jinyoung`, so `/srv/gymrats/data` and the restored `gymrats.db` must be writable by it, as on
   production (both owner `jinyoung`, group `gymrats`; directory 2775, file 644; SQLite writes its journal in the
   directory). Check with `sudo -u jinyoung test -w /srv/gymrats/data && sudo -u jinyoung test -w
   /srv/gymrats/data/gymrats.db`; if it fails, `sudo install -d -o jinyoung -g gymrats -m 2775 /srv/gymrats/data` and
   `sudo chown jinyoung:gymrats` plus `sudo chmod 644` on the file.
   Only then run **`migrate`** and `migrate --check` with the current code (a backup older than the code needs
   migrations; in 4 three were applied), as `jinyoung` from the backend with the service's environment, which
   systemd loads only for the unit: `cd /srv/gymrats/backend && sudo -u jinyoung bash -c 'set -a; . /srv/gymrats/.env;
   set +a; .venv/bin/python manage.py migrate && .venv/bin/python manage.py migrate --check'` (the secrets stay in
   that shell; Django stops without `DJANGO_SECRET_KEY` and `JWT_SECRET`).
4. Start `gymrats-api` and check its `/health` **before** starting the battle server. Then the battle server: on a
   fresh instance always, and on a snapshot whose battle release is behind, deploy the production commit with
   `server/deploy/install-battle.sh` (run from an upload directory holding that commit's `source.tar`, as the script
   says), which starts it; otherwise `sudo systemctl start gymrats-battle`. Then `sudo nginx -t && sudo systemctl
   reload nginx` (the new API code may change the included `nginx-gymrats-api.conf`), and check `/health` on both
   ports. `/health` does not touch the database, so before moving the IP also log in once on the machine with a team
   test account, the password typed at a prompt and never in the chat or shell history (`POST :8000/auth/login`) and
   read that account's `GET :8000/matches`; write access was checked in step 3. The battle server asks the API once
   at start-up (10 s limit, an error is ignored) to void the battles that were running at the backup (seen in 4); if
   the API was not up, restart `gymrats-battle` again once it is.
5. Move the static IP `52.78.38.225` to the new instance and check that its Lightsail firewall allows 80 (needed to
   issue the certificate) and 443 (firewall rules belong to each instance). Then the IP certificate, which is issued
   for the IP, so only after it is attached:
   - **Snapshot:** the files in `/srv/gymrats/battle/tls` come along, but they are short-lived certificates (about
     6 days), so an older snapshot brings an expired one, and the renewal timer's first run (10 min after boot) came
     before the IP was attached; the next is 6 h later. Check the date with `openssl x509 -enddate -noout -in
     /srv/gymrats/battle/tls/config/live/52.78.38.225/fullchain.pem` and run `sudo systemctl start
     gymrats-cert-renew.service`.
   - **Fresh instance:** create the certbot virtualenv the script expects (`python3 -m venv
     /srv/gymrats/battle/certbot-venv`, then its `pip install certbot` at the version production runs; the
     `shortlived` profile needs a recent one)
     and run `server/deploy/install-https.sh`, which installs the HTTPS site, issues the certificate and enables the
     renewal timer.
   Either way, `curl https://52.78.38.225/battle-health` must answer before step 6; until then HTTPS and WSS do not
   work for the installed app.
6. From outside: `/api/health`, a login, history, a battle and a stored result with the installed app; note the
   restored data time.

## Findings for the PM

1. **A hung process is not detected on production.** systemd restarts a service only when it exits. The P6 rule
   works (2 min 20 s in 3), but it is not installed; decision pending (P6 "미정 사항").
2. **Backups are made only before a deploy.** The newest was 3 h old today only because of the P11 deploy; the one
   before it was from 11-27 12:04 UTC. On days without a deploy the data loss can exceed the 24 h RPO draft. The
   P6 daily backup is not in place yet.
3. **Backups are on the same disk as the database.** If the machine is lost, so are they. Whether Lightsail
   snapshots exist was not checked (console access).
4. **A restore needs `migrate`.** A backup older than the deployed code is missing migrations; the procedure now says
   so (5, step 3).
5. **A battle cut by a crash stays `active` until the battle server starts again**, then becomes `void`
   (`server_restarted`) with no history rows. That start-up call is made once and its failure is ignored, so the
   API must be up first (5, step 4); on a replacement booted from a snapshot, both services must be stopped before
   the restore (5, step 2). While the battle server is down, the players' apps show the connection lost.
6. **Static IP failover is not rehearsed** and needs the team admin before beta. On a replacement, the code must be
   brought up to the production release before `migrate` if the snapshot is older than the last deploy; a fresh
   instance needs users, nginx's HTTP site and the battle release set up first; and the IP certificate must be
   renewed (snapshot) or issued (fresh) after the IP is attached, with ports 80 and 443 open (5, steps 2–5).

## Automated checks

`server/tests/test_failover.py` (pytest, in-memory SQLite) covers what the restoration relies on: a backup of a live
database passes the integrity check; a restore brings back exactly the backup and drops what came after; after a
restore an existing account logs in and reads its history, a new account signs up and a result is saved; a battle
running at the backup comes back `active` and the battle server's recovery voids it, with no history rows.

```sh
cd server
.venv/bin/python -m pytest tests/test_failover.py -q
```
