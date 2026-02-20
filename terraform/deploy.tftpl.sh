#!/usr/bin/env bash
set -euo pipefail

cd /opt/portfolio

CHANNEL="${channel}" # dev|prod
REGION="${region}"
ECR_REGISTRY_SLIDES="${ecr_url["slides"]}"
ECR_REGISTRY_PROXY="${ecr_url["proxy"]}"

if [ ! "$CHANNEL" = "dev" ]; then
    export STRICT=1
elif [ ! -f "proxy/ssh_host_key" ]; then
    echo "No ssh host key found"
    exit 1
fi

aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY_SLIDES"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY_PROXY"

export SLIDES_IMAGE="$ECR_REGISTRY_SLIDES:$CHANNEL"
export PROXY_IMAGE="$ECR_REGISTRY_PROXY:$CHANNEL"

docker compose down
docker compose pull
docker compose up -d --remove-orphans

docker image prune -f >/dev/null 2>&1 || true