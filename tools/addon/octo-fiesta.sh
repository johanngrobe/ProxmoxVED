#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: V1ck3s
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/V1ck3s/octo-fiesta

source <(curl -fsSL https://raw.githubusercontent.com/johanngrobe/ProxmoxVED/add/octo-fiesta/misc/core.func)
source <(curl -fsSL https://raw.githubusercontent.com/johanngrobe/ProxmoxVED/add/octo-fiesta/misc/tools.func)
source <(curl -fsSL https://raw.githubusercontent.com/johanngrobe/ProxmoxVED/add/octo-fiesta/misc/error_handler.func)

set -Eeuo pipefail
trap 'error_handler' ERR

APP="Octo-Fiesta"
APP_TYPE="addon"
INSTALL_PATH="/opt/octo-fiesta"
CONFIG_PATH="/opt/octo-fiesta/appsettings.json"
DEFAULT_PORT=5274

load_functions

function header_info {
  clear
  cat <<"EOF"
   ____       __          _______________        __
  / __ \____ / /____     / ____(_)__  / /_____ _/ /___ _
 / / / / __ `/ __/ _ \  / /_  / / /_/ / / ___/ __ `/ __ `/
/ /_/ / /_/ / /_/ /_/ / / __/ / / __/ /  (__  ) /_/ / /_/ /
\____/\__,_/\__/\____/ /_/  /_/_/  /_/____/\__,_/\__,_/

EOF
}

if [[ -f "/etc/alpine-release" ]]; then
  msg_error "Alpine is not supported for ${APP}. Use Debian/Ubuntu."
  exit 1
elif [[ -f "/etc/debian_version" ]]; then
  OS="Debian"
  SERVICE_PATH="/etc/systemd/system/octo-fiesta.service"
else
  echo -e "${CROSS} Unsupported OS detected. Exiting."
  exit 1
fi

function uninstall() {
  msg_info "Uninstalling ${APP}"
  systemctl disable --now octo-fiesta.service || true
  rm -f "$SERVICE_PATH"
  rm -rf "$INSTALL_PATH"
  rm -f "/usr/local/bin/update_octo_fiesta"
  rm -f "$HOME/.octo-fiesta"
  msg_ok "${APP} has been uninstalled"
  msg_info "Removing .NET SDK"
  $STD apt-get remove -y dotnet-sdk-9.0
  $STD apt-get autoremove -y
  rm -f /tmp/packages-microsoft-prod.deb
  msg_ok "Removed .NET SDK"

}

function update() {
  if check_for_gh_release "octo-fiesta" "V1ck3s/octo-fiesta"; then
    msg_info "Stopping service"
    systemctl stop octo-fiesta.service || true
    msg_ok "Stopped service"

    msg_info "Backing up configuration"
    cp "$CONFIG_PATH" /tmp/octo-fiesta.appsettings.bak
    msg_ok "Backed up configuration"

    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "octo-fiesta" "V1ck3s/octo-fiesta" "tarball" "latest" "$INSTALL_PATH"

    msg_info "Restoring configuration"
    cp /tmp/octo-fiesta.appsettings.bak "$CONFIG_PATH"
    rm -f /tmp/octo-fiesta.appsettings.bak
    msg_ok "Restored configuration"

    msg_info "Restoring dependencies"
    cd "$INSTALL_PATH"
    $STD dotnet restore
    msg_ok "Restored dependencies"

    msg_info "Building ${APP}"
    $STD dotnet build
    msg_ok "Built ${APP}"

    msg_info "Starting service"
    systemctl start octo-fiesta
    msg_ok "Started service"
    msg_ok "Updated successfully"
    exit
  fi
}

function install() {
  if command -v dotnet > /dev/null 2>&1 && dotnet --list-sdks 2>/dev/null | grep -q "^9\."; then
    msg_ok ".NET 9 SDK already installed ($(dotnet --version))"
  else
    msg_info "Installing .NET 9 SDK"

    $STD wget https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb
    $STD dpkg -i /tmp/packages-microsoft-prod.deb
    rm -f /tmp/packages-microsoft-prod.deb

    $STD apt-get update
    $STD apt-get install -y dotnet-sdk-9.0

    msg_ok "Installed .NET 9 SDK"
  fi

  rm -f "$HOME/.octo-fiesta"
  fetch_and_deploy_gh_release "octo-fiesta" "V1ck3s/octo-fiesta" "tarball" "latest" "$INSTALL_PATH"

  msg_info "Restoring dependencies"
  cd "$INSTALL_PATH"
  $STD dotnet restore
  msg_ok "Restored dependencies"

  msg_info "Building ${APP}"
  $STD dotnet build
  msg_ok "Built ${APP}"

  msg_info "Creating configuration"

  mkdir -p "$INSTALL_PATH/downloads"

  cat <<EOF >"$CONFIG_PATH"
{
  "Subsonic": {
    "Url": "http://localhost:4533",
    "MusicService": "SquidWTF",
    "AutoUpgradeQuality": false,
    "EnableExternalPlaylists": true,
    "PlaylistsDirectory": "playlists"
  },
  "Library": {
    "DownloadPath": "./downloads"
  },
  "Qobuz": {
    "UserAuthToken": "your-qobuz-token",
    "UserId": "your-qobuz-user-id",
    "Quality": "FLAC"
  },
  "Deezer": {
    "Arl": "your-deezer-arl-token",
    "ArlFallback": "",
    "Quality": "FLAC"
  },
  "SquidWTF": {
    "Source": "Qobuz",
    "Quality": "auto",
    "InstanceTimeoutSeconds": 5
  }
}
EOF
  chmod 600 "$CONFIG_PATH"
  msg_ok "Created configuration"

  msg_info "Creating service"
  cat <<EOF >"$SERVICE_PATH"
[Unit]
Description=Octo-Fiesta Subsonic Proxy
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_PATH}
ExecStart=/usr/bin/dotnet run
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
  systemctl enable --now octo-fiesta
  msg_ok "Created and started service"

  msg_info "Creating update script"
  cat <<'UPDATEEOF' >/usr/local/bin/update_octo_fiesta
type=update bash -c "$(curl -fsSL https://raw.githubusercontent.com/johanngrobe/ProxmoxVED/add/octo-fiesta/tools/addon/octo-fiesta.sh)"
UPDATEEOF
  chmod +x /usr/local/bin/update_octo_fiesta
  msg_ok "Created update script (/usr/local/bin/update_octo_fiesta)"

  echo ""
  msg_ok "${APP} is reachable at: ${BL}http://${LOCAL_IP}:${DEFAULT_PORT}${CL}"
}


if [[ "${type:-}" == "update" ]]; then
  header_info
  if [[ -d "$INSTALL_PATH" && -f "$CONFIG_PATH" ]]; then
    update
  else
    msg_error "${APP} is not installed. Nothing to update."
    exit 1
  fi
  exit 0
fi

header_info
get_lxc_ip

if [[ -d "$INSTALL_PATH" && -f "$CONFIG_PATH" ]]; then
  msg_warn "${APP} is already installed."
  echo ""

  echo -n "${TAB}Uninstall ${APP}? (y/N): "
  read -r uninstall_prompt
  if [[ "${uninstall_prompt,,}" =~ ^(y|yes)$ ]]; then
    uninstall
    exit 0
  fi

  echo -n "${TAB}Update ${APP}? (y/N): "
  read -r update_prompt
  if [[ "${update_prompt,,}" =~ ^(y|yes)$ ]]; then
    update
    exit 0
  fi

  msg_warn "No action selected. Exiting."
  exit 0
fi

msg_warn "${APP} is not installed."
echo ""
echo -e "${TAB}${INFO} This will install:"
echo -e "${TAB}  - .NET 9 SDK"
echo -e "${TAB}  - Octo-Fiesta Subsonic Proxy"
echo ""

echo -n "${TAB}Install ${APP}? (y/N): "
read -r install_prompt
if [[ "${install_prompt,,}" =~ ^(y|yes)$ ]]; then
  install
else
  msg_warn "Installation cancelled. Exiting."
  exit 0
fi