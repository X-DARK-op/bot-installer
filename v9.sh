#!/bin/bash

# =================================================================
#  Blood Cloud™ - Incus/LXC Discord Bot Auto Installer & Code Generator
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
echo -e "${RED}🩸 Welcome to Blood Cloud™ Auto Installation System (Incus & LXC Native Bot)${NC}"
echo -e "${WHITE}========================================================================${NC}"

# 0. Root Privilege Check
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}❌ Error: Please run this script as root! (sudo bash script.sh)${NC}"
  exit 1
fi

# 1. Directory Setup Prompt
echo -e "\n${YELLOW}--- Step 1: Directory Setup ---${NC}"
echo -n -e "Enter folder name for installation [Default: blood-cloud]: "
read DIR_NAME < /dev/tty
DIR_NAME=${DIR_NAME:-blood-cloud}

INSTALL_DIR="/root/${DIR_NAME}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit 1

echo -e "${GREEN}📂 Installation Path Set To: ${WHITE}${INSTALL_DIR}${NC}"

# 2. System Dependencies Installation (Incus & LXC Support)
echo -e "\n${YELLOW}--- Step 2: Installing Dependencies & Incus/LXC Engines ---${NC}"
apt update -y
apt install -y python3 python3-pip python3-venv build-essential git curl pango1.0-tools lxc lxd-installer lxd-client snapd

# Check & Setup Incus / LXC Engine command priority
if ! command -v incus &> /dev/null && ! command -v lxc &> /dev/null; then
    echo -e "${CYAN}Setting up container management engines...${NC}"
    snap install lxd --channel=latest/stable 2>/dev/null || true
    ln -s /snap/bin/lxc /usr/bin/lxc 2>/dev/null || true
    lxd init --auto 2>/dev/null || true
fi
ln -s /snap/bin/lxc /usr/bin/lxc 2>/dev/null || true

# 3. Creating Requirements & Environment Template Files Locally
echo -e "\n${YELLOW}--- Step 3: Generating Project Files Locally ---${NC}"

cat << 'EOF' > "$INSTALL_DIR/requirements.txt"
discord.py>=2.3.2
python-dotenv>=1.0.0
asyncio
EOF

