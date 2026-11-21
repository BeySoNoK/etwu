#!/bin/bash

VPN_NETWORK_NAME="BeySoN-VPN"
VPN_CREDENTIAL="4YfNfoMKyoewMzPy1ndHUi7e5WzaF7PC1gCnft2zg7g="
VPN_SERVER="tcp://86.57.218.145:11011"

if [ "$(id -u)" != "0" ]; then echo "Error: Run as root (sudo bash connect.sh)"; exit 1; fi

echo "Applying new configuration via systemd service..."

systemctl stop easytier || true
pkill -9 easytier-core || true

cat >/etc/systemd/system/easytier.service <<EOF
[Unit]
Description=EasyTier VPN Service
Wants=network.target
After=network.target network.service

[Service]
Type=simple
WorkingDirectory=/opt/easytier
ExecStart=/opt/easytier/easytier-core --network-name "$VPN_NETWORK_NAME" --credential "$VPN_CREDENTIAL" -p "$VPN_SERVER" --no-tun -i 10.10.10.4/24
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
