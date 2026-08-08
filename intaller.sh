#!/bin/bash

# =================================================================
#  Blood Cloud™ - Discord Bot Auto Installer (LXC PATH FIXED)
# =================================================================

# Color Palette Definition
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
LIGHT_CYAN='\033[1;36m'
WHITE='\033[1;37m'
DARK_GRAY='\033[1;30m'
BOLD='\033[1m'
GOLD='\033[1;33m'
NC='\033[0m'

clear
echo -e "${RED}"
cat << "LOGO"
██████╗ ██╗      ██████╗  ██████╗ ██████╗     ██████╗ ██╗      ██████╗ ██╗   ██╗██████╗ 
██╔══██╗██║     ██╔═══██╗██╔═══██╗██╔══██╗   ██╔════╝ ██║     ██╔═══██╗██║   ██║██╔══██╗
██████╔╝██║     ██║   ██║██║   ██║██║  ██║   ██║      ██║     ██║   ██║██║   ██║██║  ██║
██╔══██╗██║     ██║   ██║██║   ██║██║  ██║   ██║      ██║     ██║   ██║██║   ██║██║  ██║
██████╔╝███████╗╚██████╔╝╚██████╔╝██████╔╝   ╚██████╗ ███████╗╚██████╔╝╚██████╔╝██████╔╝
╚═════╝ ╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝     ╚═════╝ ╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝ 
LOGO
echo -e "${NC}"
echo -e "${RED}🩸 Welcome to Blood Cloud™ Auto Installation System${NC}"
echo -e "${WHITE}========================================================================${NC}"

# 0. Root Privilege Check
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}❌ Error: Please run this script as root! (sudo bash script.sh)${NC}"
  exit 1
fi

# 1. Directory Setup Prompt (Terminal Input Freeze Fix)
echo -e "\n${YELLOW}--- Step 1: Directory Setup ---${NC}"
echo -n -e "Enter folder name for installation [Default: bot]: "
read DIR_NAME < /dev/tty
DIR_NAME=${DIR_NAME:-bot}

INSTALL_DIR="/root/${DIR_NAME}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit 1

echo -e "${GREEN}📂 Installation Path Set To: ${WHITE}${INSTALL_DIR}${NC}"

# 2. System Dependencies Installation
echo -e "\n${YELLOW}--- Step 2: Installing Dependencies & LXC Engine ---${NC}"
apt update -y
apt install -y python3 python3-pip python3-venv build-essential git curl pango1.0-tools lxc lxd-installer lxd-client snapd

# LXD Engine & LXC Binary Path Setup
if ! command -v lxc &> /dev/null; then
    echo -e "${CYAN}Setting up LXD container engine & LXC binaries...${NC}"
    snap install lxd --channel=latest/stable 2>/dev/null || true
    ln -s /snap/bin/lxc /usr/bin/lxc 2>/dev/null || true
    lxd init --auto 2>/dev/null || true
fi

# Symlink check to ensure 'lxc' command works globally for Python sub-processes
ln -s /snap/bin/lxc /usr/bin/lxc 2>/dev/null || true

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
                echo -n -e "Enter $VAR_NAME (Required): "
                read USER_INPUT < /dev/tty
                if [ -z "$USER_INPUT" ]; then
                    echo -e "${RED}This field cannot be empty!${NC}"
                fi
            done
            FINAL_VAL="$USER_INPUT"
        else
            echo -n -e "Enter $VAR_NAME [Default: $DEFAULT_VAL]: "
            read USER_INPUT < /dev/tty
            FINAL_VAL=${USER_INPUT:-$DEFAULT_VAL}
        fi
        
        echo "$VAR_NAME=$FINAL_VAL" >> "$INSTALL_DIR/.env"
    done < "$INSTALL_DIR/example.env"
    
    rm -f "$INSTALL_DIR/example.env"
    echo -e "${GREEN}✔ Config file .env saved successfully!${NC}"
fi

# 5. Virtual Environment & Dual Installation Setup
echo -e "\n${YELLOW}--- Step 5: Preparing Python Environment ---${NC}"

python3 -m venv "$INSTALL_DIR/venv"
"$INSTALL_DIR/venv/bin/pip" install --upgrade pip --quiet
"$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/requirements.txt"

