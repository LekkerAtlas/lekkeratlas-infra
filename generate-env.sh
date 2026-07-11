#!/usr/bin/env bash

set -e

ENV_FILE=".env"

echo "🔐 Generating .env file..."

OLD_ENV_EXISTS=false

if [ -f "$ENV_FILE" ]; then
  OLD_ENV_EXISTS=true

  TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
  BACKUP_FILE="${ENV_FILE}.backup-${TIMESTAMP}"

  cp "$ENV_FILE" "$BACKUP_FILE"
  echo "📦 Existing .env backed up to $BACKUP_FILE"
fi

# Helper: generate random string
gen_secret() {
  openssl rand -base64 32 | tr -d '\n'
}

# Helper: read existing env value if available
get_existing_env_value() {
  local key=$1

  if [ "$OLD_ENV_EXISTS" = true ]; then
    grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | head -n1 | cut -d'=' -f2-
  fi
}

# Helper: prompt required value with optional reuse from old env
prompt_required_with_existing() {
  local var_name=$1
  local prompt_text=$2

  local existing_value
  existing_value=$(get_existing_env_value "$var_name")

  if [ -n "$existing_value" ]; then
    read -rp "$prompt_text [Press enter to reuse existing value]: " value
    value=${value:-$existing_value}
  else
    read -rp "$prompt_text: " value
  fi

  if [ -z "$value" ]; then
    echo "❌ $var_name cannot be empty"
    exit 1
  fi

  echo "$value"
}

# Helper: prompt optional value with optional reuse from old env
prompt_optional_with_existing() {
  local var_name=$1
  local prompt_text=$2
  local default_value=$3

  local existing_value
  existing_value=$(get_existing_env_value "$var_name")

  if [ -n "$existing_value" ]; then
    read -rp "$prompt_text [$existing_value]: " value
    echo "${value:-$existing_value}"
  else
    read -rp "$prompt_text [$default_value]: " value
    echo "${value:-$default_value}"
  fi
}

# === Prompt for important secrets ===

echo ""
echo "👉 Required external configuration"

ACME_EMAIL=$(prompt_required_with_existing "ACME_EMAIL" "Enter ACME email (Let's Encrypt)")
TRANSIP_ACCOUNT_NAME=$(prompt_required_with_existing "TRANSIP_ACCOUNT_NAME" "Enter TransIP account name")

echo ""
echo "👉 Required backend configuration"


AUTHENTIK_LEKKER_ATLAS_CLIENT_ID=$(prompt_required_with_existing "AUTHENTIK_LEKKER_ATLAS_CLIENT_ID" "Enter Authentik client ID (for the LekkerAtlas application)")

echo ""
echo "👉 WireGuard VPN config (worker VPN)"

WIREGUARD_PRIVATE_KEY=$(prompt_required_with_existing "WIREGUARD_PRIVATE_KEY" "Enter WireGuard private key")
WIREGUARD_ADDRESSES=$(prompt_required_with_existing "WIREGUARD_ADDRESSES" "Enter WireGuard addresses")
WIREGUARD_ENDPOINT_IP=$(prompt_required_with_existing "WIREGUARD_ENDPOINT_IP" "Enter WireGuard endpoint IP")
WIREGUARD_ENDPOINT_PORT=$(prompt_required_with_existing "WIREGUARD_ENDPOINT_PORT" "Enter WireGuard endpoint port")
WIREGUARD_PUBLIC_KEY=$(prompt_required_with_existing "WIREGUARD_PUBLIC_KEY" "Enter WireGuard public key")

echo ""
echo "👉 Database config (main app)"

POSTGRES_USER=$(prompt_optional_with_existing "POSTGRES_USER" "Postgres user" "postgres")
POSTGRES_DB=$(prompt_optional_with_existing "POSTGRES_DB" "Postgres DB name" "lekkeratlas")
POSTGRES_PASSWORD=$(get_existing_env_value "POSTGRES_PASSWORD")
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-$(gen_secret)}

echo ""
echo "👉 Generating internal secrets..."

# === Generated secrets ===

RABBITMQ_DEFAULT_USER=$(get_existing_env_value "RABBITMQ_DEFAULT_USER")
RABBITMQ_DEFAULT_USER=${RABBITMQ_DEFAULT_USER:-rabbitmq}

RABBITMQ_DEFAULT_PASS=$(get_existing_env_value "RABBITMQ_DEFAULT_PASS")
RABBITMQ_DEFAULT_PASS=${RABBITMQ_DEFAULT_PASS:-$(gen_secret)}

AUTHENTIK_SECRET_KEY=$(get_existing_env_value "AUTHENTIK_SECRET_KEY")
AUTHENTIK_SECRET_KEY=${AUTHENTIK_SECRET_KEY:-$(gen_secret)}

AUTHENTIK_WEBHOOK_SECRET=$(get_existing_env_value "AUTHENTIK_WEBHOOK_SECRET")
AUTHENTIK_WEBHOOK_SECRET=${AUTHENTIK_WEBHOOK_SECRET:-$(gen_secret)}

AUTHENTIK_POSTGRES_USER=$(get_existing_env_value "AUTHENTIK_POSTGRES_USER")
AUTHENTIK_POSTGRES_USER=${AUTHENTIK_POSTGRES_USER:-authentik}

AUTHENTIK_POSTGRES_PASSWORD=$(get_existing_env_value "AUTHENTIK_POSTGRES_PASSWORD")
AUTHENTIK_POSTGRES_PASSWORD=${AUTHENTIK_POSTGRES_PASSWORD:-$(gen_secret)}

AUTHENTIK_POSTGRES_DB=$(get_existing_env_value "AUTHENTIK_POSTGRES_DB")
AUTHENTIK_POSTGRES_DB=${AUTHENTIK_POSTGRES_DB:-authentik}

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

# WireGuard VPN (worker)
WIREGUARD_PRIVATE_KEY=$WIREGUARD_PRIVATE_KEY
WIREGUARD_ADDRESSES=$WIREGUARD_ADDRESSES
WIREGUARD_ENDPOINT_IP=$WIREGUARD_ENDPOINT_IP
WIREGUARD_ENDPOINT_PORT=$WIREGUARD_ENDPOINT_PORT
WIREGUARD_PUBLIC_KEY=$WIREGUARD_PUBLIC_KEY


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