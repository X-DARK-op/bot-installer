#!/bin/bash
set -e

# ============================================================
#        VENOM BOT V3 - AIO INSTALLER
#        Bot + FastAPI + Next.js Dashboard
# ============================================================

REPO_ZIP="https://github.com/X-DARK-op/Venom-botv3/raw/refs/heads/main/ZyroX-CV2-AIO-With-Dashboard-main.zip"
INSTALL_DIR="/opt/venom-bot"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

echo -e "${RED}"
cat <<'EOF'
██╗   ██╗███████╗███╗   ██╗ ██████╗ ███╗   ███╗
██║   ██║██╔════╝████╗  ██║██╔═══██╗████╗ ████║
╚██╗ ██╔╝█████╗  ██╔██╗ ██║██║   ██║██╔████╔██║
 ╚████╔╝ ██╔══╝  ██║╚██╗██║██║   ██║██║╚██╔╝██║
  ╚██╔╝  ███████╗██║ ╚████║╚██████╔╝██║ ╚═╝ ██║
   ╚═╝   ╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝     ╚═╝
EOF
echo -e "${NC}"
echo -e "${CYAN}        ZyroX / Venom Bot V3 Installer${NC}"
echo

# ------------------------------------------------------------
# Root check
# ------------------------------------------------------------

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run this installer as root.${NC}"
    echo "Example: sudo bash install.sh"
    exit 1
fi

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

ask_default() {
    local prompt="$1"
    local default="$2"
    local result

    if [ -n "$default" ]; then
        read -r -p "$prompt [$default]: " result
        result="${result:-$default}"
    else
        read -r -p "$prompt: " result
    fi

    echo "$result"
}

ask_secret() {
    local prompt="$1"
    local result

    while [ -z "$result" ]; do
        read -r -s -p "$prompt: " result
        echo
        if [ -z "$result" ]; then
            echo -e "${RED}This value is required.${NC}"
        fi
    done

    echo "$result"
}

# ------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------

echo -e "${YELLOW}[1/7] Installing system dependencies...${NC}"

apt-get update -y

apt-get install -y \
    curl \
    wget \
    unzip \
    git \
    ca-certificates \
    build-essential \
    python3 \
    python3-pip \
    python3-venv

# Node.js 20
if ! command -v node >/dev/null 2>&1; then
    echo -e "${CYAN}Installing Node.js 20...${NC}"

    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
fi

echo
echo -e "${GREEN}Python: $(python3 --version)${NC}"
echo -e "${GREEN}Node:   $(node --version)${NC}"
echo -e "${GREEN}NPM:    $(npm --version)${NC}"
echo

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

echo -e "${YELLOW}[2/7] Configuration${NC}"
echo
echo -e "${CYAN}Press ENTER to use the default value.${NC}"
echo -e "${CYAN}Discord TOKEN has NO default and is required.${NC}"
echo

# REQUIRED
TOKEN=$(ask_secret "Enter Discord Bot TOKEN")

# DEFAULT VALUES
OWNER_IDS=$(ask_default \
    "Enter Owner IDs (comma separated)" \
    "870179991462236170,767979794411028491,1432771000629596225,1382744437049790495,1263404140965396555")

BRAND_NAME=$(ask_default "Enter Brand Name" "ZyroX")

LAVALINK_HOST=$(ask_default \
    "Enter Lavalink Host" \
    "lavalink.jirayu.net")

LAVALINK_PASSWORD=$(ask_default \
    "Enter Lavalink Password" \
    "youshallnotpass")

LAVALINK_SECURE=$(ask_default \
    "Lavalink Secure (true/false)" \
    "false")

LAVALINK_PORT=$(ask_default \
    "Lavalink Port" \
    "13592")

EMOJI_SYNC=$(ask_default \
    "Enable Emoji Sync (true/false)" \
    "false")

API_ENABLED=$(ask_default \
    "Enable API (true/false)" \
    "true")

API_PORT=$(ask_default \
    "API Port" \
    "8000")

DASHBOARD_API_KEY=$(ask_default \
    "Dashboard API Key" \
    "ZYROX_SECURE_API_KEY_12345_CHANGE_THIS_ASAP_BY_CODEX_DEVS")

CORS_ORIGINS=$(ask_default \
    "CORS Origins" \
    "")

WEBHOOK_URL=$(ask_default \
    "Webhook URL" \
    "https://discord.com/api/webhooks/")

