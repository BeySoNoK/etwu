#!/bin/bash

# ==================== НАСТРОЙКИ (измените при необходимости) ====================
VPN_NETWORK_NAME="BeySoN-VPN"
VPN_NETWORK_SECRET="Asdf-1234"
VPN_SERVER="tcp://183.230.36.171:11010"
EASYTIER_BIN="/usr/local/bin/easytier-core"
SERVICE_NAME="easytier"
# ==============================================================================

# Цвета для оформления вывода
RED_COLOR='\e[1;31m'
GREEN_COLOR='\e[1;32m'
YELLOW_COLOR='\e[1;33m'
BLUE_COLOR='\e[1;34m'
PINK_COLOR='\e[1;35m'
SHAN='\e[1;33;5m'
RES='\e[0m'

# Функция вывода справки
HELP() {
  echo -e "\r\n${GREEN_COLOR}Справка по установке EasyTier${RES}\r\n"
  echo "Использование: ./install.sh [команда] [параметры]"
  echo
  echo "Команды:"
  echo "  install    Установить EasyTier"
  echo "  uninstall  Удалить EasyTier"
  echo "  update     Обновить EasyTier до последней версии"
  echo "  help       Показать эту справку"
  echo
  echo "Параметры:"
  echo "  --skip-folder-verify  Пропустить проверку на наличие EasyTier в папке установки"
  echo "  --skip-folder-fix     Отключить автоматическое добавление подпапки easytier к пути"
  echo "  --no-gh-proxy         Отключить прокси для GitHub"
  echo "  --gh-proxy URL        Задать свой прокси-сервер для GitHub"
  echo
  echo "Примеры:"
  echo "  ./install.sh install /opt/easytier"
  echo "  ./install.sh install --skip-folder-verify"
  echo "  ./install.sh install --no-gh-proxy"
  echo "  ./install.sh install --gh-proxy https://ваш-прокси.ру/"
  echo "  ./install.sh update"
  echo "  ./install.sh uninstall"
}

# Если аргументов нет или команда help – выводим справку
if [ $# -eq 0 ] || [ "$1" = "help" ]; then
  HELP
  exit 0
fi

# Настройки по умолчанию (можно переопределить через параметры)
SKIP_FOLDER_VERIFY=false
SKIP_FOLDER_FIX=false
NO_GH_PROXY=false
GH_PROXY='https://ghfast.top/'

COMMEND=$1
shift

# Определяем путь установки (если передан)
if [[ "$#" -ge 1 && ! "$1" == --* ]]; then
    INSTALL_PATH=$1
    shift
fi

# Разбираем остальные параметры
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --skip-folder-verify) SKIP_FOLDER_VERIFY=true ;;
        --skip-folder-fix) SKIP_FOLDER_FIX=true ;;
        --no-gh-proxy) NO_GH_PROXY=true ;;
        --gh-proxy) 
            if [ -n "$2" ]; then
                GH_PROXY=$2
                shift
            else
                echo "Ошибка: для --gh-proxy требуется указать URL"
                exit 1
            fi
            ;;
        *) echo "Неизвестный параметр: $1"; exit 1 ;;
    esac
    shift
done

# Если путь не задан, используем по умолчанию
if [ -z "$INSTALL_PATH" ]; then
    INSTALL_PATH='/opt/easytier'
fi

# Удаляем завершающий слеш, если есть
if [[ "$INSTALL_PATH" == */ ]]; then
    INSTALL_PATH=${INSTALL_PATH%?}
fi

# Если не отключена коррекция пути и путь не заканчивается на easytier – добавляем easytier
if ! $SKIP_FOLDER_FIX && ! [[ "$INSTALL_PATH" == */easytier ]]; then
    INSTALL_PATH="$INSTALL_PATH/easytier"
fi

echo "ПУТЬ УСТАНОВКИ: $INSTALL_PATH"
echo "ПРОПУСК КОРРЕКЦИИ ПУТИ: $SKIP_FOLDER_FIX"
echo "ПРОПУСК ПРОВЕРКИ ПАПКИ: $SKIP_FOLDER_VERIFY"

# Проверяем наличие unzip
if ! command -v unzip >/dev/null 2>&1; then
  echo -e "\r\n${RED_COLOR}Ошибка: unzip не установлен${RES}\r\n"
  exit 1
