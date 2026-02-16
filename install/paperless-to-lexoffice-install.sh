#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: vhsdream
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/stefanlachner/paperless-to-lexoffice

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

setup_uv

msg_info "Deploying Paperless-to-Lexoffice"
cd /opt
$STD git clone https://github.com/stefanlachner/paperless-to-lexoffice
msg_ok "Deployed Paperless-to-Lexoffice"

msg_info "Building Paperless-to-Lexoffice"
cd /opt/paperless-to-lexoffice/source
$STD uv pip install -r requirements.txt
msg_ok "Built Paperless-to-Lexoffice"

msg_info "Configuring Paperless-to-Lexoffice"
cat <<EOF >/opt/paperless-to-lexoffice/.env
# Polling interval

PL2LO_POLLING_INTERVAL_S=60

# Settings for paperless-ngx

PL2LO_PAPERLESS_TOKEN="TOKEN" # Enter your paperless-ngx token here
PL2LO_PAPERLESS_URL="http://192.168.0.5:8000" # Change this to your paperless-ngx URL
PL2LO_INBOX_TAG_ID=1 # Change this to your inbox Tag ID
PL2LO_LEXOFFICE_TAG_ID=42 # Change this to your lexoffice Tag ID

# Settings for lexoffice
# Caution: Only works with lexoffice plans that include the public API unfortunately

PL2LO_LEXOFFICE_TOKEN="TOKEN" # Enter your lexoffice API token here
PL2LO_LEXOFFICE_URL="https://api.lexware.io/v1/files"
EOF
msg_ok "Configured Paperless-to-Lexoffice"

msg_info "Creating Paperless-to-Lexoffice Service"
cat <<EOF >/etc/systemd/system/paperless-to-lexoffice.service
[Unit]
Description=Paperless-to-Lexoffice Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/paperless-to-lexoffice/source
EnvironmentFile=/opt/paperless-to-lexoffice/.env
ExecStart=/usr/bin/python3 paperless-search.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
$STD systemctl enable -q --now paperless-to-lexoffice
msg_ok "Created Paperless-to-Lexoffice Service"

motd_ssh
customize
cleanup_lxc
