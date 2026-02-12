#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: johanngrobe
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/oss-apps/split-pro

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y \
  openssl
msg_ok "Installed Dependencies"

NODE_VERSION="22" NODE_MODULE="pnpm" setup_nodejs()
PG_VERSION="17" PG_MODULES="cron" setup_postgresql()

msg_info "Installing pg_cron Extension"
sudo -u postgres psql -c "ALTER SYSTEM SET cron.database_name = 'postgres'"
sudo -u postgres psql -c "ALTER SYSTEM SET cron.timezone = 'UTC'"
systemctl restart postgresql
sudo -u postgres psql -c "CREATE EXTENSION IF NOT EXISTS pg_cron"
msg_ok "Installed pg_cron Extension"

PG_DB_NAME="splitpro" PG_DB_USER="splitpro" setup_postgresql_db

get_lxc_ip
fetch_and_deploy_gh_release "split-pro" "oss-apps/split-pro" "tarball" "latest" "/opt/splitpro"

msg_info "Installing Dependencies"
cd /opt/splitpro
$STD pnpm install --frozen-lockfile
msg_ok "Installed Dependencies"

msg_info "Building Application"
cd /opt/splitpro
$STD pnpm build
msg_ok "Built Application"

msg_info "Configuring SplitPro"
cd /opt/splitpro
mkdir -p /opt/splitpro_data/uploads
ln -sf /opt/splitpro_data/uploads /opt/splitpro/uploads
NEXTAUTH_SECRET=$(openssl rand -base64 32)
cat <<EOF >/opt/splitpro/.env
DATABASE_URL=postgresql://${PG_DB_USER}:${PG_DB_PASS}@localhost:5432/${PG_DB_NAME}
NEXTAUTH_SECRET=${NEXTAUTH_SECRET}
NEXTAUTH_URL=http://${LOCAL_IP}:3000
DEFAULT_HOMEPAGE=/home
CLEAR_CACHE_CRON_RULE=0 2 * * 0
CACHE_RETENTION_INTERVAL=2 days
EOF
cd /opt/splitpro
$STD pnpm exec prisma migrate deploy
msg_ok "Configured SplitPro"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/splitpro.service
[Unit]
Description=SplitPro
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/splitpro
EnvironmentFile=/opt/splitpro/.env
ExecStart=/usr/bin/node /opt/splitpro/.next/standalone/server.js
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now splitpro
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc