#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: johanngrobe
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/oss-apps/split-pro

# Import Functions und Setup
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# Installing Dependencies
msg_info "Installing Dependencies"
$STD apt install -y \
    git \
    curl \
    unzip \
    build-essential
msg_ok "Installed Dependencies"

NODE_VERSION="22" NODE_MODULE="pnpm@latest" setup_nodejs
PG_VERSION="16" PG_MODULES="pg_cron" setup_postgresql
PG_DB_NAME="splitpro-db" PG_DB_USER="split-pro" setup_postgresql_db

fetch_and_deploy_gh_release "split-pro" "oss-apps/split-pro"

msg_info "Setting up Split Pro"
rm -rf /opt/split-pro/{docker,example.env}
NEXTAUTH_SECRET=$(openssl rand -base64 32 | tr -d '\n')
cat <<EOF >/opt/split-pro/.env
# When adding additional environment variables, the schema in "/src/env.js"
# should be updated accordingly.

#********* REQUIRED ENV VARS *********

# These variables are also used by docker compose in compose.yml to name the container
# and initialise postgres with default username, password. Use your own values when deploying to production.
POSTGRES_USER="${PG_DB_USER}"
POSTGRES_PASSWORD="${PG_DB_PASS}"
POSTGRES_DB="${PG_DB_NAME}"
POSTGRES_PORT=5432
DATABASE_URL="postgresql://${PG_DB_USER}:${PG_DB_PASS}@localhost:5432/${PG_DB_NAME}"

# Next Auth
# You should generate a new secret on the command line with:
# openssl rand -base64 32
# https://next-auth.js.org/configuration/options#secret
NEXTAUTH_SECRET="${NEXTAUTH_SECRET}"
NEXTAUTH_URL="http://localhost:3000"

# The default /home page is a blog page that may not be suitable for your use case.
# You can change it to /balances or any other URL you want.
# Note that it creates a permanent redirect, so changing it later will require a cache clear from users.
DEFAULT_HOMEPAGE="/home"

# If provided, server-side calls will use this instead of NEXTAUTH_URL.
# Useful in environments when the server doesn't have access to the canonical URL
# of your site.
# NEXTAUTH_URL_INTERNAL="http://localhost:3000"


# Enable sending invites
ENABLE_SENDING_INVITES=false

# Disable email signup (magic link/OTP login) for new users
DISABLE_EMAIL_SIGNUP=false
#********* END OF REQUIRED ENV VARS *********


#********* OPTIONAL ENV VARS *********
# SMTP options
FROM_EMAIL=
EMAIL_SERVER_HOST=
EMAIL_SERVER_PORT=
EMAIL_SERVER_USER=
EMAIL_SERVER_PASSWORD=

# GoCardless options
GOCARDLESS_COUNTRY=
GOCARDLESS_SECRET_ID=
GOCARDLESS_SECRET_KEY=
# Bank Transactions will be fetched from today and 30 days back as default.
GOCARDLESS_INTERVAL_IN_DAYS=

# Plaid options
PLAID_CLIENT_ID=
PLAID_SECRET=
# sandbox/development/production
PLAID_ENVIRONMENT=
# https://plaid.com/docs/institutions/
PLAID_COUNTRY_CODES=
# Bank Transactions will be fetched from today and 30 days back as default.
PLAID_INTERVAL_IN_DAYS=

# Cron-job options
CLEAR_BANK_CACHE_FREQUENCY=

# Google Provider : https://next-auth.js.org/providers/google
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=

# Authentic Providder : https://next-auth.js.org/providers/authentik
# Issuer: should include the slug without a trailing slash – e.g., https://my-authentik-domain.com/application/o/splitpro
AUTHENTIK_ID=
AUTHENTIK_SECRET=
AUTHENTIK_ISSUER=

# Keycloak Providder : https://next-auth.js.org/providers/keycloak
# Issuer: should include the realm – e.g. https://my-keycloak-domain.com/realms/My_Realm
KEYCLOAK_ID=
KEYCLOAK_SECRET=
KEYCLOAK_ISSUER=

# OIDC Provider
# The (lowercase) name will be used to generate an id and possibly display an icon if it is added in https://github.com/oss-apps/split-pro/blob/main/src/pages/auth/signin.tsx#L25
# If your provider is not added, simpleicon probably has it and you may submit a PR
OIDC_NAME=
OIDC_CLIENT_ID=
OIDC_CLIENT_SECRET=

# An OIDC Well-Known URI registry: https://openid.net/specs/openid-connect-discovery-1_0.html#WellKnownRegistry
# For example, https://example.com/.well-known/openid-configuration
OIDC_WELL_KNOWN_URL=

# Required for some providers to link with existing accounts, make sure you trust your provider to properly verify email addresses
# OIDC_ALLOW_DANGEROUS_EMAIL_LINKING=1

# Storage: any S3 compatible storage will work, for self hosting can use minio
# If you're using minio for dev, you can generate access keys from the console http://localhost:9001/access-keys/new-account
# R2_ACCESS_KEY="access-key"
# R2_SECRET_KEY="secret-key"
# R2_BUCKET="splitpro"
# R2_URL="http://localhost:9002"
# R2_PUBLIC_URL="http://localhost:9002/splitpro"

# Push notification, Web Push: https://www.npmjs.com/package/web-push
# generate web push keys using this command: npx web-push generate-vapid-keys --json
# or use the online tool: https://vapidkeys.com/
WEB_PUSH_PRIVATE_KEY=
WEB_PUSH_PUBLIC_KEY=
WEB_PUSH_EMAIL=

# Email options
FEEDBACK_EMAIL=

# Discord webhook for error notifications
DISCORD_WEBHOOK_URL=

# Currency rate provider, currently supported: 'frankfurter' (default), 'openexchangerates' and 'nbp'. See Readme for details.
CURRENCY_RATE_PROVIDER=frankfurter

# Open Exchange Rates App ID
OPEN_EXCHANGE_RATES_APP_ID=
#********* END OF OPTIONAL ENV VARS *********
EOF
msg_ok "Setup Split Pro"

msg_info "Installing Split Pro"
cd /opt/split-pro
$STD pnpm install
$STD pnpm prisma migrate deploy
$STD pnpm prisma generate
$STD pnpm build
msg_ok "Installed Split Pro"

# Creating Service (if needed)
msg_info "Creating Split Pro Service"
cat <<EOF >/etc/systemd/system/split-pro.service
[Unit]
Description=Split Pro Service
After=network.target postgresql.service

[Service]
WorkingDirectory=/opt/split-pro
EnvironmentFile=/opt/split-pro/.env
ExecStart=/usr/bin/node ./.next/standalone/server.js
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now split-pro
msg_ok "Created Split Pro Service"

motd_ssh
customize

# Cleanup
msg_info "Cleaning up"
rm -f "${RELEASE}".zip
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
