# GymRats API

Django + Django REST Framework backend for accounts and match history. The app
reaches it at `http://52.78.38.225/api` (nginx forwards `/api/` to gunicorn on
`127.0.0.1:8000`).

## Endpoints

| Method | Path | Body | Result |
|---|---|---|---|
| GET | `/health` | | `{"status": "ok"}` |
| POST | `/auth/signup` | `nickname`, `login_id`, `password` | 201 `{token, user}`; 409 `login_id_taken` |
| POST | `/auth/login` | `login_id`, `password` | 200 `{token, user}`; 401 `invalid_credentials` |
| GET | `/users/me` | | `{id, login_id, nickname, best_reps, last_match}` |
| POST | `/matches` | `client_id`, `exercise`, `opponent_name`, `my_reps`, `opponent_reps`, `played_at` | 201 the saved match; 200 when that `client_id` was saved before |
| GET | `/matches?limit=20&before=<id>` | | `{items, next_before}`, newest first |

Every endpoint except `/health`, sign-up, and login needs `Authorization: Bearer <token>`
(a JWT); without a valid one the answer is 401 `invalid_token`. A user only sees their
own matches. Invalid fields get 422 with the reasons in `detail`.

Rules: `login_id` is 4 to 20 lowercase letters, digits, or `_`; `nickname` is 1 to 12
characters; `password` is 8 to 64 characters. Passwords are stored as bcrypt hashes.

## Layout

```
gymrats/     settings, URLs, error format (exceptions.py), WSGI
accounts/    User model, sign-up, login, /users/me
matches/     Match model, save and list
tests/       pytest-django
deploy/      systemd unit and nginx snippet for the team server
```

## Run locally

```
cd server
python3.12 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
.venv/bin/python -m pytest
export DJANGO_SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(48))")
export JWT_SECRET=$(python3 -c "import secrets; print(secrets.token_urlsafe(48))")
.venv/bin/python manage.py migrate
.venv/bin/python manage.py runserver 0.0.0.0:8000
```

Without `DATABASE_URL` it uses `./gymrats.db`. The server refuses to start when a
secret is shorter than 32 characters. An emulator reaches this server at
`http://10.0.2.2:8000` (`flutter run --dart-define=GYMRATS_API=http://10.0.2.2:8000`).

## Deploy to the team server

Settings come from `/srv/gymrats/.env` (keys as in `.env.example`); never commit real values.

```
# on the server, as a member of the gymrats group
cd /srv/gymrats/backend            # a copy of this server/ folder
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
set -a; . /srv/gymrats/.env; set +a
.venv/bin/python manage.py migrate
sudo cp deploy/gymrats-api.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl restart gymrats-api
curl -s http://127.0.0.1:8000/health
```

nginx includes `deploy/nginx-gymrats-api.conf` in the port 80 site
(`/etc/nginx/sites-available/gymrats`). Check from outside with
`curl -s http://52.78.38.225/api/health`.