fi

# Проверяем наличие curl
if ! command -v curl >/dev/null 2>&1; then
  echo -e "\r\n${RED_COLOR}Ошибка: curl не установлен${RES}\r\n"
  exit 1
fi

echo -e "\r\n${RED_COLOR}----------------------ПРЕДУПРЕЖДЕНИЕ----------------------${RES}\r\n"
echo " Это временный скрипт для установки EasyTier"
echo " EasyTier требует выделенную пустую папку для установки"
echo " EasyTier — развивающийся продукт и может содержать ошибки"
echo " Для использования EasyTier нужны базовые навыки работы с Linux"
echo " Вы используете EasyTier на свой страх и риск"
echo -e "\r\n${RED_COLOR}--------------------------------------------------------------${RES}\r\n"

# Определяем архитектуру процессора
if command -v arch >/dev/null 2>&1; then
  platform=$(arch)
else
  platform=$(uname -m)
fi

case "$platform" in
  amd64 | x86_64)
    ARCH="x86_64"
    ;;
  arm64 | aarch64 | *armv8*)
    ARCH="aarch64"
    ;;
  *armv7*)
    ARCH="armv7"
    ;;
  *arm*)
    ARCH="arm"
    ;;
  mips)
    ARCH="mips"
    ;;
  mipsel)
    ARCH="mipsel"
    ;;
  *)
    ARCH="UNKNOWN"
    ;;
esac

# Поддержка hard-float для ARM
if [[ "$ARCH" == "armv7" || "$ARCH" == "arm" ]]; then
  if cat /proc/cpuinfo | grep Features | grep -i 'half' >/dev/null 2>&1; then
    ARCH=${ARCH}hf
  fi
fi

echo -e "\r\n${GREEN_COLOR}Ваша платформа: ${ARCH} (${platform}) ${RES}\r\n" 1>&2

# Проверка прав root
if [ "$(id -u)" != "0" ]; then
  echo -e "\r\n${RED_COLOR}Этот скрипт должен запускаться от root !${RES}\r\n" 1>&2
  exit 1
elif [ "$ARCH" == "UNKNOWN" ]; then
  echo -e "\r\n${RED_COLOR}Упс${RES}, этот скрипт не поддерживает вашу платформу\r\nПопробуйте ${GREEN_COLOR}установить вручную${RES}\r\n"
  exit 1
fi

# Определяем систему инициализации
if command -v systemctl >/dev/null 2>&1; then
  INIT_SYSTEM="systemd"
elif command -v rc-update >/dev/null 2>&1; then
  INIT_SYSTEM="openrc"
else
  echo -e "\r\n${RED_COLOR}Ошибка: Неподдерживаемая система инициализации (не найдены systemd и OpenRC)${RES}\r\n"
  exit 1
fi

# Функция проверки папки установки
CHECK() {
  if ! $SKIP_FOLDER_VERIFY; then
    if [ -f "$INSTALL_PATH/easytier-core" ]; then
      echo "В $INSTALL_PATH уже есть EasyTier. Выберите другой путь или используйте команду \"update\""
      echo -e "Или используйте ${GREEN_COLOR}--skip-folder-verify${RES} для пропуска проверки"
      exit 0
    fi
  fi

  if [ ! -d "$INSTALL_PATH/" ]; then
    mkdir -p $INSTALL_PATH
  else
    # Проверка, пуста ли папка
    if ! $SKIP_FOLDER_VERIFY; then
      if [ -n "$(ls -A $INSTALL_PATH)" ]; then
        echo "EasyTier требует установки в пустую папку. Выберите пустой путь"
        echo -e "Или используйте ${GREEN_COLOR}--skip-folder-verify${RES} для пропуска проверки"
        echo -e "Текущий путь: $INSTALL_PATH (используйте ${GREEN_COLOR}--skip-folder-fix${RES}, чтобы отключить коррекцию пути)"
        exit 1
      fi
    fi
  fi
}

