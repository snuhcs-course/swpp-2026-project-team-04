#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
base=/srv/gymrats/battle
backup="$base/https-backups/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$backup" "$base/acme-webroot/.well-known/acme-challenge"
sudo cp -a /etc/nginx/sites-available/gymrats "$backup/gymrats-http.conf"
sudo install -m 644 nginx-gymrats-http.conf /etc/nginx/sites-available/gymrats
if ! sudo nginx -t; then
  sudo cp -a "$backup/gymrats-http.conf" /etc/nginx/sites-available/gymrats
  exit 1
fi
sudo systemctl reload nginx
sudo mkdir -p "$base/tls/config" "$base/tls/work" "$base/tls/logs"
sudo chmod 700 "$base/tls/config" "$base/tls/work" "$base/tls/logs"
sudo "$base/certbot-venv/bin/certbot" certonly --non-interactive --agree-tos --register-unsafely-without-email \
  --required-profile shortlived --webroot --webroot-path "$base/acme-webroot" \
  --ip-address 52.78.38.225 --cert-name 52.78.38.225 \
  --config-dir "$base/tls/config" --work-dir "$base/tls/work" --logs-dir "$base/tls/logs"
sudo install -m 644 nginx-gymrats-https.conf /etc/nginx/sites-available/gymrats-https
sudo ln -sf /etc/nginx/sites-available/gymrats-https /etc/nginx/sites-enabled/gymrats-https
if ! sudo nginx -t; then
  sudo unlink /etc/nginx/sites-enabled/gymrats-https
  exit 1
fi
sudo systemctl reload nginx
sudo install -m 644 gymrats-cert-renew.service gymrats-cert-renew.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now gymrats-cert-renew.timer
curl --fail --silent https://52.78.38.225/battle-health
printf '\nHTTPS_READY\n'
