#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

APP_DIR="${APP_DIR:-/opt/vps-bot}"
XTREAM_DIR="$APP_DIR/xtream"
VENV_DIR="$APP_DIR/.venv"
ENV_FILE="$APP_DIR/.env"
ENV_BACKUP="$APP_DIR/.env.backup"

CF_DIR="/etc/cloudflared"
CF_TOKEN_FILE="$CF_DIR/tunnel-token"

TMP_DIR="$(mktemp -d -p /tmp vps-bot-install.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Administrator-provided upgrade package
ZIP_URL="https://raw.githubusercontent.com/X-DARK-op/bot-installer/main/vps-bot-xtream-upgrade.zip"
ZIP_FILE="$TMP_DIR/vps-bot-xtream-upgrade.zip"
ZIP_DIR="$TMP_DIR/upgrade"

export DEBIAN_FRONTEND=noninteractive

log(){ printf '\033[1;34m[INSTALL]\033[0m %s\n' "$*"; }
ok(){ printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2; }
die(){ printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

trap 'rc=$?; if ((rc!=0)); then printf "\033[1;31m[ERROR]\033[0m Installation stopped with exit code %s. Existing files were not intentionally removed.\n" "$rc" >&2; fi' ERR

require_root(){
  [[ "${EUID}" -eq 0 ]] || die "Run this installer as root."
}

command_exists(){
  command -v "$1" >/dev/null 2>&1
}

prompt_value(){
  local var="$1" label="$2" default="${3:-}" value
  if [[ -n "$default" ]]; then
    read -r -p "$label [$default]: " value || true
    value="${value:-$default}"
  else
    read -r -p "$label: " value || true
  fi
  printf -v "$var" '%s' "$value"
}

prompt_secret(){
  local var="$1" label="$2" existing="${3:-}" value
  if [[ -n "$existing" ]]; then
    read -r -s -p "$label [press Enter to keep existing]: " value || true
    printf '\n'
    value="${value:-$existing}"
  else
    read -r -s -p "$label: " value || true
    printf '\n'
  fi
  [[ -n "$value" ]] || die "$label cannot be empty."
  printf -v "$var" '%s' "$value"
}

trim_host(){
  local h="$1"
  h="${h#http://}"
  h="${h#https://}"
  h="${h%%/*}"
  h="${h%%:*}"
  printf '%s' "$h"
}

valid_port(){
  [[ "$1" =~ ^[0-9]+$ ]] && ((10#$1>=1 && 10#$1<=65535))
}

port_available(){
  local p="$1"
  ! ss -H -ltn "( sport = :$p )" 2>/dev/null | grep -q .
}

env_get(){
  local key="$1"
  [[ -f "$ENV_FILE" ]] || return 0
  awk -v k="$key" '
    index($0,k"=")==1 {
      sub("^[^=]*=","")
      gsub(/^"|"$/,"")
      print
      exit
    }
  ' "$ENV_FILE"
}

set_env(){
  local key="$1" value="$2" tmp="$TMP_DIR/env.$RANDOM"
  touch "$ENV_FILE"
  awk -v k="$key" -v v="$value" '
    BEGIN{done=0}
    index($0,k"=")==1 {print k"="v; done=1; next}
    {print}
    END{if(!done) print k"="v}
  ' "$ENV_FILE" > "$tmp"
  install -m 600 "$tmp" "$ENV_FILE"
}

ensure_env_var_if_missing(){
  local key="$1" value="$2"
  [[ -n "$(env_get "$key")" ]] || set_env "$key" "$value"
}

download_raw(){
  local url="$1" dest="$2"
  curl --fail --silent --show-error --location \
    --retry 3 --connect-timeout 15 --max-time 120 \
    "$url" -o "$dest"
  [[ -s "$dest" ]] || die "Downloaded file is empty: $url"
}

download_upgrade_zip(){
  log "Downloading VPS Bot Xtream upgrade ZIP..."
  curl --fail --silent --show-error --location \
    --retry 3 --connect-timeout 15 --max-time 180 \
    "$ZIP_URL" -o "$ZIP_FILE"

  [[ -s "$ZIP_FILE" ]] || die "Upgrade ZIP download failed or is empty."

  mkdir -p "$ZIP_DIR"
  unzip -q "$ZIP_FILE" -d "$ZIP_DIR" \
    || die "Could not extract upgrade ZIP."

  ok "Upgrade ZIP downloaded and extracted"
}

find_in_upgrade(){
  local filename="$1"
  find "$ZIP_DIR" -type f -name "$filename" -print -quit 2>/dev/null || true
}

api_call(){
  # Usage: api_call METHOD URL [JSON_FILE]
  local method="$1" url="$2" data="${3:-}" out="$TMP_DIR/api.$RANDOM.json"

  if [[ -n "$data" ]]; then
    curl --fail --silent --show-error --location \
      --connect-timeout 15 --max-time 60 \
      -X "$method" \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json" \
      --data-binary "@$data" \
      "$url" -o "$out"
  else
    curl --fail --silent --show-error --location \
      --connect-timeout 15 --max-time 60 \
      -X "$method" \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      "$url" -o "$out"
  fi

  printf '%s' "$out"
}

json_ok(){
  jq -e '.success == true' "$1" >/dev/null 2>&1
}

install_blood_cloud_watermark(){
  log "Installing BLOOD CLOUD red watermark..."

  cat > /etc/profile.d/blood-cloud.sh <<'EOF'
#!/usr/bin/env bash

if [[ $- == *i* ]]; then
  RED='\033[1;31m'
  RESET='\033[0m'

  printf "\n"
  printf "${RED}╔════════════════════════════════════════════════════╗${RESET}\n"
  printf "${RED}║                                                    ║${RESET}\n"
  printf "${RED}║                 BLOOD CLOUD                        ║${RESET}\n"
  printf "${RED}║              VPS WEB TERMINAL                     ║${RESET}\n"
  printf "${RED}║                                                    ║${RESET}\n"
  printf "${RED}╚════════════════════════════════════════════════════╝${RESET}\n"
  printf "\n"
fi
EOF

  chmod 644 /etc/profile.d/blood-cloud.sh

  # /etc/motd is kept simple because /etc/profile.d handles ANSI color reliably.
  cat > /etc/motd <<'EOF'

============================================================
                    BLOOD CLOUD
                 VPS WEB TERMINAL
============================================================

EOF

  ok "BLOOD CLOUD red watermark installed"
}

install_from_upgrade_zip(){
  log "Checking upgrade package contents..."

  local bot_file xtream_file requirements_file

  bot_file="$(find_in_upgrade bot.py)"
  xtream_file="$(find_in_upgrade xtream.js)"
  requirements_file="$(find_in_upgrade requirements.txt)"

  if [[ -n "$bot_file" ]]; then
    install -m 640 "$bot_file" "$APP_DIR/bot.py"
    ok "bot.py installed from upgrade ZIP"
  fi

  if [[ -n "$requirements_file" ]]; then
    install -m 640 "$requirements_file" "$APP_DIR/requirements.txt"
    ok "requirements.txt installed from upgrade ZIP"
  fi

  if [[ -n "$xtream_file" ]]; then
    install -m 640 "$xtream_file" "$XTREAM_DIR/xtream.js"
    ok "xtream.js installed from upgrade ZIP"
  fi

  if [[ -z "$bot_file" && -z "$xtream_file" ]]; then
    warn "No bot.py/xtream.js found in ZIP; administrator-provided raw URLs will be used."
  fi
}

require_root

# Initial banner
printf '\033[1;31m'
cat <<'EOF'
╔════════════════════════════════════════════════════╗
║                                                    ║
║                 BLOOD CLOUD                        ║
║              VPS BOT INSTALLER                    ║
║                                                    ║
╚════════════════════════════════════════════════════╝
EOF
printf '\033[0m\n'

log "Starting safe/idempotent installation in $APP_DIR"

log "Installing OS dependencies..."
apt-get update -qq
apt-get install -y -qq \
  ca-certificates curl jq git unzip build-essential \
  python3 python3-venv python3-pip python3-dev \
  pkg-config libsqlite3-dev libssl-dev libffi-dev \
  openssh-client lxc-utils iproute2
ok "Base dependencies installed"

# Node.js 22
if ! command_exists node || ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 22 ? 0 : 1)' >/dev/null 2>&1; then
  log "Installing Node.js 22..."
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash - >/dev/null
  apt-get install -y -qq nodejs
fi
ok "Node.js $(node -v) ready"

mkdir -p "$APP_DIR" "$XTREAM_DIR" "$CF_DIR" /var/log/cloudflared
chmod 700 "$APP_DIR" "$CF_DIR"

if [[ -f "$ENV_FILE" ]]; then
  cp -a "$ENV_FILE" "$ENV_BACKUP"
  chmod 600 "$ENV_BACKUP"
  ok "Existing .env preserved at $ENV_BACKUP"
else
  touch "$ENV_FILE"
  chmod 600 "$ENV_FILE"
fi

# Download the ZIP before asking for source URLs.
download_upgrade_zip

echo
echo "Discord Bot configuration"
echo "-------------------------"
prompt_secret DISCORD_TOKEN "Enter Discord Bot Token" "$(env_get DISCORD_TOKEN)"
prompt_value ADMIN_ID "Enter Admin Discord User ID" "$(env_get ADMIN_ID)"
[[ "$ADMIN_ID" =~ ^[0-9]{15,25}$ ]] || die "Admin Discord User ID must be a Discord snowflake."

echo
prompt_value XTREAM_PORT "Enter Xtream.js Port" "$(env_get XTREAM_PORT || echo 8080)"
valid_port "$XTREAM_PORT" || die "Invalid Xtream.js port."

if ! port_available "$XTREAM_PORT"; then
  if systemctl is-active --quiet xtream.service; then
    warn "Xtream port $XTREAM_PORT is already in use by the existing Xtream service."
  else
    die "Xtream.js port $XTREAM_PORT is already in use by another process."
  fi
fi

prompt_value XTREAM_HOST "Enter Xtream.js Host/URL" "$(env_get XTREAM_HOST)"
[[ "$XTREAM_HOST" =~ ^https://[^[:space:]]+$ ]] \
  || die "Use an HTTPS hostname, e.g. https://terminal.example.com"

XTREAM_HOST_NAME="$(env_get XTREAM_HOST_NAME || true)"

prompt_value XTREAM_RAW_URL \
  "Enter Xtream.js Raw GitHub URL" \
  "$(env_get XTREAM_RAW_URL)"

if [[ -z "$XTREAM_RAW_URL" ]]; then
  XTREAM_RAW_URL="https://raw.githubusercontent.com/X-DARK-op/bot-installer/main/xtream.js"
fi

[[ "$XTREAM_RAW_URL" =~ ^https://raw\.githubusercontent\.com/ ]] \
  || die "Xtream raw URL must be a raw.githubusercontent.com URL."

prompt_value XTREAM_LOGO \
  "Enter Xtream Logo/Image URL" \
  "$(env_get XTREAM_LOGO)"

# Blood Cloud is the default watermark.
prompt_value XTREAM_WATERMARK \
  "Enter Xtream Watermark" \
  "$(env_get XTREAM_WATERMARK || echo 'BLOOD CLOUD')"

echo
echo "Cloudflare configuration"
echo "------------------------"
prompt_secret CF_API_TOKEN \
  "Enter Cloudflare Zero Trust API Token" \
  "$(env_get CLOUDFLARE_TOKEN)"

prompt_value CF_TUNNEL \
  "Enter Cloudflare Tunnel ID/Name" \
  "$(env_get CLOUDFLARE_TUNNEL)"

prompt_value CF_HOST \
  "Enter Cloudflare Hostname" \
  "$(env_get CLOUDFLARE_HOST || trim_host "$XTREAM_HOST")"

prompt_value CF_PORT \
  "Enter Cloudflare Port" \
  "$(env_get CLOUDFLARE_PORT || echo "$XTREAM_PORT")"

valid_port "$CF_PORT" || die "Invalid Cloudflare origin port."

if [[ "$(trim_host "$XTREAM_HOST")" != "$CF_HOST" ]]; then
  warn "Xtream host and Cloudflare hostname differ; Xtream public host will remain $XTREAM_HOST."
fi

if [[ "$CF_PORT" != "$XTREAM_PORT" ]]; then
  warn "Cloudflare origin port differs from Xtream.js port."
  read -r -p "Continue anyway? [y/N]: " ans || true
  [[ "$ans" =~ ^[Yy]$ ]] || die "Set Cloudflare Port to $XTREAM_PORT."
fi

echo
prompt_value MOTD_RAW_URL \
  "Enter MOTD/Watermark Raw GitHub URL" \
  "$(env_get MOTD_RAW_URL)"

[[ -z "$MOTD_RAW_URL" || "$MOTD_RAW_URL" =~ ^https://raw\.githubusercontent\.com/ ]] \
  || die "MOTD URL must be a raw.githubusercontent.com URL."

echo
prompt_value BOT_RAW_BASE \
  "Enter Bot Raw GitHub Base URL (for bot.py/requirements.txt)" \
  "$(env_get BOT_RAW_BASE_URL)"

if [[ -z "$BOT_RAW_BASE" ]]; then
  BOT_RAW_BASE="https://raw.githubusercontent.com/X-DARK-op/bot-installer/main"
fi

[[ "$BOT_RAW_BASE" =~ ^https://raw\.githubusercontent\.com/[^[:space:]]+$ ]] \
  || die "Bot raw base URL must point to raw.githubusercontent.com."

# Preserve all existing variables and only add/update required keys.
set_env DISCORD_TOKEN "$DISCORD_TOKEN"
set_env ADMIN_ID "$ADMIN_ID"
ensure_env_var_if_missing MAIN_ADMIN_ID "$ADMIN_ID"

set_env XTREAM_ENABLED "true"
set_env XTREAM_PORT "$XTREAM_PORT"
set_env XTREAM_BIND "127.0.0.1"
set_env XTREAM_HOST "$XTREAM_HOST"
set_env XTREAM_RAW_URL "$XTREAM_RAW_URL"
set_env XTREAM_LOGO "$XTREAM_LOGO"
set_env XTREAM_WATERMARK "$XTREAM_WATERMARK"
set_env XTREAM_PORT_START "$(env_get XTREAM_PORT_START || echo 30100)"
set_env XTREAM_PORT_END "$(env_get XTREAM_PORT_END || echo 39999)"
set_env XTREAM_HOST_NAME "${XTREAM_HOST_NAME:-VPS Web Terminal}"

set_env CLOUDFLARE_TOKEN "$CF_API_TOKEN"
set_env CLOUDFLARE_TUNNEL "$CF_TUNNEL"
set_env CLOUDFLARE_HOST "$CF_HOST"
set_env CLOUDFLARE_PORT "$CF_PORT"
set_env CLOUDFLARE_ACCOUNT_ID "$(env_get CLOUDFLARE_ACCOUNT_ID || true)"
set_env CLOUDFLARE_TUNNEL_TOKEN_FILE "$CF_TOKEN_FILE"

set_env MOTD_RAW_URL "$MOTD_RAW_URL"
set_env TAILSCALE_ENABLED "true"
set_env XTREAM_DB "$APP_DIR/vps.db"
set_env BOT_RAW_BASE_URL "$BOT_RAW_BASE"

# Generate/persist Xtream encryption key if absent.
if [[ -z "$(env_get XTREAM_SECRET_KEY)" ]]; then
  secret_key="$(
    python3 - <<'PY'
import base64
import os
print(base64.urlsafe_b64encode(os.urandom(32)).decode())
PY
  )"
  set_env XTREAM_SECRET_KEY "$secret_key"
  unset secret_key
fi

chmod 600 "$ENV_FILE"

# Install source from ZIP where available.
install_from_upgrade_zip

# Fallback to raw GitHub source if ZIP did not contain the needed files.
if [[ ! -s "$APP_DIR/bot.py" ]]; then
  log "Downloading bot source from configured raw GitHub URL..."
  download_raw "$BOT_RAW_BASE/bot.py" "$TMP_DIR/bot.py"
  install -m 640 "$TMP_DIR/bot.py" "$APP_DIR/bot.py"
fi

if [[ ! -s "$APP_DIR/requirements.txt" ]]; then
  log "Downloading Python requirements..."
  download_raw "$BOT_RAW_BASE/requirements.txt" "$TMP_DIR/requirements.txt"
  install -m 640 "$TMP_DIR/requirements.txt" "$APP_DIR/requirements.txt"
fi

if [[ ! -s "$XTREAM_DIR/xtream.js" ]]; then
  log "Downloading Xtream.js from configured raw URL..."
  download_raw "$XTREAM_RAW_URL" "$XTREAM_DIR/xtream.js"
  install -m 640 "$XTREAM_DIR/xtream.js" "$XTREAM_DIR/xtream.js"
fi

# Defense-in-depth: do not allow the bot source to log the Discord token.
python3 - "$APP_DIR/bot.py" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
s = p.read_text(encoding="utf-8")

s = s.replace(
    'logger.error("DISCORD_TOKEN in .env is currently set to: " + str(DISCORD_TOKEN))',
    'logger.error("DISCORD_TOKEN is missing or invalid; the token value is intentionally never logged.")'
)

p.write_text(s, encoding="utf-8")
PY

# If ZIP has a package.json, use it; otherwise create the known dependency set.
if [[ -f "$ZIP_DIR/package.json" ]]; then
  cp -f "$(find "$ZIP_DIR" -type f -name package.json -print -quit)" "$XTREAM_DIR/package.json"
else
  cat > "$XTREAM_DIR/package.json" <<'JSON'
{
  "name": "vps-bot-xtream",
  "private": true,
  "version": "1.0.0",
  "main": "xtream.js",
  "engines": { "node": ">=22" },
  "dependencies": {
    "@xterm/addon-fit": "^0.10.0",
    "@xterm/xterm": "^5.3.0",
    "better-sqlite3": "^12.0.0",
    "node-pty": "^1.1.0",
    "ws": "^8.18.0"
  }
}
JSON
fi

chown -R root:root "$APP_DIR"
chmod 750 "$APP_DIR" "$XTREAM_DIR"

log "Creating Python virtual environment..."
python3 -m venv "$VENV_DIR"
"$VENV_DIR/bin/pip" install --disable-pip-version-check --no-input -q \
  --upgrade pip wheel setuptools

"$VENV_DIR/bin/pip" install --disable-pip-version-check --no-input -q \
  -r "$APP_DIR/requirements.txt"

ok "Python dependencies installed"

log "Installing Xtream.js native dependencies..."
cd "$XTREAM_DIR"
npm install --omit=dev --no-audit --no-fund >/dev/null
ok "Xtream.js dependencies installed"

log "Preparing Cloudflare Tunnel..."

CF_ACCOUNT_ID="$(env_get CLOUDFLARE_ACCOUNT_ID || true)"

if [[ -z "$CF_ACCOUNT_ID" ]]; then
  accounts_json="$(
    api_call GET \
      "https://api.cloudflare.com/client/v4/accounts?per_page=50"
  )"

  if ! json_ok "$accounts_json"; then
    die "Cloudflare API token could not list accounts. Add account access/Account Read to the token or set CLOUDFLARE_ACCOUNT_ID in .env and rerun."
  fi

  CF_ACCOUNT_ID="$(jq -r '.result[0].id // empty' "$accounts_json")"
  [[ -n "$CF_ACCOUNT_ID" ]] \
    || die "No Cloudflare account was visible to the supplied API token."

  set_env CLOUDFLARE_ACCOUNT_ID "$CF_ACCOUNT_ID"
fi

CF_TUNNEL_ID=""

if [[ "$CF_TUNNEL" =~ ^[0-9a-fA-F-]{36}$ ]]; then
  CF_TUNNEL_ID="$CF_TUNNEL"
else
  tunnels_json="$(
    api_call GET \
      "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/cfd_tunnel?per_page=100"
  )"

  if ! json_ok "$tunnels_json"; then
    die "Could not list Cloudflare tunnels. Check tunnel permissions and account ID."
  fi

  CF_TUNNEL_ID="$(
    jq -r --arg n "$CF_TUNNEL" \
      '.result[] | select(.name==$n) | .id' \
      "$tunnels_json" | head -n1
  )"
fi

[[ -n "$CF_TUNNEL_ID" ]] \
  || die "Cloudflare Tunnel '$CF_TUNNEL' was not found in the selected account."

cat > "$TMP_DIR/tunnel-config.json" <<JSON
{
  "config": {
    "ingress": [
      {
        "hostname": "$CF_HOST",
        "service": "http://127.0.0.1:$CF_PORT",
        "originRequest": {}
      },
      {
        "service": "http_status:404"
      }
    ]
  }
}
JSON

config_resp="$(
  api_call PUT \
    "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/cfd_tunnel/$CF_TUNNEL_ID/configurations" \
    "$TMP_DIR/tunnel-config.json"
)"

json_ok "$config_resp" \
  || die "Cloudflare tunnel configuration update failed."

token_resp="$(
  api_call GET \
    "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/cfd_tunnel/$CF_TUNNEL_ID/token"
)"

json_ok "$token_resp" \
  || die "Could not retrieve the Cloudflare Tunnel connector token."

CF_TUNNEL_TOKEN="$(jq -r '.result // empty' "$token_resp")"

[[ -n "$CF_TUNNEL_TOKEN" && "$CF_TUNNEL_TOKEN" != "null" ]] \
  || die "Cloudflare returned an empty tunnel token."

printf '%s\n' "$CF_TUNNEL_TOKEN" > "$CF_TOKEN_FILE"
chmod 600 "$CF_TOKEN_FILE"
unset CF_TUNNEL_TOKEN

ZONE_NAME="$(
  python3 - "$CF_HOST" <<'PY'
import sys
parts=sys.argv[1].strip('.').split('.')
if len(parts) < 2:
    raise SystemExit(1)
print('.'.join(parts[-2:]))
PY
)" || die "Invalid Cloudflare hostname."

zones_json="$(
  api_call GET \
    "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME&status=active&per_page=50"
)"

json_ok "$zones_json" \
  || die "Could not query the Cloudflare DNS zone for $ZONE_NAME."

ZONE_ID="$(jq -r '.result[0].id // empty' "$zones_json")"

[[ -n "$ZONE_ID" ]] \
  || die "Cloudflare zone $ZONE_NAME was not found or token lacks DNS access."

fqdn="$CF_HOST"

dns_json="$(
  api_call GET \
    "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=CNAME&name=$fqdn&per_page=100"
)"

json_ok "$dns_json" \
  || die "Could not inspect DNS records."

record_id="$(jq -r '.result[0].id // empty' "$dns_json")"

cat > "$TMP_DIR/dns.json" <<JSON
{
  "type": "CNAME",
  "name": "$fqdn",
  "content": "$CF_TUNNEL_ID.cfargotunnel.com",
  "proxied": true,
  "ttl": 1
}
JSON

if [[ -n "$record_id" ]]; then
  dns_resp="$(
    api_call PUT \
      "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
      "$TMP_DIR/dns.json"
  )"
