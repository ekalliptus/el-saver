#!/usr/bin/env bash
# Clean, idempotent deploy for the ANR Saver backend on a fresh Ubuntu/Debian VPS.
# Layout:
#   /opt/anrsaver/server   <- this repo's server/ dir
#   /opt/anrsaver/venv     <- python venv for the two API services
#   /opt/anrsaver/.env     <- config (from .env.example)
#   Cobalt (9000) via docker compose; ytdlp-api (9002) + cookie-sync (9005) via systemd.
#
# Usage (from the server/ dir on the VPS, as root):
#   sudo bash install-vps.sh
set -euo pipefail

APP_DIR=/opt/anrsaver
SRC_DIR="$APP_DIR/server"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ $EUID -eq 0 ]] || { echo "Run as root (sudo)."; exit 1; }

echo ">> Installing OS deps (docker, python, ffmpeg)..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq python3 python3-venv python3-pip ffmpeg curl ufw caddy
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi
docker compose version >/dev/null 2>&1 || apt-get install -y -qq docker-compose-plugin

echo ">> Syncing source to $SRC_DIR..."
mkdir -p "$SRC_DIR" "$APP_DIR/cookies" "$APP_DIR/downloads"
cp -f "$SELF_DIR"/*.py "$SELF_DIR/requirements.txt" "$SELF_DIR/docker-compose.yml" "$SELF_DIR/Caddyfile" "$SRC_DIR/"

# cookies.json must exist as a FILE before docker mounts it (else docker makes a dir)
[[ -f "$APP_DIR/cookies.json" ]] || echo '{}' > "$APP_DIR/cookies.json"

echo ">> Service user (both API services run unprivileged)..."
id -u anrsaver &>/dev/null || useradd --system --home-dir "$APP_DIR" --shell /usr/sbin/nologin anrsaver
chown -R anrsaver:anrsaver "$APP_DIR/cookies" "$APP_DIR/downloads"
[[ -f "$APP_DIR/cookies.json" ]] && chown anrsaver:anrsaver "$APP_DIR/cookies.json"
chown anrsaver:anrsaver "$APP_DIR"/premium-*.json 2>/dev/null || true

echo ">> Config (.env)..."
if [[ ! -f "$APP_DIR/.env" ]]; then
  cp "$SELF_DIR/.env.example" "$APP_DIR/.env"
  echo "   -> created $APP_DIR/.env (fill API_KEY, ADMIN_KEY, WEBHOOK_SECRET, STATIC_QRIS)"
fi
# Generate missing secrets so the services' fail-loud checks pass.
if ! grep -q '^ADMIN_KEY=' "$APP_DIR/.env" 2>/dev/null; then
  echo "ADMIN_KEY=$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')" >> "$APP_DIR/.env"
  echo "   -> generated ADMIN_KEY"
fi
if ! grep -q '^WEBHOOK_SECRET=' "$APP_DIR/.env" 2>/dev/null; then
  echo "WEBHOOK_SECRET=$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')" >> "$APP_DIR/.env"
  echo "   -> generated WEBHOOK_SECRET (share it with your payment webhook relay)"
fi
chown root:anrsaver "$APP_DIR/.env"
chmod 640 "$APP_DIR/.env"

echo ">> Python venv + deps..."
[[ -d "$APP_DIR/venv" ]] || python3 -m venv "$APP_DIR/venv"
"$APP_DIR/venv/bin/pip" install -q --upgrade pip
"$APP_DIR/venv/bin/pip" install -q -r "$SRC_DIR/requirements.txt"
# yt-dlp on YouTube needs the latest master (n-challenge fixes ship fast)
"$APP_DIR/venv/bin/pip" install -q -U --pre \
  "yt-dlp @ git+https://github.com/yt-dlp/yt-dlp.git" || true

echo ">> deno (JS runtime for yt-dlp's YouTube EJS solver)..."
# Pinned release installed straight from GitHub — no mutable install script.
DENO_VERSION=v2.9.7
if ! command -v deno >/dev/null || ! deno --version 2>/dev/null | grep -q "${DENO_VERSION#v}"; then
  apt-get install -y -qq unzip
  curl -fsSL -o /tmp/deno.zip \
    "https://github.com/denoland/deno/releases/download/${DENO_VERSION}/deno-x86_64-unknown-linux-gnu.zip"
  unzip -oq /tmp/deno.zip -d /usr/local/bin
  chmod +x /usr/local/bin/deno
  rm -f /tmp/deno.zip
fi
/usr/local/bin/deno --version | head -1 || echo "WARN: deno not runnable"

echo ">> Cobalt via docker compose..."
( set -a; . "$APP_DIR/.env"; set +a; cd "$SRC_DIR" && docker compose up -d )

echo ">> systemd services..."
cp -f "$SELF_DIR/ytdlp-api.service" "$SELF_DIR/cookie-sync.service" \
      "$SELF_DIR/anrsaver-ssrf-guard.service" /etc/systemd/system/
systemctl daemon-reload
# Kernel-level SSRF guard must be active before the API services run.
systemctl enable --now anrsaver-ssrf-guard.service
systemctl enable --now ytdlp-api.service cookie-sync.service
systemctl restart anrsaver-ssrf-guard.service ytdlp-api.service cookie-sync.service

# HTTPS reverse proxy. Existing Caddy config is preserved as a dated backup.
[[ -f /etc/caddy/Caddyfile ]] && cp -a /etc/caddy/Caddyfile "/etc/caddy/Caddyfile.bak.$(date +%s)"
cp -f "$SELF_DIR/Caddyfile" /etc/caddy/Caddyfile
caddy validate --config /etc/caddy/Caddyfile
systemctl enable --now caddy
systemctl reload caddy

echo ">> Firewall (HTTPS only)..."
ufw allow 22/tcp  >/dev/null 2>&1 || true
ufw allow 80/tcp  >/dev/null 2>&1 || true
ufw allow 443/tcp >/dev/null 2>&1 || true
ufw delete allow 9000/tcp >/dev/null 2>&1 || true
ufw delete allow 9002/tcp >/dev/null 2>&1 || true
ufw delete allow 9005/tcp >/dev/null 2>&1 || true

echo ">> Health checks..."
sleep 3
# Cobalt serves info at /, the Python services expose /health
cobalt=$(curl -s -o /dev/null -w '%{http_code}' -m 5 "http://127.0.0.1:9000/" || echo 000)
echo "   port 9000 (cobalt) -> HTTP $cobalt"
for p in 9002 9005; do
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 5 "http://127.0.0.1:$p/health" || echo 000)
  echo "   port $p -> HTTP $code"
done

echo "   HTTPS Cobalt -> $(curl -s -o /dev/null -w '%{http_code}' -m 10 https://api.ekalliptus.com/ || echo 000)"
echo "   HTTPS yt-dlp -> $(curl -s -o /dev/null -w '%{http_code}' -m 10 https://api.ekalliptus.com/ytdlp/health || echo 000)"
echo "   HTTPS cookies -> $(curl -s -o /dev/null -w '%{http_code}' -m 10 https://api.ekalliptus.com/cookie-sync/health || echo 000)"
echo
echo "Done. Public services: https://api.ekalliptus.com"
