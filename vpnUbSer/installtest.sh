#!/bin/bash

# ==================== НАСТРОЙКИ ====================
INSTALL_PATH="/opt/easytier"
EASYTIER_BIN="/usr/local/bin/easytier-core"
TARGET_VERSION="v2.7.0" # Фиксируем версию для стабильности
# ==================================================

# Цвета для красивого вывода
GREEN='\e[1;32m'
RED='\e[1;31m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
RES='\e[0m'

# Проверка на Root
if [ "$(id -u)" != "0" ]; then
  echo -e "${RED}Ошибка: Скрипт должен быть запущен от имени root (используйте sudo)!${RES}"
  exit 1
fi

# Проверка зависимостей
if ! command -v unzip >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    echo -e "${YELLOW}Установка необходимых пакетов (curl, unzip)...${RES}"
    apt-get update -qq && apt-get install -y curl unzip >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}Не удалось установить curl или unzip. Установите их вручную.${RES}"
        exit 1
    fi
fi

# Определение архитектуры
platform=$(uname -m)
case "$platform" in
  x86_64|amd64) ARCH="x86_64" ;;
  aarch64|arm64) ARCH="aarch64" ;;
  armv7*) ARCH="armv7" ;;
  *) echo -e "${RED}Ваша архитектура ($platform) не поддерживается.${RES}"; exit 1 ;;
esac

echo -e "${BLUE}=== Начинаем установку EasyTier $TARGET_VERSION ($ARCH) ===${RES}"

# Очистка старых файлов
echo -e "${YELLOW}Очистка предыдущих версий...${RES}"
systemctl stop easytier >/dev/null 2>&1
systemctl disable easytier >/dev/null 2>&1
rm -rf $INSTALL_PATH
mkdir -p $INSTALL_PATH
mkdir -p $(dirname $EASYTIER_BIN)

# Скачивание
echo -e "${YELLOW}Скачивание архива...${RES}"
BASE_URL="https://github.com/EasyTier/EasyTier/releases/download/${TARGET_VERSION}/easytier-linux-${ARCH}-${TARGET_VERSION}.zip"
DOWNLOAD_URL="https://ghfast.top/${BASE_URL}" # Используем прокси для РФ/Китая

rm -f /tmp/easytier.zip
curl -L ${DOWNLOAD_URL} -o /tmp/easytier.zip -s

if ! file /tmp/easytier.zip | grep -q "Zip archive"; then
    echo -e "${RED}Ошибка скачивания! Возможно, GitHub недоступен.${RES}"
    exit 1
fi

# Распаковка
echo -e "${YELLOW}Распаковка файлов...${RES}"
unzip -o /tmp/easytier.zip -d $INSTALL_PATH/ > /dev/null
mv $INSTALL_PATH/easytier-linux-${ARCH}/* $INSTALL_PATH/
rm -rf $INSTALL_PATH/easytier-linux-${ARCH}/ /tmp/easytier.zip
chmod +x $INSTALL_PATH/easytier-core $INSTALL_PATH/easytier-cli

# Создание символьных ссылок
ln -sf $INSTALL_PATH/easytier-core $EASYTIER_BIN
ln -sf $INSTALL_PATH/easytier-cli $(dirname $EASYTIER_BIN)/easytier-cli

echo -e "${GREEN}=====================================================${RES}"
echo -e "${GREEN} Установка EasyTier $TARGET_VERSION успешно завершена!${RES}"
echo -e "${GREEN}=====================================================${RES}"
echo -e "Программа установлена в: ${BLUE}$INSTALL_PATH${RES}"
echo -e ""
echo -e "${YELLOW}ВАЖНО: Служба пока НЕ ЗАПУЩЕНА и НЕ СОЗДАНА.${RES}"
echo -e "Чтобы подключиться к сети, откройте файл ${GREEN}connect.sh${RES},"
echo -e "впишите в него ваши данные и запустите: ${GREEN}sudo bash connect.sh${RES}"