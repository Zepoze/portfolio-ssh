#!/bin/bash
source "$(dirname "$0")/common.sh"

USERS_CA_RAW="${1:?missing users ca}"

require_env ARTEFACTS_S3_BUCKET
require_env CHANNEL

BUCKET="$ARTEFACTS_S3_BUCKET"
CHEMIN="artefacts/portfolio-ssh/$CHANNEL/users_ca.pub"

# Vérifier que le fichier est une clé publique valide
if ! ssh-keygen -lf <(echo "$USERS_CA_RAW") >/dev/null 2>&1; then
    die "Erreur: La clé publique CA fournie n'est pas valide."
fi

WORKDIR="$(mktemp -d)"
USERS_CA_FILE="$WORKDIR/users_ca.pub"

trap 'rm -rf "$WORKDIR"' EXIT

echo "$USERS_CA_RAW" > "$USERS_CA_FILE"

# Upload vers S3
aws s3 cp "$USERS_CA_FILE" "s3://$BUCKET/$CHEMIN"

# Vérifier si l'upload a réussi
if [ $? -eq 0 ]; then
    info "✅ Upload réussi : s3://$BUCKET/$CHEMIN"
else
    die "❌ Erreur lors de l'upload"
fi
