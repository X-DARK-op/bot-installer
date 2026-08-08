#!/bin/bash

# Clear screen
clear

echo "=================================================="
echo "    VPS LXC/LXD & Incus Environment Auto-Fixer   "
echo "=================================================="
echo ""

# Check Root User
if [ "$EUID" -ne 0 ]; then
  echo "❌ Error: Ye script root user se chalayein! (sudo su)"
  exit 1
fi

echo "🔄 [1/5] System packages aur tools update ho rahe hain..."
apt update -y && apt install -y curl gpg software-properties-common ca-certificates >/dev/null 2>&1

echo "🧹 [2/5] Purani aur broken links saaf ki ja rahi hain..."
rm -f /etc/apt/sources.list.d/zabbly* /usr/bin/lxc /usr/bin/lxd /usr/local/bin/lxc /usr/local/bin/lxd

echo "📦 [3/5] Incus Engine repository setup ki ja rahi hai..."
echo "deb [trusted=yes] https://pkgs.zabbly.com/incus/stable jammy main" > /etc/apt/sources.list.d/zabbly-incus-stable.list

apt update -y >/dev/null 2>&1
apt install -y incus >/dev/null 2>&1

if ! command -v incus &> /dev/null; then
    echo "❌ Error: Incus installation fail ho gayi. Internet connection check karein!"
    exit 1
fi

echo "⚙️ [4/5] AppArmor aur Network Bypassed Init apply ho raha hai..."
cat <<EOF | incus admin init --preseed >/dev/null 2>&1
config: {}
networks: []
storage_pools:
- name: default
  driver: dir
profiles:
- name: default
  devices: {}
EOF

echo "🔗 [5/5] LXD/LXC compatibility layer aur symlinks link ho rahe hain..."
ln -s /usr/bin/incus /usr/bin/lxc
ln -s /usr/bin/incus /usr/bin/lxd
systemctl enable --now incus-lxd.socket >/dev/null 2>&1 || true

# Bot Restart (agar systemd service bani hui ho)
if systemctl is-active --quiet bot || systemctl is-enabled --quiet bot; then
    echo "🔄 Bot service restart ki ja rahi hai..."
    systemctl restart bot
fi

echo ""
echo "=================================================="
echo " ✅ SUCCESS: VPS Container Engine Setup Complete! "
echo "=================================================="
echo " Ab aapka Python Bot bina kisi maslay ke VPS create kar sakega."
echo ""
