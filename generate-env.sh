#!/usr/bin/env bash

set -euo pipefail

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

# Generate a random secret suitable for use in an environment variable.
gen_secret() {
  openssl rand -base64 32 | tr -d '\n'
}

# Read an existing environment value when available.
get_existing_env_value() {
  local key=$1

  if [ "$OLD_ENV_EXISTS" = true ]; then
    grep -E "^${key}=" "$ENV_FILE" 2>/dev/null |
      head -n1 |
      cut -d'=' -f2-
  fi
}

# Prompt for a required value, optionally reusing the existing value.
prompt_required_with_existing() {
  local var_name=$1
  local prompt_text=$2
  local existing_value
  local value

  existing_value=$(get_existing_env_value "$var_name")

  if [ -n "$existing_value" ]; then
    read -rp "$prompt_text [Press enter to reuse existing value]: " value
    value=${value:-$existing_value}
  else
    read -rp "$prompt_text: " value
  fi

  if [ -z "$value" ]; then
    echo "❌ $var_name cannot be empty" >&2
    exit 1
  fi

  echo "$value"
}

# Prompt for an optional value, using either the existing value or a default.
prompt_optional_with_existing() {
  local var_name=$1
  local prompt_text=$2
  local default_value=$3
  local existing_value
  local value

  existing_value=$(get_existing_env_value "$var_name")

  if [ -n "$existing_value" ]; then
    read -rp "$prompt_text [$existing_value]: " value
    echo "${value:-$existing_value}"
  else
    read -rp "$prompt_text [$default_value]: " value
    echo "${value:-$default_value}"
  fi
}

echo ""
echo "👉 Required external configuration"

ACME_EMAIL=$(
  prompt_required_with_existing \
    "ACME_EMAIL" \
    "Enter ACME email (Let's Encrypt)"
)

TRANSIP_ACCOUNT_NAME=$(
  prompt_required_with_existing \
    "TRANSIP_ACCOUNT_NAME" \
    "Enter TransIP account name"
)

echo ""
echo "👉 Required backend configuration"

AUTHENTIK_LEKKER_ATLAS_CLIENT_ID=$(
  prompt_required_with_existing \
    "AUTHENTIK_LEKKER_ATLAS_CLIENT_ID" \
    "Enter Authentik client ID for the LekkerAtlas application"
)

echo ""
echo "👉 Authentik production URLs"

AUTHENTIK_LEKKERATLAS_FQDN=$(
  prompt_optional_with_existing \
    "AUTHENTIK_LEKKERATLAS_FQDN" \
    "Authentik public URL" \
    "https://auth.lekkeratlas.nl"
)

AUTHENTIK_LEKKERATLAS_REDIRECT_URI=$(
  prompt_optional_with_existing \
    "AUTHENTIK_LEKKERATLAS_REDIRECT_URI" \
    "LekkerAtlas redirect and logout URI" \
    "https://lekkeratlas.nl"
)

AUTHENTIK_LEKKERATLAS_WEBHOOK_FQDN=$(
  prompt_optional_with_existing \
    "AUTHENTIK_LEKKERATLAS_WEBHOOK_FQDN" \
    "Backend URL used by the Authentik webhook" \
    "http://backend-api:8080"
)

echo ""
echo "👉 Authentik bootstrap configuration"

AUTHENTIK_BOOTSTRAP_EMAIL=$(
  prompt_optional_with_existing \
    "AUTHENTIK_BOOTSTRAP_EMAIL" \
    "Authentik bootstrap administrator email" \
    "$ACME_EMAIL"
)

AUTHENTIK_ERROR_REPORTING__ENABLED=$(
  prompt_optional_with_existing \
    "AUTHENTIK_ERROR_REPORTING__ENABLED" \
    "Enable Authentik error reporting" \
    "false"
)

echo ""
echo "👉 WireGuard VPN configuration"

WIREGUARD_PRIVATE_KEY=$(
  prompt_required_with_existing \
    "WIREGUARD_PRIVATE_KEY" \
    "Enter WireGuard private key"
)

WIREGUARD_ADDRESSES=$(
  prompt_required_with_existing \
    "WIREGUARD_ADDRESSES" \
    "Enter WireGuard addresses"
)

