#!/bin/bash

# =================================================================
#  Blood Cloud™ - Discord Bot Auto Installer (v8 PRO FIXED)
#  High Performance • Auto Setup • Systemd Integrated
# =================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
GOLD='\033[1;33m'
NC='\033[0m'

clear
echo -e "${RED}"
cat << "LOGO"
██████╗ ██╗      ██████╗  ██████╗ ██████╗      ██████╗ ██╗      ██████╗ ██╗   ██╗██████╗ 
██╔══██╗██║     ██╔═══██╗██╔═══██╗██╔══██╗    ██╔════╝ ██║     ██╔═══██╗██║   ██║██╔══██╗
██████╔╝██║     ██║   ██║██║   ██║██║  ██║    ██║     ██║     ██║   ██║██║   ██║██║  ██║
██╔══██╗██║     ██║   ██║██║   ██║██║  ██║    ██║     ██║     ██║   ██║██║   ██║██║  ██║
██████╔╝███████╗╚██████╔╝╚██████╔╝██████╔╝    ╚██████╗███████╗╚██████╔╝╚██████╔╝██████╔╝
╚═════╝ ╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝      ╚═════╝╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝ 
LOGO
echo -e "${NC}"
echo -e "${RED}🩸 Welcome to Blood Cloud™ Auto Installation System${NC}"
echo -e "${WHITE}========================================================================${NC}"

# 0. Root Check
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}❌ Error: Please run this script as root! (sudo bash script.sh)${NC}"
  exit 1
fi

# 1. Directory Setup Prompt
echo -e "\n${YELLOW}--- Step 1: Directory Setup ---${NC}"
read -p "Enter folder name for installation [Default: bot]: " DIR_NAME </dev/tty
DIR_NAME=${DIR_NAME:-bot}

INSTALL_DIR="/root/${DIR_NAME}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit 1

echo -e "${GREEN}📂 Installation Path Set To: ${WHITE}${INSTALL_DIR}${NC}"

# 2. System Dependencies Installation
echo -e "\n${YELLOW}--- Step 2: Installing Dependencies ---${NC}"
apt update -y
apt install -y python3 python3-pip python3-venv build-essential git curl pango1.0-tools

# LXD Setup via Snap
if ! command -v lxd &> /dev/null; then
    echo -e "${CYAN}Setting up LXD container engine...${NC}"
    apt install -y snapd 2>/dev/null || true
    snap install lxd --channel=latest/stable 2>/dev/null || true
    lxd init --auto 2>/dev/null || true
fi

# 3. Downloading Source Files
echo -e "\n${YELLOW}--- Step 3: Fetching Bot Source Files ---${NC}"
curl -sSL "https://files.catbox.moe/e7m1ou.py" -o "$INSTALL_DIR/bot.py"
curl -sSL "https://files.catbox.moe/wjzlfv.txt" -o "$INSTALL_DIR/requirements.txt"
curl -sSL "https://files.catbox.moe/dbvwq3.env" -o "$INSTALL_DIR/example.env"

echo -e "${GREEN}✔ Files downloaded successfully!${NC}"

# 4. Interactive Configuration Setup (.env)
echo -e "\n${YELLOW}--- Step 4: Configuring Environment (.env) ---${NC}"

if [ -f "$INSTALL_DIR/example.env" ]; then
    > "$INSTALL_DIR/.env"
    
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        VAR_NAME=$(echo "$line" | cut -d'=' -f1 | xargs)
        DEFAULT_VAL=$(echo "$line" | cut -d'=' -f2- | xargs)
        
        if [ -z "$DEFAULT_VAL" ]; then
            USER_INPUT=""
            while [ -z "$USER_INPUT" ]; do
                read -p "Enter $VAR_NAME (Required): " USER_INPUT </dev/tty
                if [ -z "$USER_INPUT" ]; then
                    echo -e "${RED}This field cannot be empty!${NC}"
                fi
            done
            FINAL_VAL="$USER_INPUT"
        else
            read -p "Enter $VAR_NAME [Default: $DEFAULT_VAL]: " USER_INPUT </dev/tty
            FINAL_VAL=${USER_INPUT:-$DEFAULT_VAL}
        fi
        
        echo "$VAR_NAME=$FINAL_VAL" >> "$INSTALL_DIR/.env"
    done < "$INSTALL_DIR/example.env"
    
    rm -f "$INSTALL_DIR/example.env"
    echo -e "${GREEN}✔ Config file .env saved successfully!${NC}"
fi

# 5. Virtual Environment & Dual Installation Fix
echo -e "\n${YELLOW}--- Step 5: Preparing Python Environment ---${NC}"

# Create VENV
python3 -m venv "$INSTALL_DIR/venv"
"$INSTALL_DIR/venv/bin/pip" install --upgrade pip --quiet
"$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/requirements.txt"

# Dual-install on System Python (Fixes No Module Found error in Systemd)
pip3 install -r "$INSTALL_DIR/requirements.txt" --break-system-packages 2>/dev/null || pip3 install -r "$INSTALL_DIR/requirements.txt" 2>/dev/null || true

# 6. Systemd Background Service Configuration
echo -e "\n${YELLOW}--- Step 6: Setting Up Systemd Background Service ---${NC}"

cat <<SERVICEFILE > /etc/systemd/system/bot.service
[Unit]
Description=Blood Cloud Discord Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/bot.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICEFILE

systemctl daemon-reload
systemctl enable bot.service
systemctl restart bot.service

# Completion Summary Output
clear
echo -e "${RED}========================================================================${NC}"
echo -e "${WHITE}${BOLD} 🎉 CONGRATULATIONS! YOUR DISCORD BOT IS INSTALLED & RUNNING! 🚀${NC}"
echo -e "${RED}========================================================================${NC}"
echo -e "${CYAN} Environment, Virtual Environment, and Systemd Service Configured.${NC}"
echo -e ""
echo -e "${YELLOW} 📁 Directory Path:${NC} ${WHITE}${INSTALL_DIR}${NC}"
echo -e "${YELLOW} 📄 Config File:${NC}    ${WHITE}${INSTALL_DIR}/.env${NC}"
echo -e "${YELLOW} 🐍 Executable:${NC}     ${WHITE}${INSTALL_DIR}/bot.py${NC}"
echo -e ""
echo -e "${PURPLE}------------------------------------------------------------------------${NC}"
echo -e "${WHITE}${BOLD} 📌 Useful Commands Cheat-Sheet:${NC}"
echo -e "${PURPLE}------------------------------------------------------------------------${NC}"
echo -e " ${GREEN}▶ Status Check:${NC}   systemctl status bot"
echo -e " ${CYAN}▶ Live Logs:${NC}      journalctl -u bot -f -n 50"
echo -e " ${BLUE}▶ Restart Bot:${NC}    systemctl restart bot"
echo -e " ${RED}▶ Stop Bot:${NC}       systemctl stop bot"
echo -e "${RED}========================================================================${NC}"
echo -e "${GOLD}${BOLD}   Thank you for using Blood Cloud™ Automation Suite! 💎${NC}"
echo -e "${RED}========================================================================${NC}"
echo -e ""