else
  dns_resp="$(
    api_call POST \
      "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
      "$TMP_DIR/dns.json"
  )"
fi

json_ok "$dns_resp" \
  || die "Cloudflare DNS record update failed. Check DNS Edit permission."

set_env CLOUDFLARE_TUNNEL "$CF_TUNNEL_ID"

ok "Cloudflare tunnel and DNS configured"

log "Installing cloudflared..."

arch="$(dpkg --print-architecture)"

case "$arch" in
  amd64|arm64|armhf) ;;
  *) die "Unsupported Debian architecture for cloudflared: $arch" ;;
esac

cf_deb="$TMP_DIR/cloudflared.deb"

curl --fail --silent --show-error --location --retry 3 \
  "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$arch.deb" \
  -o "$cf_deb"

dpkg -i "$cf_deb" >/dev/null

command_exists cloudflared \
  || die "cloudflared installation failed."

CF_BIN="$(command -v cloudflared)"

ok "cloudflared installed"

log "Installing systemd units..."

cat > /etc/systemd/system/xtream.service <<UNIT
[Unit]
Description=VPS Bot Xtream Web Terminal
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$XTREAM_DIR
Environment=XTREAM_ENV_FILE=$ENV_FILE
ExecStart=/usr/bin/node $XTREAM_DIR/xtream.js
Restart=on-failure
RestartSec=5
TimeoutStopSec=10
PrivateTmp=true
ProtectHome=true
ProtectSystem=full
ReadWritePaths=$APP_DIR
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT

