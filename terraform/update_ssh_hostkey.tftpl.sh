#!/bin/bash
set -euo pipefail

# ================= CONFIG =================
AWS_REGION="${region}"
SECRET_ID="${secred_id}"

mkdir -p /opt/portfolio/proxy || true

KEY_PATH="/opt/portfolio/proxy/ssh_host_key"
PUB_PATH="/opt/portfolio/proxy/ssh_host_key.pub"
# ==========================================

echo "Starting SSH host key bootstrap..."

echo "Fetching secret from Secrets Manager..."

SECRET_JSON="$(aws secretsmanager get-secret-value \
  --region "$AWS_REGION" \
  --secret-id "$SECRET_ID" \
  --query SecretString \
  --output text)"

if [ -z "$SECRET_JSON" ] || [ "$SECRET_JSON" = "null" ]; then
  echo "Secret empty or not found!"
  exit 1
fi

# Extraction
PRIVATE_KEY="$(echo "$SECRET_JSON" | jq -r .private_key_pem)"
PUBLIC_KEY="$(echo "$SECRET_JSON" | jq -r .public_key)"

if [ -z "$PRIVATE_KEY" ] || [ "$PRIVATE_KEY" = "null" ]; then
  echo "private_key_pem missing in secret!"
  exit 1
fi

# Création sécurisée
umask 077

echo "$PRIVATE_KEY" > "$KEY_PATH"

if [ -n "$PUBLIC_KEY" ] && [ "$PUBLIC_KEY" != "null" ]; then
  echo "$PUBLIC_KEY" > "$PUB_PATH"
fi

chown root:root "$KEY_PATH" "$PUB_PATH" 2>/dev/null || true
chmod 600 "$KEY_PATH"
chmod 644 "$PUB_PATH" 2>/dev/null || true

echo "SSH host key successfully installed."