CMD_WEBHOOK_URL=$(ask_default \
    "Command Webhook URL" \
    "https://discord.com/api/webhooks/")

TUNNEL_ENABLED=$(ask_default \
    "Enable Cloudflare Tunnel (true/false)" \
    "true")

CF_TUNNEL_TOKEN=$(ask_default \
    "Cloudflare Tunnel Token" \
    "xxx_xxxx")

CF_TUNNEL_URL=$(ask_default \
    "Cloudflare Tunnel URL" \
    "https://zyrox-api.yourdomain.com")

echo
echo -e "${YELLOW}Dashboard configuration${NC}"
echo

NEXT_PUBLIC_API_URL=$(ask_default \
    "Dashboard API URL" \
    "${CF_TUNNEL_URL}/api/v1")

NEXT_PUBLIC_DASHBOARD_API_KEY=$(ask_default \
    "Dashboard API Key" \
    "$DASHBOARD_API_KEY")

NEXTAUTH_URL=$(ask_default \
    "NextAuth URL" \
    "http://localhost:3000/")

NEXTAUTH_SECRET=$(ask_default \
    "NextAuth Secret" \
    "zyrox_nextauth_default_secret_string_2026_change_me_BY_CODEX_DEVS")

DISCORD_CLIENT_ID=$(ask_default \
    "Discord OAuth Client ID" \
    "")

DISCORD_CLIENT_SECRET=$(ask_default \
    "Discord OAuth Client Secret" \
    "")

NEXT_PUBLIC_ADMIN_IDS=$(ask_default \
    "Dashboard Admin IDs" \
    "$OWNER_IDS")

NEXT_PUBLIC_BRAND_NAME=$(ask_default \
    "Dashboard Brand Name" \
    "$BRAND_NAME")

NEXT_PUBLIC_BRAND_NAME_WORD=$(ask_default \
    "Dashboard Brand Short Name" \
    "ZX")

# ------------------------------------------------------------
# Download
# ------------------------------------------------------------

echo
echo -e "${YELLOW}[3/7] Downloading Venom Bot...${NC}"

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

cd /tmp

rm -f venom-bot.zip

curl -L --fail --progress-bar \
    "$REPO_ZIP" \
    -o venom-bot.zip

echo
echo -e "${GREEN}Download completed.${NC}"

# ------------------------------------------------------------
# Extract
# ------------------------------------------------------------

echo -e "${YELLOW}[4/7] Extracting files...${NC}"

mkdir -p /tmp/venom-extract