cat > /etc/systemd/system/cloudflared-vps-bot.service <<UNIT
[Unit]
Description=Cloudflare Zero Trust Tunnel for VPS Bot
Requires=xtream.service
After=network-online.target xtream.service
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
ExecStart=$CF_BIN tunnel --no-autoupdate run --token-file $CF_TOKEN_FILE
Restart=on-failure
RestartSec=5
TimeoutStartSec=0
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=$CF_DIR /var/log/cloudflared
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT

cat > /etc/systemd/system/vps-bot.service <<UNIT
[Unit]
Description=VPS Discord Bot
After=network-online.target cloudflared-vps-bot.service
Wants=network-online.target cloudflared-vps-bot.service

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$APP_DIR
Environment=PYTHONUNBUFFERED=1
ExecStart=$VENV_DIR/bin/python $APP_DIR/bot.py
Restart=on-failure
RestartSec=5
TimeoutStopSec=20
PrivateTmp=true
ProtectHome=false
ProtectSystem=full
ReadWritePaths=$APP_DIR
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload

systemctl enable \
  xtream.service \
  cloudflared-vps-bot.service \
  vps-bot.service >/dev/null

install_blood_cloud_watermark

log "Installing configurable MOTD/Watermark..."

if [[ -n "$MOTD_RAW_URL" ]]; then
  motd_tmp="$TMP_DIR/MOTD"
  download_raw "$MOTD_RAW_URL" "$motd_tmp"
  chmod 700 "$motd_tmp"

  # Do not export secrets to the MOTD script.
  bash "$motd_tmp"

  ok "MOTD script executed"
