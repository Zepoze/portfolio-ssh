#!/bin/bash
source "$(dirname "$0")/common.sh"

FICHIER="$(dirname "$0")/../content/slides.md"

require_env ARTEFACTS_S3_BUCKET
require_env CHANNEL

BUCKET="$ARTEFACTS_S3_BUCKET"
CHEMIN="artefacts/portfolio-ssh/$CHANNEL/slides.md"

# Vérifier que le fichier existe
if [ ! -f "$FICHIER" ]; then
    die "Erreur: Le fichier '$FICHIER' n'existe pas."
    
fi

# Upload vers S3
aws s3 cp "$FICHIER" "s3://$BUCKET/$CHEMIN"

# Vérifier si l'upload a réussi
if [ $? -eq 0 ]; then
    info "✅ Upload réussi : s3://$BUCKET/$CHEMIN"
else
    die "❌ Erreur lors de l'upload"
fi
