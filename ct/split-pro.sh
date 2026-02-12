#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/johanngrobe/ProxmoxVED/add/splitpro/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: johanngrobe
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/oss-apps/split-pro

APP="Split-Pro"
var_tags="${var_tags:-finance;expense-sharing}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-6}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

variables
color 
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/split-pro ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  RELEASE=$(curl -s https://api.github.com/repos/oss-apps/split-pro/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3)}')
  CURRENT_VERSION=$(cat /opt/split-pro_version.txt 2>/dev/null || echo "unknown")

  if [[ "${RELEASE}" != "${CURRENT_VERSION}" ]]; then
    msg_info "Updating from ${CURRENT_VERSION} to ${RELEASE}"

    msg_info "Stopping Service"
    systemctl stop split-pro
    msg_ok "Stopped Service"

    msg_info "Backing up Data"
    cp /opt/split-pro/.env /tmp/split-pro_backup
    msg_ok "Backed up Data"

    msg_info "Downloading Update"
    rm -rf /opt/split-pro
    mkdir -p /opt/split-pro
    $STD git clone --depth 1 --branch ${RELEASE} https://github.com/oss-apps/split-pro.git /opt/split-pro
    echo "${RELEASE}" >/opt/split-pro_version.txt
    msg_ok "Downloaded Update"

    msg_info "Building Application"
    cd /opt/split-pro
    $STD pnpm install --frozen-lockfile
    $STD pnpm build
    cp /tmp/split-pro_backup /opt/split-pro/.env
    rm -f /tmp/split-pro_backup
    ln -sf /opt/split-pro_data/uploads /opt/split-pro/uploads
    cd /opt/split-pro
    $STD pnpm exec prisma migrate deploy
    msg_ok "Built Application"

    msg_info "Starting Service"
    systemctl start split-pro
    msg_ok "Started Service"
    msg_ok "Updated to ${RELEASE} successfully!"
  else
    msg_ok "Already on latest version ${CURRENT_VERSION}"
  fi
  exit
}

start
build_container
description
msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:3000${CL}"