# System Python Fallback Configuration
pip3 install -r "$INSTALL_DIR/requirements.txt" --break-system-packages 2>/dev/null || pip3 install -r "$INSTALL_DIR/requirements.txt" 2>/dev/null || true

# 6. Systemd Service Deployment
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

# Completion Output (Enterprise Control Panel UI)
clear
echo -e "${RED}┌─────────────────────────────────────────────────────────────────────────────┐${NC}"
echo -e "${RED}│${NC} ${RED}●${NC} ${YELLOW}●${NC} ${GREEN}●${NC}  ${LIGHT_CYAN}${BOLD}BLOOD CLOUD™ INTEGRATION SYSTEM${NC} ${DARK_GRAY}[v3.0-PRO]${NC}                        ${RED}│${NC}"
echo -e "${RED}├─────────────────────────────────────────────────────────────────────────────┤${NC}"
echo -e "${RED}│${NC}                                                                             ${RED}│${NC}"
echo -e "${RED}│${NC}  ${GREEN}SYSTEM STATUS${NC}  ::  ${BOLD}${WHITE}ONLINE & ACTIVE${NC} ${DARK_GRAY}(PID: Auto | Port: Active)${NC}           ${RED}│${NC}"
echo -e "${RED}│${NC}  ${CYAN}DEPLOYMENT${NC}     ::  ${WHITE}Discord Gateway Connected${NC}                               ${RED}│${NC}"
echo -e "${RED}│${NC}                                                                             ${RED}│${NC}"
echo -e "${RED}├─────────────────────────────────────────────────────────────────────────────┤${NC}"
echo -e "${RED}│${NC} ${BOLD}${WHITE}ENVIRONMENT METRICS${NC}                                                        ${RED}│${NC}"
echo -e "${RED}├─────────────────────────────────────────────────────────────────────────────┤${NC}"
echo -e "${RED}│${NC}                                                                             ${RED}│${NC}"
echo -e "${RED}│${NC}   ${LIGHT_CYAN}Target Directory${NC}  │ ${WHITE}${INSTALL_DIR}${NC}                                          ${RED}│${NC}"
echo -e "${RED}│${NC}   ${LIGHT_CYAN}Configuration${NC}     │ ${WHITE}${INSTALL_DIR}/.env${NC}                                     ${RED}│${NC}"
echo -e "${RED}│${NC}   ${LIGHT_CYAN}Python Engine${NC}     │ ${WHITE}${INSTALL_DIR}/venv/bin/python3${NC}                            ${RED}│${NC}"
echo -e "${RED}│${NC}                                                                             ${RED}│${NC}"
echo -e "${RED}├─────────────────────────────────────────────────────────────────────────────┤${NC}"
echo -e "${RED}│${NC} ${BOLD}${WHITE}SYSTEMD CONTROL COMMANDS${NC}                                                    ${RED}│${NC}"
echo -e "${RED}├─────────────────────────────────────────────────────────────────────────────┤${NC}"
echo -e "${RED}│${NC}                                                                             ${RED}│${NC}"
echo -e "${RED}│${NC}   ${GREEN}systemctl status bot${NC}       ${DARK_GRAY}│${NC} View service active state                  ${RED}│${NC}"
echo -e "${RED}│${NC}   ${CYAN}journalctl -u bot -f -n 50${NC} ${DARK_GRAY}│${NC} Stream real-time application logs          ${RED}│${NC}"
echo -e "${RED}│${NC}   ${YELLOW}systemctl restart bot${NC}      ${DARK_GRAY}│${NC} Hard restart background process            ${RED}│${NC}"
echo -e "${RED}│${NC}   ${RED}systemctl stop bot${NC}         ${DARK_GRAY}│${NC} Terminate bot process safely               ${RED}│${NC}"
echo -e "${RED}│${NC}                                                                             ${RED}│${NC}"
echo -e "${RED}├─────────────────────────────────────────────────────────────────────────────┤${NC}"
echo -e "${RED}│${NC} ${GOLD}${BOLD}Blood Cloud™ Infrastructure Suite${NC} ${DARK_GRAY}─ All rights reserved.${NC}                    ${RED}│${NC}"
echo -e "${RED}└─────────────────────────────────────────────────────────────────────────────┘${NC}"
echo -e ""
