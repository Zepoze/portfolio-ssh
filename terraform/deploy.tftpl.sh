#!/usr/bin/env bash
set -euo pipefail

cd /opt/portfolio

CHANNEL="${channel}" # dev|prod
ECR_REGISTRY="${ecr_url}"

export SLIDES_IMAGE="$ECR_REGISTRY:slides-$CHANNEL"
export PROXY_IMAGE="$ECR_REGISTRY:proxy-$CHANNEL"

docker compose down
docker compose pull
docker compose up -d --remove-orphans

docker image prune -f >/dev/null 2>&1 || true