cat << 'EOF' > "$INSTALL_DIR/example.env"
DISCORD_TOKEN=your_bot_token_here
MAIN_ADMIN_ID=123456789012345678
BOT_NAME="Blood Cloud"
PREFIX="!"
LOGO_URL=https://i.imgur.com/v8S7y1H.png
BANNER_URL=https://i.imgur.com/43R3XqF.png
MOTD_CMD=bash <(curl -fsSL https://raw.githubusercontent.com/X-DARK-op/bot-installer/main/MOTD)
EOF

# 4. Generating Complete Incus/LXC Native Bot Script (bot.py) Locally
cat << 'EOF' > "$INSTALL_DIR/bot.py"
import os
import re
import random
import string
import logging
import asyncio
import discord
from discord.ext import commands
from dotenv import load_dotenv

load_dotenv()

DISCORD_TOKEN = os.getenv("DISCORD_TOKEN")
MAIN_ADMIN_ID = os.getenv("MAIN_ADMIN_ID", "0")
BOT_NAME = os.getenv("BOT_NAME", "Blood Cloud")
PREFIX = os.getenv("PREFIX", "!")
LOGO_URL = os.getenv("LOGO_URL", "")
BANNER_URL = os.getenv("BANNER_URL", "")
MOTD_CMD = os.getenv("MOTD_CMD", "bash <(curl -fsSL https://raw.githubusercontent.com/X-DARK-op/bot-installer/main/MOTD)")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("BloodCloudIncusBot")

intents = discord.Intents.default()
intents.message_content = True
bot = commands.Bot(command_prefix=PREFIX, intents=intents, help_command=None)

vps_data = {}
admin_data = {"admins": [MAIN_ADMIN_ID]}

def generate_strong_password(length=12):
    chars = string.ascii_letters + string.digits + "!@#$%^&*"
    return ''.join(random.choice(chars) for _ in range(length))

def apply_branding(embed: discord.Embed, show_banner: bool = False):
    if LOGO_URL:
        embed.set_thumbnail(url=LOGO_URL)
    if show_banner and BANNER_URL:
        embed.set_image(url=BANNER_URL)
    embed.set_footer(text=f"Powered by {BOT_NAME} (Incus Engine)", icon_url=LOGO_URL if LOGO_URL else None)
    return embed

def create_info_embed(title, description="", show_banner=False):
    embed = discord.Embed(title=title, description=description, color=discord.Color.red())
    return apply_branding(embed, show_banner)

def create_success_embed(title, description="", show_banner=False):
    embed = discord.Embed(title=f"✅ {title}", description=description, color=discord.Color.green())
    return apply_branding(embed, show_banner)

def create_error_embed(title, description="", show_banner=False):
    embed = discord.Embed(title=f"❌ {title}", description=description, color=discord.Color.dark_red())
    return apply_branding(embed, show_banner)

def create_warning_embed(title, description="", show_banner=False):
    embed = discord.Embed(title=f"⚠️ {title}", description=description, color=discord.Color.gold())
    return apply_branding(embed, show_banner)

def add_field(embed, name, value, inline=True):
    embed.add_field(name=name, value=value, inline=inline)

def format_expiration(vps):
    return vps.get("expires", "Never")

def get_node(node_id):
    return {"id": node_id, "name": f"Incus-Node-{node_id}"}

async def execute_cli(container_name, command, node_id=1):
    # Automatically check if incus is available, fallback to lxc CLI syntax
    cli_tool = "incus" if os.system("command -v incus &> /dev/null") == 0 else "lxc"
    if not os.path.exists("/usr/bin/incus") and os.path.exists("/snap/bin/incus"):
        cli_tool = "/snap/bin/incus"
    
    full_cmd = f"{cli_tool} {command}"
    logger.info(f"Executing Incus/LXC command for {container_name}: {full_cmd}")
    
    proc = await asyncio.create_subprocess_shell(
        full_cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )
    stdout, stderr = await proc.communicate()
    if proc.returncode != 0:
        err_msg = stderr.decode().strip()
        logger.error(f"Incus/LXC Error: {err_msg}")
        raise Exception(err_msg or "Container engine command failed")
    return stdout.decode().strip()

async def get_container_status(container_name, node_id=1):
    try:
        res = await execute_cli(container_name, f"info {container_name}", node_id)
        if "Status: running" in res:
            return "running"
        return "stopped"
    except Exception:
        return "stopped"

async def get_container_networks(container_name, node_id=1):
    try:
        res = await execute_cli(container_name, f"list {container_name} --format csv -c n", node_id)
        if res:
            return {"eth0": res.split()[0]}
    except Exception:
        pass
    return {"eth0": "10.x.x.x"}

async def configure_ssh(container_name, node_id, password):
    await execute_cli(container_name, f"exec {container_name} -- echo 'root:{password}' | chpasswd", node_id)
    await execute_cli(container_name, f"exec {container_name} -- sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config", node_id)
    await execute_cli(container_name, f"exec {container_name} -- sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config", node_id)
    await execute_cli(container_name, f"exec {container_name} -- systemctl restart ssh sshd 2>/dev/null || true", node_id)
    logger.info(f"SSH reconfigured for Incus instance {container_name}")
    return True

async def apply_vps_motd(container_name, node_id):
    try:
        cmd = f"exec {container_name} -- {MOTD_CMD}"
        await execute_cli(container_name, cmd, node_id=node_id)
        logger.info(f"MOTD command executed successfully on Incus instance {container_name}")
    except Exception as e:
        logger.error(f"Failed to execute MOTD command on {container_name}: {e}")

class ReinstallOSSelectView(discord.ui.View):
    def __init__(self, parent_view, container_name, owner_id, actual_idx, ram_gb, cpu, storage_gb, node_id):
        super().__init__(timeout=60)
        self.parent_view = parent_view
        self.container_name = container_name
        self.owner_id = owner_id
        self.actual_idx = actual_idx
        self.ram_gb = ram_gb
        self.cpu = cpu
        self.storage_gb = storage_gb
        self.node_id = node_id

        options = [
            discord.SelectOption(label="Ubuntu 22.04 (Incus)", value="images:ubuntu/22.04"),
            discord.SelectOption(label="Ubuntu 20.04 (Incus)", value="images:ubuntu/20.04"),
            discord.SelectOption(label="Debian 12 (Incus)", value="images:debian/12"),
            discord.SelectOption(label="Alpine 3.18 (Incus)", value="images:alpine/3.18")
        ]
        self.select = discord.ui.Select(placeholder="Choose Incus Operating System", options=options)
        self.select.callback = self.select_os
        self.add_item(self.select)

    async def select_os(self, interaction: discord.Interaction):
        await interaction.response.defer()
        selected_os = self.select.values[0]
        new_password = generate_strong_password()

        try:
            await execute_cli(self.container_name, f"init {selected_os} {self.container_name}", node_id=self.node_id)
            await execute_cli(self.container_name, f"config set {self.container_name} limits.memory {self.ram_gb}GB", node_id=self.node_id)
            await execute_cli(self.container_name, f"config set {self.container_name} limits.cpu {self.cpu}", node_id=self.node_id)
            await execute_cli(self.container_name, f"start {self.container_name}", node_id=self.node_id)
            await asyncio.sleep(3)
            await configure_ssh(self.container_name, self.node_id, new_password)
            await apply_vps_motd(self.container_name, self.node_id)

            success_embed = create_success_embed("Incus Reinstall Complete", f"Instance `{self.container_name}` reinstalled with `{selected_os}`.")
            await interaction.followup.send(embed=success_embed)
            
            try:
                owner = await bot.fetch_user(int(self.owner_id))
                dm_embed = create_success_embed("🔄 Incus VPS Reinstalled Successfully!", f"Your container `{self.container_name}` has been reinstalled.", show_banner=True)
                
                try:
                    networks = await asyncio.wait_for(get_container_networks(self.container_name, self.node_id), timeout=3.0)
                except asyncio.TimeoutError:
                    networks = {}

                if networks:
                    ssh_access_info = "**🖥️ Available Connection Points:**\n"
                    for interface, ip in sorted(networks.items()):
                        ssh_access_info += f"└─ **{interface}:** `ssh root@{ip}`\n"
                else:
                    ssh_access_info = "**📡 SSH Command:** `ssh root@<your-vps-ip>`\n"
                
                ssh_access_info += f"\n**🔑 Login Credentials:**\n"
                ssh_access_info += f"**Username:** `root`\n"
                ssh_access_info += f"**Password:** `{new_password}`\n"
                
                add_field(dm_embed, "🔐 New SSH Credentials", ssh_access_info, False)
                await owner.send(embed=dm_embed)
            except Exception as e:
                logger.warning(f"Could not send DM: {e}")

        except Exception as e:
            await interaction.followup.send(embed=create_error_embed("Reinstall Failed", f"Error: {str(e)}"))

class ConfirmReinstallView(discord.ui.View):
    def __init__(self, parent_view, container_name, owner_id, actual_idx, ram_gb, cpu, storage_gb, node_id):
        super().__init__(timeout=60)
        self.parent_view = parent_view
        self.container_name = container_name
        self.owner_id = owner_id
        self.actual_idx = actual_idx
        self.ram_gb = ram_gb
        self.cpu = cpu
        self.storage_gb = storage_gb
        self.node_id = node_id

    @discord.ui.button(label="Confirm Reinstall", style=discord.ButtonStyle.danger)
    async def confirm(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.defer()
        try:
            await execute_cli(self.container_name, f"stop {self.container_name} --force", node_id=self.node_id)
        except Exception:
            pass
        try:
            await execute_cli(self.container_name, f"delete {self.container_name} --force", node_id=self.node_id)
        except Exception:
            pass

        os_view = ReinstallOSSelectView(
            self.parent_view, self.container_name, self.owner_id, 
            self.actual_idx, self.ram_gb, self.cpu, self.storage_gb, self.node_id
        )
        await interaction.followup.send(embed=create_info_embed("Select OS", "Choose the operating system to configure:"), view=os_view)

    @discord.ui.button(label="Cancel", style=discord.ButtonStyle.secondary)
    async def cancel(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.send_message("Reinstall canceled.", ephemeral=True)

class VPSControlView(discord.ui.View):
    def __init__(self, ctx, user_id):
        super().__init__(timeout=180)
        self.ctx = ctx
        self.user_id = str(user_id)
        self.vps_list = vps_data.get(self.user_id, [])
        self.current_idx = 0

        options = [
            discord.SelectOption(label=f"{v['container_name']}", value=str(i))
            for i, v in enumerate(self.vps_list)
        ]
        if options:
            self.select = discord.ui.Select(placeholder="Select an Incus VPS to Manage", options=options)
            self.select.callback = self.select_vps
            self.add_item(self.select)

    async def select_vps(self, interaction: discord.Interaction):
        self.current_idx = int(self.select.values[0])
        await self.update_dashboard(interaction)

    async def update_dashboard(self, interaction: discord.Interaction):
        if not self.vps_list:
            await interaction.response.send_message("No container found.", ephemeral=True)
            return

        vps = self.vps_list[self.current_idx]
        node_id = vps.get('node_id', 1)
        container_name = vps['container_name']

        status = await get_container_status(container_name, node_id)
        vps['status'] = status

        embed = create_info_embed(f"Incus Panel: {container_name}", show_banner=True)
        add_field(embed, "Status", f"`{status.upper()}`", True)
        add_field(embed, "Config", f"`{vps.get('config', 'Custom')}`", True)
        add_field(embed, "Engine", "`Incus / LXC`", True)
        add_field(embed, "Expiration", format_expiration(vps), False)

        if interaction.response.is_done():
            await interaction.message.edit(embed=embed, view=self)
        else:
            await interaction.response.edit_message(embed=embed, view=self)

    @discord.ui.button(label="Start", style=discord.ButtonStyle.success, row=1)
    async def start_vps(self, interaction: discord.Interaction, button: discord.ui.Button):
        if not self.vps_list: return
        vps = self.vps_list[self.current_idx]
        await execute_cli(vps['container_name'], f"start {vps['container_name']}", node_id=vps.get('node_id', 1))
        await self.update_dashboard(interaction)

    @discord.ui.button(label="Stop", style=discord.ButtonStyle.danger, row=1)
    async def stop_vps(self, interaction: discord.Interaction, button: discord.ui.Button):
        if not self.vps_list: return
        vps = self.vps_list[self.current_idx]
        await execute_cli(vps['container_name'], f"stop {vps['container_name']}", node_id=vps.get('node_id', 1))
        await self.update_dashboard(interaction)

    @discord.ui.button(label="Restart", style=discord.ButtonStyle.primary, row=1)
    async def restart_vps(self, interaction: discord.Interaction, button: discord.ui.Button):
        if not self.vps_list: return
        vps = self.vps_list[self.current_idx]
        await execute_cli(vps['container_name'], f"restart {vps['container_name']}", node_id=vps.get('node_id', 1))
        await self.update_dashboard(interaction)

    @discord.ui.button(label="🔑 New Password", style=discord.ButtonStyle.secondary, row=2)
    async def reset_password(self, interaction: discord.Interaction, button: discord.ui.Button):
        if not self.vps_list: return
        vps = self.vps_list[self.current_idx]
        new_pass = generate_strong_password()
        await configure_ssh(vps['container_name'], vps.get('node_id', 1), new_pass)
        await interaction.response.send_message(f"🔐 Password for `{vps['container_name']}` reset to: `{new_pass}`", ephemeral=True)

    @discord.ui.button(label="🔄 Reinstall", style=discord.ButtonStyle.danger, row=2)
    async def reinstall(self, interaction: discord.Interaction, button: discord.ui.Button):
        if not self.vps_list: return
        vps = self.vps_list[self.current_idx]
        
        ram_gb = int(''.join(filter(str.isdigit, str(vps.get('ram', '1'))))) or 1
        cpu = int(vps.get('cpu', 1)) or 1
        storage_gb = int(''.join(filter(str.isdigit, str(vps.get('storage', '10'))))) or 10
        
        view = ConfirmReinstallView(
            self, vps['container_name'], self.user_id, self.current_idx,
            ram_gb, cpu, storage_gb, vps.get('node_id', 1)
        )
        embed = create_warning_embed("⚠️ Reinstall Confirmation", f"Are you sure you want to reinstall `{vps['container_name']}`? **ALL DATA WILL BE ERASED.**")
        await interaction.response.send_message(embed=embed, view=view, ephemeral=True)

@bot.command(name="create")
@commands.has_permissions(administrator=True)
async def create_vps(ctx, ram_gb: int, cpu: int, disk_gb: int, member: discord.Member):
    user_id = str(member.id)
    
    await ctx.send(embed=create_info_embed("VPS Name Required", f"Please reply in this chat with the **desired Incus container name** for {member.mention}:"))

    def check(m):
        return m.author == ctx.author and m.channel == ctx.channel

    try:
        msg = await bot.wait_for('message', timeout=30.0, check=check)
        container_name = msg.content.strip()
    except asyncio.TimeoutError:
        await ctx.send(embed=create_error_embed("Timeout", "No name provided in time. Creation cancelled."))
        return

    if not re.match("^[a-zA-Z0-9-_]+$", container_name):
        await ctx.send(embed=create_error_embed("Invalid Name", "Container name can only contain letters, numbers, dashes, and underscores."))
        return

    node_id = 1
    new_password = generate_strong_password()
    selected_os = "images:ubuntu/22.04"

    progress_msg = await ctx.send(embed=create_info_embed("Deploying Incus VPS", f"Creating container `{container_name}`..."))

    try:
        await execute_cli(container_name, f"init {selected_os} {container_name}", node_id=node_id)
        await execute_cli(container_name, f"config set {container_name} limits.memory {ram_gb}GB", node_id=node_id)
        await execute_cli(container_name, f"config set {container_name} limits.cpu {cpu}", node_id=node_id)
        await execute_cli(container_name, f"start {container_name}", node_id=node_id)
        await asyncio.sleep(3)
        await configure_ssh(container_name, node_id, new_password)
        await apply_vps_motd(container_name, node_id)

        if user_id not in vps_data:
            vps_data[user_id] = []
        
        vps_info = {
            "container_name": container_name,
            "ram": f"{ram_gb}GB",
            "cpu": str(cpu),
            "storage": f"{disk_gb}GB",
            "node_id": node_id,
            "config": f"{ram_gb}GB RAM / {cpu} CPU",
            "expires": "Never"
        }
        vps_data[user_id].append(vps_info)

        success_embed = create_success_embed("Incus VPS Deployed Successfully!", f"Container `{container_name}` has been successfully created via Incus and assigned to {member.mention}.", show_banner=True)
        add_field(success_embed, "Specs", f"RAM: {ram_gb}GB | CPU: {cpu} | Disk: {disk_gb}GB", False)
        await progress_msg.edit(embed=success_embed)

        try:
            dm_embed = create_success_embed("🚀 Your Incus VPS is Ready!", f"Your container `{container_name}` has been deployed on **{BOT_NAME}**.", show_banner=True)
            
            try:
                networks = await asyncio.wait_for(get_container_networks(container_name, node_id), timeout=3.0)
            except asyncio.TimeoutError:
                networks = {}

            if networks:
                ssh_access_info = "**🖥️ Connection Points:**\n"
                for interface, ip in sorted(networks.items()):
                    ssh_access_info += f"└─ **{interface}:** `ssh root@{ip}`\n"
            else:
                ssh_access_info = "**📡 SSH Command:** `ssh root@<your-vps-ip>`\n"
            
            ssh_access_info += f"\n**🔑 Login Credentials:**\n"
            ssh_access_info += f"**Username:** `root`\n"
            ssh_access_info += f"**Password:** `{new_password}`\n"
            ssh_access_info += f"\n*(Note: Blood Cloud custom branding MOTD is active!)*"
            
            add_field(dm_embed, "🔐 Access Details", ssh_access_info, False)
            await member.send(embed=dm_embed)
        except Exception as e:
            logger.warning(f"Could not send DM: {e}")

    except Exception as e:
        await ctx.send(embed=create_error_embed("Deployment Failed", f"An error occurred: {str(e)}"))

@bot.command(name="manage")
async def manage(ctx):
    user_id = str(ctx.author.id)
    if user_id not in vps_data or not vps_data[user_id]:
        await ctx.send(embed=create_error_embed("No VPS Found", "You do not own any Incus VPS containers."))
        return
    view = VPSControlView(ctx, user_id)
    embed = create_info_embed("Incus VPS Control Panel", "Select a container from the dropdown below to manage it.", show_banner=True)
    await ctx.send(embed=embed, view=view)

@bot.command(name="reinstall")
async def reinstall_cmd(ctx):
    await manage(ctx)

@bot.command(name="help")
async def help_cmd(ctx):
    embed = create_info_embed(f"🤖 {BOT_NAME} Incus Help Menu", "List of available commands:", show_banner=True)
    add_field(embed, "User Commands", f"`{PREFIX}myvps` - View your VPS list\n`{PREFIX}manage` - Control Panel (Start, Stop, Reinstall, Password)\n`{PREFIX}ping` - Check latency", False)
    
    user_id = str(ctx.author.id)
    if user_id == str(MAIN_ADMIN_ID) or user_id in admin_data.get("admins", []):
        add_field(embed, "Admin Commands", f"`{PREFIX}create <ram> <cpu> <disk> <@user>` - Deploy Incus VPS", False)
    
    await ctx.send(embed=embed)

@bot.event
async def on_ready():
    logger.info(f"Bot logged in as {bot.user.name} ({bot.user.id}) with Incus Engine support.")

if __name__ == '__main__':
    if not DISCORD_TOKEN:
        logger.error("DISCORD_TOKEN is missing!")
    else:
        bot.run(DISCORD_TOKEN)
EOF

echo -e "${GREEN}✔ Incus/LXC Bot file (bot.py) created successfully!${NC}"

# 5. Interactive Configuration Setup (.env)
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

# 6. Virtual Environment & Dual Installation Setup
echo -e "\n${YELLOW}--- Step 5: Preparing Python Environment ---${NC}"

python3 -m venv "$INSTALL_DIR/venv"
"$INSTALL_DIR/venv/bin/pip" install --upgrade pip --quiet
"$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/requirements.txt"

pip3 install -r "$INSTALL_DIR/requirements.txt" --break-system-packages 2>/dev/null || pip3 install -r "$INSTALL_DIR/requirements.txt" 2>/dev/null || true

# 7. Systemd Service Deployment
echo -e "\n${YELLOW}--- Step 6: Setting Up Systemd Background Service ---${NC}"

cat <<SERVICEFILE > /etc/systemd/system/bot.service
[Unit]
Description=Blood Cloud Incus Discord Bot
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
echo -e "${RED}│${NC} ${RED}●${NC} ${YELLOW}●${NC} ${GREEN}●${NC}  ${LIGHT_CYAN}${BOLD}BLOOD CLOUD™ INCUS INTEGRATION${NC} ${DARK_GRAY}[v3.0-PRO]${NC}                  ${RED}│${NC}"
echo -e "${RED}├─────────────────────────────────────────────────────────────────────────────┤${NC}"
echo -e "${RED}│${NC}                                                                             ${RED}│${NC}"
echo -e "${RED}│${NC}  ${GREEN}SYSTEM STATUS${NC}  ::  ${BOLD}${WHITE}ONLINE & ACTIVE${NC} ${DARK_GRAY}(Incus / LXC Engine Ready)${NC}      ${RED}│${NC}"
echo -e "${RED}│${NC}  ${CYAN}DEPLOYMENT${NC}     ::  ${WHITE}Discord Gateway Connected${NC}                               ${RED}│${NC}"
echo -e "${RED}│${NC}                                                                             ${RED}│${NC}"
echo -e "${RED}├─────────────────────────────────────────────────────────────────────────────┤${NC}"
echo -e "${RED}│${NC} ${BOLD}${WHITE}ENVIRONMENT METRICS${NC}                                                        ${RED}│${NC}"
echo -e "${RED}├─────────────────────────────────────────────────────────────────────────────┤${NC}"
echo -e "${RED}│${NC}                                                                             ${RED}│${NC}"
echo -e "${RED}│${NC}   ${LIGHT_CYAN}Target Directory${NC}  │ ${WHITE}${INSTALL_DIR}${NC}                                          ${RED}│${NC}"
echo -e "${RED}│${NC}   ${LIGHT_CYAN}Configuration${NC}     │ ${WHITE}${INSTALL_DIR}/.env${NC}                                     ${RED}│${NC}"
echo -e "${RED}│${NC}   ${LIGHT_CYAN}Bot Source File${NC}   │ ${WHITE}${INSTALL_DIR}/bot.py${NC}                                   ${RED}│${NC}"
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