# Функция установки
INSTALL() {
  # Получаем номер последней версии
  RESPONSE=$(curl -s "https://api.github.com/repos/EasyTier/EasyTier/releases/latest")
  LATEST_VERSION=$(echo "$RESPONSE" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  LATEST_VERSION=$(echo -e "$LATEST_VERSION" | tr -d '[:space:]')

  if [ -z "$LATEST_VERSION" ]; then
    echo -e "\r\n${RED_COLOR}Упс${RES}, не удалось получить последнюю версию. Проверьте интернет-соединение\r\nИли попробуйте ${GREEN_COLOR}установить вручную${RES}\r\n"
    exit 1
  fi

  # Скачивание
  echo -e "\r\n${GREEN_COLOR}Скачиваем EasyTier $LATEST_VERSION ...${RES}"
  rm -rf /tmp/easytier_tmp_install.zip
  BASE_URL="https://github.com/EasyTier/EasyTier/releases/latest/download/easytier-linux-${ARCH}-${LATEST_VERSION}.zip"
  DOWNLOAD_URL=$($NO_GH_PROXY && echo "$BASE_URL" || echo "${GH_PROXY}${BASE_URL}")
  echo -e "Ссылка для скачивания: ${GREEN_COLOR}${DOWNLOAD_URL}${RES}"
  curl -L ${DOWNLOAD_URL} -o /tmp/easytier_tmp_install.zip $CURL_BAR

  # Распаковка
  echo -e "\r\n${GREEN_COLOR}Распаковываем архив ...${RES}"
  unzip -o /tmp/easytier_tmp_install.zip -d $INSTALL_PATH/
  mkdir $INSTALL_PATH/config
  mv $INSTALL_PATH/easytier-linux-${ARCH}/* $INSTALL_PATH/
  rm -rf $INSTALL_PATH/easytier-linux-${ARCH}/
  chmod +x $INSTALL_PATH/easytier-core $INSTALL_PATH/easytier-cli

  # Создаём символические ссылки на бинарники в соответствии с EASYTIER_BIN
  mkdir -p $(dirname $EASYTIER_BIN)
  ln -sf $INSTALL_PATH/easytier-core $EASYTIER_BIN
  ln -sf $INSTALL_PATH/easytier-cli $(dirname $EASYTIER_BIN)/easytier-cli

  if [ -f $INSTALL_PATH/easytier-core ] || [ -f $INSTALL_PATH/easytier-cli ]; then
    echo -e "${GREEN_COLOR} Скачивание прошло успешно! ${RES}"
  else
    echo -e "${RED_COLOR} Скачивание не удалось! ${RES}"
    exit 1
  fi
}

# Функция инициализации (создание конфига и службы)
INIT() {
  if [ ! -f "$INSTALL_PATH/easytier-core" ]; then
    echo -e "\r\n${RED_COLOR}Упс${RES}, не удалось найти EasyTier\r\n"
    exit 1
  fi

  # Создаём файл конфигурации с пользовательскими настройками
  cat >$INSTALL_PATH/config/default.conf <<EOF
instance_name = "default"
dhcp = true
listeners = [
    "tcp://0.0.0.0:11010",
    "udp://0.0.0.0:11010",
    "wg://0.0.0.0:11011",
    "ws://0.0.0.0:11011/",
    "wss://0.0.0.0:11012/",
]
exit_nodes = []
rpc_portal = "0.0.0.0:0"

[[peer]]
uri = "$VPN_SERVER"

[network_identity]
network_name = "$VPN_NETWORK_NAME"
network_secret = "$VPN_NETWORK_SECRET"

[flags]
default_protocol = "udp"
dev_name = ""
enable_encryption = true
enable_ipv6 = true
mtu = 1380
latency_first = false
enable_exit_node = false
no_tun = false
use_smoltcp = false
foreign_network_whitelist = "*"
disable_p2p = false
p2p_only = false
relay_all_peer_rpc = false
disable_tcp_hole_punching = false
disable_udp_hole_punching = false

EOF

  # Создаём скрипт инициализации для OpenRC с именем SERVICE_NAME
  if [ "$INIT_SYSTEM" = "openrc" ]; then
    cat >/etc/init.d/${SERVICE_NAME} <<EOF
#!/sbin/openrc-run

name="EasyTier"
description="EasyTier Service"
command="$INSTALL_PATH/easytier-core"
command_args="-c $INSTALL_PATH/config/default.conf"
command_user="nobody:nobody"
command_background=true

pidfile="/run/\${RC_SVCNAME}.pid"

depend() {
  need net
}


EOF
    chmod +x /etc/init.d/${SERVICE_NAME}
  fi

  # Создаём systemd-сервис с именем SERVICE_NAME
  if [ "$INIT_SYSTEM" = "systemd" ]; then
    cat >/etc/systemd/system/${SERVICE_NAME}@.service <<EOF
[Unit]
Description=EasyTier Service
Wants=network.target
After=network.target network.service
StartLimitIntervalSec=0

[Service]
Type=simple
WorkingDirectory=$INSTALL_PATH
ExecStart=$INSTALL_PATH/easytier-core -c $INSTALL_PATH/config/%i.conf
Restart=always
RestartSec=1s

[Install]
WantedBy=multi-user.target
EOF
  fi

  # Запускаем службу с именем SERVICE_NAME
  if [ "$INIT_SYSTEM" = "systemd" ]; then
    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME}@default >/dev/null 2>&1
    systemctl start ${SERVICE_NAME}@default
  else
    rc-update add $SERVICE_NAME default
    rc-service $SERVICE_NAME start
  fi

  # Удаляем возможные остатки от старых версий (если использовались стандартные имена)
  rm -rf /etc/systemd/system/easytier.service
  rm -rf /usr/bin/easytier-core
  rm -rf /usr/bin/easytier-cli

  # Ссылки уже созданы в INSTALL, но на всякий случай пересоздадим
  ln -sf $INSTALL_PATH/easytier-core $EASYTIER_BIN
  ln -sf $INSTALL_PATH/easytier-cli $(dirname $EASYTIER_BIN)/easytier-cli
}

# Функция вывода сообщения об успешной установке
SUCCESS() {
  clear
  echo " Установка EasyTier прошла успешно!"
  echo -e "\r\nПорт по умолчанию: ${GREEN_COLOR}11010(UDP+TCP)${RES}, не забудьте разрешить его в брандмауэре!\r\n"
  echo -e "Имя сети: ${GREEN_COLOR}$VPN_NETWORK_NAME${RES}"
  echo -e "Сервер: ${GREEN_COLOR}$VPN_SERVER${RES}"
  echo -e "Служба: ${GREEN_COLOR}$SERVICE_NAME${RES}\r\n"

  echo "Конфигурационный файл: ${GREEN_COLOR}$INSTALL_PATH/config/default.conf${RES}"
  echo -e "Для изменения настроек отредактируйте его и перезапустите службу.\r\n"

  echo "Управление службой:"
  if [ "$INIT_SYSTEM" = "systemd" ]; then
    echo -e "Статус: ${GREEN_COLOR}systemctl status ${SERVICE_NAME}@default${RES}"
    echo -e "Запуск: ${GREEN_COLOR}systemctl start ${SERVICE_NAME}@default${RES}"
    echo -e "Перезапуск: ${GREEN_COLOR}systemctl restart ${SERVICE_NAME}@default${RES}"
    echo -e "Остановка: ${GREEN_COLOR}systemctl stop ${SERVICE_NAME}@default${RES}"
  else
    echo -e "Статус: ${GREEN_COLOR}rc-service $SERVICE_NAME status${RES}"
    echo -e "Запуск: ${GREEN_COLOR}rc-service $SERVICE_NAME start${RES}"
    echo -e "Перезапуск: ${GREEN_COLOR}rc-service $SERVICE_NAME restart${RES}"
    echo -e "Остановка: ${GREEN_COLOR}rc-service $SERVICE_NAME stop${RES}"
  fi
  echo
}

# Функция удаления
UNINSTALL() {
  echo -e "\r\n${GREEN_COLOR}Удаление EasyTier ...${RES}\r\n"
  echo -e "${GREEN_COLOR}Останавливаем процесс ...${RES}"
  if [ "$INIT_SYSTEM" = "systemd" ]; then
    systemctl disable "${SERVICE_NAME}@*" >/dev/null 2>&1
    systemctl stop "${SERVICE_NAME}@*" >/dev/null 2>&1
  else
    rc-update del $SERVICE_NAME
    rc-service $SERVICE_NAME stop
  fi
  echo -e "${GREEN_COLOR}Удаляем файлы ...${RES}"
  if [ "$INIT_SYSTEM" = "systemd" ]; then
    rm -rf $INSTALL_PATH /etc/systemd/system/${SERVICE_NAME}@.service /usr/bin/easytier-core /usr/bin/easytier-cli /etc/systemd/system/easytier@.service /usr/sbin/easytier-core /usr/sbin/easytier-cli
    # Удаляем симлинки из EASYTIER_BIN
    rm -f $EASYTIER_BIN $(dirname $EASYTIER_BIN)/easytier-cli
    systemctl daemon-reload
  else
    rm -rf $INSTALL_PATH /etc/init.d/$SERVICE_NAME /usr/bin/easytier-core /usr/bin/easytier-cli /usr/sbin/easytier-core /usr/sbin/easytier-cli
    rm -f $EASYTIER_BIN $(dirname $EASYTIER_BIN)/easytier-cli
  fi
  echo -e "\r\n${GREEN_COLOR}EasyTier успешно удалён! ${RES}\r\n"
}

# Функция обновления – с учётом нового имени службы
UPDATE() {
  if [ ! -f "$INSTALL_PATH/easytier-core" ]; then
    echo -e "\r\n${RED_COLOR}Ошибка${RES}: EasyTier не найден в $INSTALL_PATH. Невозможно обновить.\r\n"
    exit 1
  fi

  # 1. Получаем информацию о последней версии
  echo -e "${GREEN_COLOR}Проверяем наличие последней версии...${RES}"
  RESPONSE=$(curl -s "https://api.github.com/repos/EasyTier/EasyTier/releases/latest")
  LATEST_VERSION=$(echo "$RESPONSE" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  LATEST_VERSION=$(echo -e "$LATEST_VERSION" | tr -d '[:space:]')

  if [ -z "$LATEST_VERSION" ]; then
    echo -e "\r\n${RED_COLOR}Ошибка${RES}: Не удалось получить последнюю версию. Проверьте интернет-соединение.\r\n"
    exit 1
  fi

  echo -e "Найдена последняя версия: ${GREEN_COLOR}$LATEST_VERSION${RES}"

  # 2. Скачиваем и распаковываем новую версию во временную папку
  TEMP_UPDATE_DIR=$(mktemp -d /tmp/easytier_update_XXXXXX)
  echo -e "${GREEN_COLOR}Скачиваем новую версию во временную папку: $TEMP_UPDATE_DIR${RES}"
  
  BASE_URL="https://github.com/EasyTier/EasyTier/releases/latest/download/easytier-linux-${ARCH}-${LATEST_VERSION}.zip"
  DOWNLOAD_URL=$($NO_GH_PROXY && echo "$BASE_URL" || echo "${GH_PROXY}${BASE_URL}")
  
  echo -e "Ссылка для скачивания: ${GREEN_COLOR}${DOWNLOAD_URL}${RES}"
  curl -L ${DOWNLOAD_URL} -o "$TEMP_UPDATE_DIR/easytier.zip" $CURL_BAR
  if [ $? -ne 0 ]; then
      echo -e "${RED_COLOR}Скачивание не удалось!${RES}"
      rm -rf "$TEMP_UPDATE_DIR"
      exit 1
  fi
  
  unzip -o "$TEMP_UPDATE_DIR/easytier.zip" -d "$TEMP_UPDATE_DIR/"
  
  NEW_CORE_FILE="$TEMP_UPDATE_DIR/easytier-linux-${ARCH}/easytier-core"
  if [ ! -f "$NEW_CORE_FILE" ]; then
      echo -e "${RED_COLOR}Распаковка не удалась или архив повреждён.${RES}"
      rm -rf "$TEMP_UPDATE_DIR"
      exit 1
  fi
  
  echo -e "${GREEN_COLOR}Новая версия подготовлена. Начинаем процесс обновления...${RES}"
  
  # 3. Останавливаем службу (запоминаем активные экземпляры)
  ACTIVE_SERVICES=()
  if [ "$INIT_SYSTEM" = "systemd" ]; then
    mapfile -t ACTIVE_SERVICES < <(systemctl list-units --type=service --state=active | grep "${SERVICE_NAME}@" | awk '{print $1}')
    if [ ${#ACTIVE_SERVICES[@]} -gt 0 ]; then
        echo -e "\r\n${YELLOW_COLOR}Найдены работающие службы: ${ACTIVE_SERVICES[*]}${RES}"
        echo -e "${YELLOW_COLOR}Останавливаем службы EasyTier...${RES}"
        systemctl stop "${ACTIVE_SERVICES[@]}"
    else
        echo -e "\r\n${YELLOW_COLOR}Не найдено работающих служб EasyTier. Останавливать нечего.${RES}"
    fi
  else
    echo -e "\r\n${YELLOW_COLOR}Останавливаем службу EasyTier...${RES}"
    rc-service $SERVICE_NAME stop
  fi

  # Резервируем конфигурацию
  echo "Создаём резервную копию конфигурации..."
  BACKUP_CONFIG_DIR=$(mktemp -d /tmp/easytier_config_backup_XXXXXX)
  if [ -d "$INSTALL_PATH/config" ]; then
      cp -a "$INSTALL_PATH/config" "$BACKUP_CONFIG_DIR/"
  fi
  
  echo "Заменяем файлы..."
  rm -f "$INSTALL_PATH/easytier-core" "$INSTALL_PATH/easytier-cli" "$INSTALL_PATH/LICENSE" "$INSTALL_PATH/README.md"
  
  mv "$TEMP_UPDATE_DIR/easytier-linux-${ARCH}"/* "$INSTALL_PATH/"
  chmod +x "$INSTALL_PATH/easytier-core" "$INSTALL_PATH/easytier-cli"

  # Восстанавливаем конфиг (чтобы не перезаписать пользовательские настройки)
  if [ -d "$BACKUP_CONFIG_DIR/config" ]; then
      cp -af "$BACKUP_CONFIG_DIR/config/." "$INSTALL_PATH/config/"
  fi

  # Обновляем симлинки
  ln -sf $INSTALL_PATH/easytier-core $EASYTIER_BIN
  ln -sf $INSTALL_PATH/easytier-cli $(dirname $EASYTIER_BIN)/easytier-cli
  
  # 4. Запускаем службы
  if [ "$INIT_SYSTEM" = "systemd" ]; then
    if [ ${#ACTIVE_SERVICES[@]} -gt 0 ]; then
        echo -e "${GREEN_COLOR}Запускаем новую версию служб EasyTier: ${ACTIVE_SERVICES[*]}${RES}"
        systemctl start "${ACTIVE_SERVICES[@]}"
    else
        echo -e "${GREEN_COLOR}До обновления не было запущенных служб. Обновление завершено.${RES}"
    fi
  else
    echo -e "${GREEN_COLOR}Запускаем новую версию службы EasyTier...${RES}"
    rc-service $SERVICE_NAME start
  fi
  
  # 5. Удаляем временные файлы
  echo "Очищаем временные файлы..."
  rm -rf "$TEMP_UPDATE_DIR"
  rm -rf "$BACKUP_CONFIG_DIR"
  
  echo -e "\r\n${GREEN_COLOR}EasyTier успешно обновлён до версии $LATEST_VERSION!${RES}\r\n"
}

# Определяем, поддерживает ли curl отображение прогресс-бара
if curl --help | grep progress-bar >/dev/null 2>&1; then
  CURL_BAR="--progress-bar"
fi

# Временная папка /tmp должна существовать
if [ ! -d "/tmp" ]; then
  mkdir -p /tmp
fi

echo $COMMEND

# Выполняем выбранную команду
if [ "$COMMEND" = "uninstall" ]; then
  UNINSTALL
elif [ "$COMMEND" = "update" ]; then
  UPDATE
elif [ "$COMMEND" = "install" ]; then
  CHECK
  INSTALL
  INIT
  if [ -f "$INSTALL_PATH/easytier-core" ]; then
    SUCCESS
  else
    echo -e "${RED_COLOR} Установка не удалась, попробуйте установить вручную${RES}"
  fi
else
  echo -e "${RED_COLOR} Неизвестная команда ${RES}\n\r"
  echo " Допустимые команды:"
  echo -e "\n\r${GREEN_COLOR} install, uninstall, update, help ${RES}"
fi

# Удаляем временные файлы, если остались
rm -rf /tmp/easytier_tmp_*