else
  warn "MOTD URL was empty; external MOTD step skipped."
fi

# Validate sources before starting services.
"$VENV_DIR/bin/python" -m py_compile "$APP_DIR/bot.py"
node --check "$XTREAM_DIR/xtream.js"

ok "Python and Xtream syntax checks passed"

# Stop only managed services.
systemctl stop \
  vps-bot.service \
  cloudflared-vps-bot.service \
  xtream.service 2>/dev/null || true

systemctl start xtream.service
sleep 2

systemctl is-active --quiet xtream.service \
  || die "Xtream.js failed to start; inspect: journalctl -u xtream.service -n 100 --no-pager"

systemctl start cloudflared-vps-bot.service
sleep 2

systemctl is-active --quiet cloudflared-vps-bot.service \
  || die "Cloudflare Tunnel failed to start; inspect: journalctl -u cloudflared-vps-bot.service -n 100 --no-pager"

systemctl start vps-bot.service
sleep 3

systemctl is-active --quiet vps-bot.service \
  || die "Discord bot failed to start; inspect: journalctl -u vps-bot.service -n 100 --no-pager"

echo
printf '\033[1;31m'
cat <<'EOF'
============================================
          BLOOD CLOUD INSTALLATION
                 COMPLETE
============================================
EOF
printf '\033[0m'

printf "Discord Bot:        Installed\n"
printf "Xtream.js:          Installed\n"
printf "Xtream Port:        %s\n" "$XTREAM_PORT"
printf "Cloudflare:         Configured\n"
printf "Hostname:           %s\n" "$CF_HOST"
printf "MOTD:               %s\n" "$([[ -n "$MOTD_RAW_URL" ]] && echo Installed || echo Skipped)"
printf "Watermark:          BLOOD CLOUD\n"
printf "Watermark Color:    RED\n"

echo
echo "Services:"

systemctl is-active --quiet vps-bot.service \
  && printf '\033[1;31m✓ Discord Bot\033[0m\n'

systemctl is-active --quiet xtream.service \
  && printf '\033[1;31m✓ Xtream.js\033[0m\n'

systemctl is-active --quiet cloudflared-vps-bot.service \
  && printf '\033[1;31m✓ Cloudflare Tunnel\033[0m\n'

printf "Bot Status:          Running\n"

printf '\033[1;31m============================================\033[0m\n'
printf "Public Web Terminal: %s\n" "$XTREAM_HOST"
printf "Credentials are generated per VPS and sent only by Discord DM.\n"
printf "Secrets were not printed by this installer.\n"
printf '\033[1;31m============================================\033[0m\n'
