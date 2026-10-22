#!/usr/bin/env bash
set -euo pipefail
# Run from an isolated upload directory as the authorized SSH user.
# Existing Django/nginx/config/database files are never replaced.
base=/srv/gymrats/battle
release="$base/releases/$(date -u +%Y%m%dT%H%M%SZ)-fifo"
mkdir -p "$base/runtime" "$release"
if [ ! -x "$base/runtime/dart-sdk/bin/dart" ]; then
  sdk_url=https://storage.googleapis.com/dart-archive/channels/stable/release/3.13.5/sdk/dartsdk-linux-x64-release.zip
  curl --fail --silent --show-error --location "$sdk_url" -o "$base/runtime/sdk.zip"
  curl --fail --silent --show-error --location "$sdk_url.sha256sum" -o "$base/runtime/sdk.sha256sum"
  expected=$(awk '{print $1}' "$base/runtime/sdk.sha256sum")
  actual=$(sha256sum "$base/runtime/sdk.zip" | awk '{print $1}')
  test "$expected" = "$actual"
  python3 -m zipfile -e "$base/runtime/sdk.zip" "$base/runtime"
  chmod -R u+rx "$base/runtime/dart-sdk/bin"
fi
tar -xf source.tar -C "$release"
"$base/runtime/dart-sdk/bin/dart" compile exe "$release/server/bin/server.dart" -o "$release/gymrats-battle"
test -x "$release/gymrats-battle"
if [ -L "$base/current" ]; then
  readlink "$base/current" > "$release/previous-release.txt"
fi
ln -s "$release" "$base/current.next"
mv -Tf "$base/current.next" "$base/current"
if [ -e /etc/systemd/system/gymrats-battle.service ]; then
  sudo cp -a /etc/systemd/system/gymrats-battle.service "$release/previous-service.conf"
fi
sudo install -m 644 server/deploy/gymrats-battle.service /etc/systemd/system/gymrats-battle.service
sudo systemctl daemon-reload
sudo systemctl enable --now gymrats-battle.service
sudo systemctl restart gymrats-battle.service
sleep 2
systemctl is-active gymrats-battle.service
curl --fail --silent http://127.0.0.1:8080/health
printf '\nRELEASE=%s\n' "$release"
