#!/usr/bin/env bash
set -euo pipefail
set -a
source "$(dirname "$0")/.env"
set +a

cd /opt/portfolio

if [ ! "$CHANNEL" = "dev" ] && [ ! -f "proxy/ssh_host_key" ]; then
    echo "No ssh host key found"
    exit 1
fi

sudo aws s3 cp s3://$ARTEFACT_BUCKET_FOLDER/slides.md "$(dirname "$0")/slides/slides.md"

aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY_SLIDES"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY_PROXY"

docker compose down
docker compose pull
docker compose up -d --remove-orphans

docker image prune -f >/dev/null 2>&1 || true