WIREGUARD_ENDPOINT_IP=$(
  prompt_required_with_existing \
    "WIREGUARD_ENDPOINT_IP" \
    "Enter WireGuard endpoint IP"
)

WIREGUARD_ENDPOINT_PORT=$(
  prompt_required_with_existing \
    "WIREGUARD_ENDPOINT_PORT" \
    "Enter WireGuard endpoint port"
)

WIREGUARD_PUBLIC_KEY=$(
  prompt_required_with_existing \
    "WIREGUARD_PUBLIC_KEY" \
    "Enter WireGuard public key"
)

echo ""
echo "👉 Main application database"

POSTGRES_USER=$(
  prompt_optional_with_existing \
    "POSTGRES_USER" \
    "Postgres user" \
    "postgres"
)

POSTGRES_DB=$(
  prompt_optional_with_existing \
    "POSTGRES_DB" \
    "Postgres database name" \
    "lekkeratlas"
)

POSTGRES_PASSWORD=$(get_existing_env_value "POSTGRES_PASSWORD")
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-$(gen_secret)}

echo ""
echo "👉 Generating and reusing internal secrets..."

# RabbitMQ

RABBITMQ_DEFAULT_USER=$(get_existing_env_value "RABBITMQ_DEFAULT_USER")
RABBITMQ_DEFAULT_USER=${RABBITMQ_DEFAULT_USER:-rabbitmq}

RABBITMQ_DEFAULT_PASS=$(get_existing_env_value "RABBITMQ_DEFAULT_PASS")
RABBITMQ_DEFAULT_PASS=${RABBITMQ_DEFAULT_PASS:-$(gen_secret)}

# Authentik database

AUTHENTIK_POSTGRES_USER=$(get_existing_env_value "AUTHENTIK_POSTGRES_USER")
AUTHENTIK_POSTGRES_USER=${AUTHENTIK_POSTGRES_USER:-authentik}

AUTHENTIK_POSTGRES_PASSWORD=$(
  get_existing_env_value "AUTHENTIK_POSTGRES_PASSWORD"
)
AUTHENTIK_POSTGRES_PASSWORD=${AUTHENTIK_POSTGRES_PASSWORD:-$(gen_secret)}

AUTHENTIK_POSTGRES_DB=$(get_existing_env_value "AUTHENTIK_POSTGRES_DB")
AUTHENTIK_POSTGRES_DB=${AUTHENTIK_POSTGRES_DB:-authentik}

# Authentik application secrets

AUTHENTIK_SECRET_KEY=$(get_existing_env_value "AUTHENTIK_SECRET_KEY")
AUTHENTIK_SECRET_KEY=${AUTHENTIK_SECRET_KEY:-$(gen_secret)}

AUTHENTIK_BOOTSTRAP_PASSWORD=$(
  get_existing_env_value "AUTHENTIK_BOOTSTRAP_PASSWORD"
)
AUTHENTIK_BOOTSTRAP_PASSWORD=${AUTHENTIK_BOOTSTRAP_PASSWORD:-$(gen_secret)}

AUTHENTIK_BOOTSTRAP_TOKEN=$(
  get_existing_env_value "AUTHENTIK_BOOTSTRAP_TOKEN"
)
AUTHENTIK_BOOTSTRAP_TOKEN=${AUTHENTIK_BOOTSTRAP_TOKEN:-$(gen_secret)}

AUTHENTIK_PROVIDER_FOR_LEKKERATLAS_CLIENT_SECRET=$(
  get_existing_env_value "AUTHENTIK_PROVIDER_FOR_LEKKERATLAS_CLIENT_SECRET"
)
AUTHENTIK_PROVIDER_FOR_LEKKERATLAS_CLIENT_SECRET=${
  AUTHENTIK_PROVIDER_FOR_LEKKERATLAS_CLIENT_SECRET:-$(gen_secret)
}

AUTHENTIK_RABBITMQ_CLIENT_SECRET=$(
  get_existing_env_value "AUTHENTIK_RABBITMQ_CLIENT_SECRET"
)
AUTHENTIK_RABBITMQ_CLIENT_SECRET=${
  AUTHENTIK_RABBITMQ_CLIENT_SECRET:-$(gen_secret)
}

