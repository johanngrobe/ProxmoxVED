#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/johanngrobe/ProxmoxVED/add/splitpro/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: johanngrobe
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/oss-apps/split-pro

APP="SplitPro"
var_tags="${var_tags:-finance;expense-sharing}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-6}"
var_os="${var_os:-debian}"
var_unprivileged="${var_unprivileged:-1}"

variables
color 
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/splitpro ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if check_for_gh_release "splitpro" "oss-apps/split-pro"; then
    msg_info "Stopping Service"
    systemctl stop splitpro
    msg_ok "Stopped Service"

    msg_info "Backing up Data"
    cp /opt/splitpro/.env /tmp/splitpro_backup
    msg_ok "Backed up Data"

    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "splitpro" "oss-apps/split-pro" "tarball" "latest" "/opt/splitpro"

    msg_info "Building Application"
    cd /opt/splitpro
    $STD pnpm install --frozen-lockfile
    $STD pnpm build
    cp /tmp/splitpro_backup /opt/splitpro/.env
    rm -f /tmp/splitpro_backup
    ln -sf /opt/splitpro_data/uploads /opt/splitpro/uploads
    cd /opt/splitpro
    $STD pnpm exec prisma migrate deploy
    msg_ok "Built Application"

    msg_info "Starting Service"
    systemctl start splitpro
    msg_ok "Started Service"
    msg_ok "Updated successfully!"
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