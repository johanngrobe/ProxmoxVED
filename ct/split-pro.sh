#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: johanngrobe
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/oss-apps/split-pro

# App Default Values
# Name of the app (e.g. Google, Adventurelog, Apache-Guacamole"
APP="Split Pro"
# Tags for Proxmox VE, maximum 2 pcs., no spaces allowed, separated by a semicolon ; (e.g. database | adblock;dhcp)
var_tags="${var_tags:-finance;friends}"
# Number of cores (1-X) (e.g. 4) - default are 2
var_cpu="${var_cpu:-1}"
# Amount of used RAM in MB (e.g. 2048 or 4096)
var_ram="${var_ram:-2048}"
# Amount of used disk space in GB (e.g. 4 or 10)
var_disk="${var_disk:-4}"
# Default OS (e.g. debian, ubuntu, alpine)
var_os="${var_os:-debian}"
# Default OS version (e.g. 12 for debian, 24.04 for ubuntu, 3.20 for alpine)
var_version="${var_version:-13}"
# 1 = unprivileged container, 0 = privileged container
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  # Check if installation is present | -f for file, -d for folder
  if [[ ! -f /opt/split-pro ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  # Crawling the new version and checking whether an update is required
  RELEASE=$(curl -fsSL https://api.github.com/repos/oss-apps/split-pro/releases/latest \
     | grep "tag_name" | cut -d '"' -f 4)
  if [[ "${RELEASE}" != "$(cat /opt/${APP}_version.txt)" ]] || [[ ! -f /opt/${APP}_version.txt ]]; then
    # Stopping Services
    msg_info "Stopping $APP"
    systemctl stop split-pro
    msg_ok "Stopped $APP"

    # Creating Backup
    msg_info "Creating Backup"
    cp /opt/split-pro/.env /opt/env.backup
    msg_ok "Backup Created"

    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "split-pro" "oss-apps/split-pro"

    # Execute Update
    msg_info "Updating $APP to v${RELEASE}"
    $STD pnpm install
    $STD pnpm prisma migrate deploy
    $STD pnpm prisma generate
    $STD pnpm build
    cp /opt/env.backup /opt/split-pro/.env
    msg_ok "Updated $APP to v${RELEASE}"

    # Starting Services
    msg_info "Starting $APP"
    systemctl start split-pro
    msg_ok "Started $APP"

    # Cleaning up
    msg_info "Cleaning Up"
    rm -rf /opt/split-pro/{docker,example.env}
    msg_ok "Cleanup Completed"

    # Last Action
    echo "${RELEASE}" >/opt/${APP}_version.txt
    msg_ok "Update Successful"
  else
    msg_ok "No update required. ${APP} is already at v${RELEASE}"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:3000${CL}"