rm -rf /tmp/venom-extract/*
unzip -q /tmp/venom-bot.zip -d /tmp/venom-extract

EXTRACTED_DIR=$(find /tmp/venom-extract -maxdepth 1 -type d \
    -name "ZyroX-CV2-AIO-With-Dashboard-main" | head -n 1)

if [ -z "$EXTRACTED_DIR" ]; then
    echo -e "${RED}Could not find project directory inside ZIP.${NC}"
    exit 1
fi

cp -a "$EXTRACTED_DIR/." "$INSTALL_DIR/"

echo -e "${GREEN}Files extracted to $INSTALL_DIR${NC}"

# ------------------------------------------------------------
# Bot ENV
# ------------------------------------------------------------

echo -e "${YELLOW}[5/7] Creating environment files...${NC}"

cat > "$INSTALL_DIR/bot/.env" <<EOF
TOKEN=$TOKEN
brand_name='$BRAND_NAME'
NEXT_PUBLIC_BRAND_NAME='$BRAND_NAME'

OWNER_IDS=$OWNER_IDS

LAVALINK_HOST="$LAVALINK_HOST"
LAVALINK_PASSWORD="$LAVALINK_PASSWORD"
LAVALINK_SECURE="$LAVALINK_SECURE"
LAVALINK_PORT="$LAVALINK_PORT"

EMOJI_SYNC="$EMOJI_SYNC"

API_ENABLED="$API_ENABLED"
API_PORT="$API_PORT"
DASHBOARD_API_KEY="$DASHBOARD_API_KEY"
CORS_ORIGINS="$CORS_ORIGINS"

WEBHOOK_URL="$WEBHOOK_URL"
CMD_WEBHOOK_URL="$CMD_WEBHOOK_URL"

TUNNEL_ENABLED="$TUNNEL_ENABLED"
CF_TUNNEL_TOKEN="$CF_TUNNEL_TOKEN"
CF_TUNNEL_URL="$CF_TUNNEL_URL"
EOF

chmod 600 "$INSTALL_DIR/bot/.env"

# ------------------------------------------------------------
# Dashboard ENV
# ------------------------------------------------------------

cat > "$INSTALL_DIR/dashboard/.env.local" <<EOF
NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
NEXT_PUBLIC_DASHBOARD_API_KEY=$NEXT_PUBLIC_DASHBOARD_API_KEY

NEXTAUTH_URL=$NEXTAUTH_URL
NEXTAUTH_SECRET=$NEXTAUTH_SECRET

DISCORD_CLIENT_ID=$DISCORD_CLIENT_ID
DISCORD_CLIENT_SECRET=$DISCORD_CLIENT_SECRET

NEXT_PUBLIC_ADMIN_IDS=$NEXT_PUBLIC_ADMIN_IDS

NEXT_PUBLIC_BRAND_NAME="$NEXT_PUBLIC_BRAND_NAME"
NEXT_PUBLIC_BRAND_NAME_WORD="$NEXT_PUBLIC_BRAND_NAME_WORD"
EOF

chmod 600 "$INSTALL_DIR/dashboard/.env.local"

# ------------------------------------------------------------
# Python
# ------------------------------------------------------------

echo -e "${YELLOW}[6/7] Installing Python dependencies...${NC}"

cd "$INSTALL_DIR/bot"

python3 -m venv .venv

source .venv/bin/activate

python -m pip install --upgrade pip

pip install -r requirements.txt

deactivate

# ------------------------------------------------------------
# Dashboard
# ------------------------------------------------------------

echo -e "${YELLOW}Installing dashboard dependencies...${NC}"

cd "$INSTALL_DIR/dashboard"

npm install

echo -e "${YELLOW}Building dashboard...${NC}"

npm run build

# ------------------------------------------------------------
# Systemd Bot
# ------------------------------------------------------------

echo -e "${YELLOW}[7/7] Creating systemd services...${NC}"

cat > /etc/systemd/system/venom-bot.service <<EOF
[Unit]
Description=Venom Bot V3
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR/bot
EnvironmentFile=$INSTALL_DIR/bot/.env
ExecStart=$INSTALL_DIR/bot/.venv/bin/python CodeX.py
Restart=always
RestartSec=5
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
EOF

# ------------------------------------------------------------
# Systemd Dashboard
# ------------------------------------------------------------

cat > /etc/systemd/system/venom-dashboard.service <<EOF
[Unit]
Description=Venom Bot V3 Next.js Dashboard
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR/dashboard
EnvironmentFile=$INSTALL_DIR/dashboard/.env.local
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# ------------------------------------------------------------
# Start
# ------------------------------------------------------------

systemctl daemon-reload

systemctl enable venom-bot.service
systemctl enable venom-dashboard.service

systemctl restart venom-bot.service
systemctl restart venom-dashboard.service

sleep 3

# ------------------------------------------------------------
# Status
# ------------------------------------------------------------

echo
echo -e "${GREEN}"
echo "============================================================"
echo "              INSTALLATION COMPLETE"
echo "============================================================"
echo -e "${NC}"

if systemctl is-active --quiet venom-bot; then
    echo -e "Bot:       ${GREEN}RUNNING ✓${NC}"
else
    echo -e "Bot:       ${RED}FAILED ✗${NC}"
fi

if systemctl is-active --quiet venom-dashboard; then
    echo -e "Dashboard: ${GREEN}RUNNING ✓${NC}"
else
    echo -e "Dashboard: ${RED}FAILED ✗${NC}"
fi

echo
echo -e "${CYAN}Bot service:${NC}"
echo "  systemctl status venom-bot"

echo
echo -e "${CYAN}Dashboard service:${NC}"
echo "  systemctl status venom-dashboard"

echo
echo -e "${CYAN}Bot logs:${NC}"
echo "  journalctl -u venom-bot -f"

echo
echo -e "${CYAN}Dashboard logs:${NC}"
echo "  journalctl -u venom-dashboard -f"

echo
echo -e "${CYAN}Dashboard:${NC}"
echo "  http://YOUR_VPS_IP:3000"

echo
echo -e "${GREEN}Venom Bot V3 installed successfully!${NC}"
