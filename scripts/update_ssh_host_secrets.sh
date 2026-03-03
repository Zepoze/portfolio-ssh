#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

# ================== CONFIG ==================
SECRET_ID="${SECRET_ID:-arn:aws:secretsmanager:eu-west-3:160927904376:secret:portfolio-ssh/dev/ssh_hostkey-t2gzfT}"
AWS_REGION="${AWS_REGION:-eu-west-3}"
COMMENT="${COMMENT:-ssh-host@myapp}"

# Sécurité : compte AWS attendu (optionnel mais recommandé)
EXPECTED_ACCOUNT_ID="${EXPECTED_ACCOUNT_ID:-}" # ex: 123456789012

# ============================================



# ================== PRE-CHECKS ==================

command -v aws >/dev/null || die "aws cli non installé"
command -v jq >/dev/null || die "jq non installé"
command -v ssh-keygen >/dev/null || die "ssh-keygen non installé"

info "Vérification identité AWS…"

IDENTITY="$(aws sts get-caller-identity --region "$AWS_REGION")"
ACCOUNT_ID="$(echo "$IDENTITY" | jq -r .Account)"
ARN="$(echo "$IDENTITY" | jq -r .Arn)"

info "Compte AWS : $ACCOUNT_ID"
info "Caller ARN : $ARN"
info "Region     : $AWS_REGION"

if [[ -n "$EXPECTED_ACCOUNT_ID" && "$ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]]; then
  die "Mauvais compte AWS (attendu: $EXPECTED_ACCOUNT_ID)"
fi

# ================== WORKDIR ==================

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
umask 077

KEYFILE="$WORKDIR/ssh_host_ed25519_key"
PUBFILE="$KEYFILE.pub"
JSONFILE="$WORKDIR/hostkey.json"

# ================== GENERATE KEY ==================

info "Génération nouvelle host key ed25519…"

ssh-keygen -t ed25519 -N "" -C "$COMMENT" -f "$KEYFILE" >/dev/null

# ================== FINGERPRINT ==================

echo
info "NOUVEAU FINGERPRINT SSH :"
ssh-keygen -lf "$PUBFILE"
echo

# ================== CONFIRM ==================

warn "Cette opération va ÉCRASER la host key existante."
warn "Tous les clients verront un changement de fingerprint."

read -rp "Confirmer la creation/modification ? (yes/no) : " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
  warn "Annulé par l'utilisateur."
  exit 0
fi

# ================== BUILD JSON ==================

jq -n \
  --arg private_key_pem "$(cat "$KEYFILE")" \
  --arg public_key "$(cat "$PUBFILE")" \
  '{private_key_pem:$private_key_pem, public_key:$public_key}' \
  > "$JSONFILE"

# ================== UPLOAD ==================

info "Upload vers Secrets Manager…"

aws secretsmanager put-secret-value \
  --secret-id "$SECRET_ID" \
  --region "$AWS_REGION" \
  --secret-string file://"$JSONFILE" \
  >/dev/null

info "Création terminée avec succès ✅"

echo
info "Pense à notifier les clients du nouveau fingerprint."
ssh-keygen -lf "$PUBFILE"
