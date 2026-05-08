#!/usr/bin/env bash

set -e

ENV_FILE=".env"

echo "🔐 Generating .env file..."

# Backup existing .env if it exists
if [ -f "$ENV_FILE" ]; then
  TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
  BACKUP_FILE="${ENV_FILE}.backup-${TIMESTAMP}"

  cp "$ENV_FILE" "$BACKUP_FILE"
  echo "📦 Existing .env backed up to $BACKUP_FILE"
fi

# Helper: generate random string
gen_secret() {
  openssl rand -base64 32 | tr -d '\n'
}

# Helper: prompt for required input
prompt_required() {
  local var_name=$1
  local prompt_text=$2

  read -rp "$prompt_text: " value
  if [ -z "$value" ]; then
    echo "❌ $var_name cannot be empty"
    exit 1
  fi
  echo "$value"
}

# Helper: prompt optional with default
prompt_optional() {
  local var_name=$1
  local prompt_text=$2
  local default_value=$3

  read -rp "$prompt_text [$default_value]: " value
  echo "${value:-$default_value}"
}

# === Prompt for important secrets ===

echo ""
echo "👉 Required external configuration"

ACME_EMAIL=$(prompt_required "ACME_EMAIL" "Enter ACME email (Let's Encrypt)")
TRANSIP_ACCOUNT_NAME=$(prompt_required "TRANSIP_ACCOUNT_NAME" "Enter TransIP account name")

echo ""
echo "👉 Required backend configuration"

AUTHENTIK_LEKKER_ATLAS_CLIENT_ID=$(prompt_required "AUTHENTIK_LEKKER_ATLAS_CLIENT_ID" "Enter Authentik client ID (for the LekkerAtlas application)")
AUTHENTIK_LEKKER_ATLAS_CLIENT_SECRET=$(prompt_required "AUTHENTIK_LEKKER_ATLAS_CLIENT_SECRET" "Enter Authentik client secret (for the LekkerAtlas application)")

echo ""
echo "👉 Database config (main app)"

POSTGRES_USER=$(prompt_optional "POSTGRES_USER" "Postgres user" "postgres")
POSTGRES_DB=$(prompt_optional "POSTGRES_DB" "Postgres DB name" "lekkeratlas")
POSTGRES_PASSWORD=$(gen_secret)

echo ""
echo "👉 Generating internal secrets..."

# === Generated secrets ===

RABBITMQ_DEFAULT_USER="rabbitmq"
RABBITMQ_DEFAULT_PASS=$(gen_secret)

AUTHENTIK_SECRET_KEY=$(gen_secret)
AUTHENTIK_WEBHOOK_SECRET=$(gen_secret)

AUTHENTIK_POSTGRES_USER="authentik"
AUTHENTIK_POSTGRES_PASSWORD=$(gen_secret)
AUTHENTIK_POSTGRES_DB="authentik"

# === Write .env ===

cat > "$ENV_FILE" <<EOF
# ================================
# Public / External config
# ================================

ACME_EMAIL=$ACME_EMAIL
TRANSIP_ACCOUNT_NAME=$TRANSIP_ACCOUNT_NAME


# ================================
# Backend config
# ================================

# Authentik OIDC
AUTHENTIK_LEKKER_ATLAS_CLIENT_ID=$AUTHENTIK_LEKKER_ATLAS_CLIENT_ID
AUTHENTIK_LEKKER_ATLAS_CLIENT_SECRET=$AUTHENTIK_LEKKER_ATLAS_CLIENT_SECRET


# ================================
# Main application database
# ================================

POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=$POSTGRES_DB


# ================================
# RabbitMQ (internal only)
# ================================

RABBITMQ_DEFAULT_USER=$RABBITMQ_DEFAULT_USER
RABBITMQ_DEFAULT_PASS=$RABBITMQ_DEFAULT_PASS


# ================================
# Authentik
# ================================

AUTHENTIK_SECRET_KEY=$AUTHENTIK_SECRET_KEY
AUTHENTIK_WEBHOOK_SECRET=$AUTHENTIK_WEBHOOK_SECRET

AUTHENTIK_POSTGRES_USER=$AUTHENTIK_POSTGRES_USER
AUTHENTIK_POSTGRES_PASSWORD=$AUTHENTIK_POSTGRES_PASSWORD
AUTHENTIK_POSTGRES_DB=$AUTHENTIK_POSTGRES_DB


# ================================
# 🐳 Optional overrides
# ================================

# AUTHENTIK_IMAGE=ghcr.io/goauthentik/server
# AUTHENTIK_TAG=2026.2.2

EOF

echo ""
echo "✅ .env file generated!"
echo "⚠️  Keep this file safe and DO NOT commit it to git."