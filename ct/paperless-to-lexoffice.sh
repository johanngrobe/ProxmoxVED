#!/usr/bin/env bash

source <(curl -fsSL https://raw.githubusercontent.com/johanngrobe/ProxmoxVED/refs/heads/dev/paperless-to-lexoffice/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: johanngrobe
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/stefanlachner/paperless-to-lexoffice

APP="paperless-to-lexoffice"
var_tags="${var_tags:-business;sync}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/paperless-to-lexoffice ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Stopping ${APP}"
  systemctl stop paperless-to-lexoffice
  msg_ok "Stopped ${APP}"

  msg_info "Updating ${APP}"
  cd /opt/paperless-to-lexoffice
  $STD git pull
  $STD uv pip install -r source/requirements.txt
  msg_ok "Updated ${APP}"

  msg_info "Starting ${APP}"
  systemctl start paperless-to-lexoffice
  msg_ok "Started ${APP}"

  msg_ok "Updated Successfully!"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Configure the service by editing:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}/opt/paperless-to-lexoffice/.env${CL}"