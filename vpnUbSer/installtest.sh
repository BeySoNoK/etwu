#!/bin/bash

# ==================== SETTINGS ====================
INSTALL_PATH="/opt/easytier"
EASYTIER_BIN="/usr/local/bin/easytier-core"
SERVICE_NAME="easytier"
# ==================================================

RED_COLOR='\e[1;31m'
GREEN_COLOR='\e[1;32m'
YELLOW_COLOR='\e[1;33m'
RES='\e[0m'

if [ "$(id -u)" != "0" ]; then
  echo -e "\r\n${RED_COLOR}Error: Script must be run as root (use sudo)!${RES}\r\n"
  exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then echo -e "\r\n${RED_COLOR}Error: unzip is not installed${RES}\r\n"; exit 1; fi
if ! command -v curl >/dev/null 2>&1; then echo -e "\r\n${RED_COLOR}Error: curl is not installed${RES}\r\n"; exit 1; fi

if command -v arch >/dev/null 2>&1; then platform=$(arch); else platform=$(uname -m); fi
case "$platform" in
  amd64 | x86_64) ARCH="x86_64" ;;
  arm64 | aarch64 | *armv8*) ARCH="aarch64" ;;
  *armv7*) ARCH="armv7" ;;
  *arm*) ARCH="arm" ;;
  *) ARCH="UNKNOWN" ;;
esac
if [[ "$ARCH" == "UNKNOWN" ]]; then echo -e "\r\n${RED_COLOR}Unsupported platform${RES}\r\n"; exit 1; fi

echo -e "\r\n${GREEN_COLOR}Creating directories...${RES}"
mkdir -p $INSTALL_PATH/config
mkdir -p $(dirname $EASYTIER_BIN)

echo -e "\r\n${GREEN_COLOR}Downloading latest EasyTier...${RES}"
RESPONSE=$(curl -s "https://api.github.com/repos/EasyTier/EasyTier/releases/latest")
LATEST_VERSION=$(echo "$RESPONSE" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | tr -d '[:space:]')

if [ -z "$LATEST_VERSION" ]; then echo -e "\r\n${RED_COLOR}Failed to get version${RES}\r\n"; exit 1; fi

BASE_URL="https://github.com/EasyTier/EasyTier/releases/latest/download/easytier-linux-${ARCH}-${LATEST_VERSION}.zip"
DOWNLOAD_URL="https://ghfast.top/${BASE_URL}"
rm -rf /tmp/easytier_tmp_install.zip
curl -L ${DOWNLOAD_URL} -o /tmp/easytier_tmp_install.zip

echo -e "\r\n${GREEN_COLOR}Extracting...${RES}"
unzip -o /tmp/easytier_tmp_install.zip -d $INSTALL_PATH/ > /dev/null
mv $INSTALL_PATH/easytier-linux-${ARCH}/* $INSTALL_PATH/
rm -rf $INSTALL_PATH/easytier-linux-${ARCH}/ /tmp/easytier_tmp_install.zip
chmod +x $INSTALL_PATH/easytier-core $INSTALL_PATH/easytier-cli

ln -sf $INSTALL_PATH/easytier-core $EASYTIER_BIN
ln -sf $INSTALL_PATH/easytier-cli $(dirname $EASYTIER_BIN)/easytier-cli

echo -e "\r\n${GREEN_COLOR}Creating systemd service...${RES}"
cat >/etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=EasyTier VPN Service
Wants=network.target
After=network.target network.service
# Служба запустится только если файл конфигурации существует
ConditionPathExists=$INSTALL_PATH/config/default.conf

[Service]
Type=simple
WorkingDirectory=$INSTALL_PATH
ExecStart=$INSTALL_PATH/easytier-core -c $INSTALL_PATH/config/default.conf
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ${SERVICE_NAME} >/dev/null 2>&1

echo -e "\r\n${GREEN_COLOR}=====================================================${RES}"
echo -e "${GREEN_COLOR} Installation complete!${RES}"
echo -e "${GREEN_COLOR}=====================================================${RES}"
echo -e "The service is installed and enabled, but NOT STARTED yet."
echo -e "To connect, create a file named 'connect.sh' (see instructions)."