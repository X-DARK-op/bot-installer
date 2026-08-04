#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}===========================================${NC}"
echo -e "${GREEN}       Discord Bot Auto Installer        ${NC}"
echo -e "${BLUE}===========================================${NC}"

if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}Please run this script as root! (use sudo)${NC}"
  exit 1
fi

# 1. Directory Setup Prompt
echo -e "\n${YELLOW}--- Installation Directory Setup ---${NC}"
read -p "Enter folder name to install into [Default: vps]: " DIR_NAME </dev/tty
DIR_NAME=${DIR_NAME:-vps}

INSTALL_DIR="/root/${DIR_NAME}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit 1

echo -e "${GREEN}Installing files into: ${INSTALL_DIR}${NC}"

# 2. Downloading Files
echo -e "\n${YELLOW}Downloading files from Catbox...${NC}"
curl -sSL "https://files.catbox.moe/e7m1ou.py" -o "$INSTALL_DIR/bot.py"
curl -sSL "https://files.catbox.moe/wjzlfv.txt" -o "$INSTALL_DIR/requirements.txt"
curl -sSL "https://files.catbox.moe/dbvwq3.env" -o "$INSTALL_DIR/example.env"

echo -e "${GREEN}Files downloaded successfully!${NC}"

# 3. Interactive .env Generator
echo -e "\n${YELLOW}--- Bot Setup Configurations ---${NC}"

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
                    echo -e "${RED}This field cannot be empty! Please provide a value.${NC}"
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
    echo -e "${GREEN}Configuration saved to $INSTALL_DIR/.env!${NC}"
else
    echo -e "${RED}Error: example.env not found!${NC}"
    exit 1
fi

# 4. System Dependencies
echo -e "\n${YELLOW}Updating system packages and installing dependencies...${NC}"
apt update && apt upgrade -y
apt install -y python3 python3-pip python3-venv build-essential pango1.0-tools lxd lxd-client

# LXD Setup
echo -e "\n${YELLOW}Initializing LXD container engine...${NC}"
lxd init --auto

# Python Requirements
echo -e "\n${YELLOW}Installing Python packages...${NC}"
pip3 install --break-system-packages davey -r "$INSTALL_DIR/requirements.txt" || pip3 install davey -r "$INSTALL_DIR/requirements.txt"

# 5. Systemd Service Setup
echo -e "\n${YELLOW}Creating Systemd Service...${NC}"
cat <<SERVICEFILE > /etc/systemd/system/bot.service
[Unit]
Description=Discord Bot Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/python3 $INSTALL_DIR/bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICEFILE

# Reload and Restart Service
systemctl daemon-reload
systemctl enable bot.service
systemctl restart bot.service

# Clear Screen & Show Dashboard
clear

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE} ${BOLD}               ✨ SETUP COMPLETED SUCCESSFULLY ✨                       ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}                                                                          ${CYAN}║${NC}"
echo -e "${CYAN}║${GREEN}  🚀 Files installed to: ${WHITE}${INSTALL_DIR}                                 ${CYAN}║${NC}"
echo -e "${CYAN}║${GREEN}  📂 Go to directory:   ${YELLOW}cd ${INSTALL_DIR}                                      ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                                          ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${PURPLE} ${BOLD}           📌 QUICK SYSTEMCTL COMMANDS CHEATSHEET 📌                    ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}                                                                          ${CYAN}║${NC}"
echo -e "${CYAN}║${YELLOW}  ▶ Start Bot:${NC}       systemctl start bot                                 ${CYAN}║${NC}"
echo -e "${CYAN}║${RED}  ▶ Stop Bot:${NC}        systemctl stop bot                                  ${CYAN}║${NC}"
echo -e "${CYAN}║${BLUE}  ▶ Restart Bot:${NC}     systemctl restart bot                               ${CYAN}║${NC}"
echo -e "${CYAN}║${GREEN}  ▶ Check Status:${NC}    systemctl status bot                                ${CYAN}║${NC}"
echo -e "${CYAN}║${CYAN}  ▶ View Live Logs:${NC}  journalctl -u bot -f -n 50                          ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                                          ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${WHITE}  📁 Files Path: ${GREEN}${INSTALL_DIR}/.env${WHITE} | ${GREEN}${INSTALL_DIR}/bot.py                     ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
echo -e ""
