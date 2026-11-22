#!/bin/bash

# ==================== НАСТРОЙКИ ====================
VPN_NETWORK_NAME="BeySoN-VPN"
VPN_CREDENTIAL="4YfNfoMKyoewMzPy1ndHUi7e5WzaF7PC1gCnft2zg7g="
VPN_SERVER_EXTERNAL="86.57.218.145:11011"
VPN_SERVER_INTERNAL="192.168.0.111:11011" # Внутренний IP твоего сервера (замени на свой, если другой)
IP_FLAG="-i 10.10.10.4/24" # или "-d" для DHCP
# ==================================================

if [ "$(id -u)" != "0" ]; then echo "Error: Run as root (sudo bash connect.sh)"; exit 1; fi

echo "Detecting network environment..."
# Получаем первые три октета внешнего IP сервера (например, "86.57.218")
EXTERNAL_PREFIX=$(echo "$VPN_SERVER_EXTERNAL" | cut -d. -f1-3)

# Проверяем, есть ли у нас интерфейс с таким же префиксом
if ip a | grep -q "inet $EXTERNAL_PREFIX\."; then
    echo "-> Local network detected! Using internal server IP."
    VPN_SERVER="tcp://$VPN_SERVER_INTERNAL"
else
    echo "-> External connection detected. Using external server IP."
    VPN_SERVER="tcp://$VPN_SERVER_EXTERNAL"
fi

echo "Applying new configuration via systemd service..."

systemctl stop easytier || true
pkill -9 easytier-core || true
sleep 1

cat >/etc/systemd/system/easytier.service <<EOF
[Unit]
Description=EasyTier VPN Service
Wants=network.target
After=network.target network.service

[Service]
Type=simple
WorkingDirectory=/opt/easytier
ExecStart=/opt/easytier/easytier-core --network-name "$VPN_NETWORK_NAME" --credential "$VPN_CREDENTIAL" -p "$VPN_SERVER" --no-tun $IP_FLAG
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable easytier >/dev/null 2>&1
systemctl restart easytier

echo "Restarting EasyTier service..."
sleep 2

echo "Done! Current service status:"
systemctl status easytier --no-pager