# The backend and Authentik webhook blueprint must use the same bearer token.
AUTHENTIK_WEBHOOK_SECRET=$(get_existing_env_value "AUTHENTIK_WEBHOOK_SECRET")

if [ -z "$AUTHENTIK_WEBHOOK_SECRET" ]; then
  AUTHENTIK_WEBHOOK_SECRET=$(
    get_existing_env_value \
      "AUTHENTIK_WEBHOOK_SYNC_LEKKERATLAS_DB_BEARER_TOKEN"
  )
fi

AUTHENTIK_WEBHOOK_SECRET=${AUTHENTIK_WEBHOOK_SECRET:-$(gen_secret)}

AUTHENTIK_WEBHOOK_SYNC_LEKKERATLAS_DB_BEARER_TOKEN=$AUTHENTIK_WEBHOOK_SECRET

# Write .env

cat >"$ENV_FILE" <<EOF
# ================================
# Public / external configuration
# ================================

ACME_EMAIL=$ACME_EMAIL
TRANSIP_ACCOUNT_NAME=$TRANSIP_ACCOUNT_NAME


# ================================
# Backend configuration
# ================================

# Authentik OIDC
AUTHENTIK_LEKKER_ATLAS_CLIENT_ID=$AUTHENTIK_LEKKER_ATLAS_CLIENT_ID

# Authentik webhook authentication
AUTHENTIK_WEBHOOK_SECRET=$AUTHENTIK_WEBHOOK_SECRET

# WireGuard VPN for the backend worker
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
# RabbitMQ
# ================================

RABBITMQ_DEFAULT_USER=$RABBITMQ_DEFAULT_USER
RABBITMQ_DEFAULT_PASS=$RABBITMQ_DEFAULT_PASS


# ================================
# Authentik database
# ================================

AUTHENTIK_POSTGRES_USER=$AUTHENTIK_POSTGRES_USER
AUTHENTIK_POSTGRES_PASSWORD=$AUTHENTIK_POSTGRES_PASSWORD
AUTHENTIK_POSTGRES_DB=$AUTHENTIK_POSTGRES_DB


# ================================
# Authentik core configuration
# ================================

AUTHENTIK_SECRET_KEY=$AUTHENTIK_SECRET_KEY
AUTHENTIK_ERROR_REPORTING__ENABLED=$AUTHENTIK_ERROR_REPORTING__ENABLED

AUTHENTIK_BOOTSTRAP_EMAIL=$AUTHENTIK_BOOTSTRAP_EMAIL
AUTHENTIK_BOOTSTRAP_PASSWORD=$AUTHENTIK_BOOTSTRAP_PASSWORD
AUTHENTIK_BOOTSTRAP_TOKEN=$AUTHENTIK_BOOTSTRAP_TOKEN


# ================================
# Authentik LekkerAtlas blueprint
# ================================

AUTHENTIK_LEKKERATLAS_FQDN=$AUTHENTIK_LEKKERATLAS_FQDN
AUTHENTIK_LEKKERATLAS_REDIRECT_URI=$AUTHENTIK_LEKKERATLAS_REDIRECT_URI
AUTHENTIK_LEKKERATLAS_WEBHOOK_FQDN=$AUTHENTIK_LEKKERATLAS_WEBHOOK_FQDN

AUTHENTIK_WEBHOOK_SYNC_LEKKERATLAS_DB_BEARER_TOKEN=$AUTHENTIK_WEBHOOK_SYNC_LEKKERATLAS_DB_BEARER_TOKEN
AUTHENTIK_PROVIDER_FOR_LEKKERATLAS_CLIENT_SECRET=$AUTHENTIK_PROVIDER_FOR_LEKKERATLAS_CLIENT_SECRET
AUTHENTIK_RABBITMQ_CLIENT_SECRET=$AUTHENTIK_RABBITMQ_CLIENT_SECRET
EOF

chmod 600 "$ENV_FILE"

echo ""
echo "✅ .env file generated!"
echo "🔒 Permissions set to 600."
echo "⚠️  Keep this file safe and DO NOT commit it to git."
