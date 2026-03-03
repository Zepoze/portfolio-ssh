#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

CHANNEL="${1:?missing channel}"

require_env AWS_REGION
require_env ECR_REGISTRY

# ECR login
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

# Proxy push + build
PROXY_IMAGE="$(image_ref "$ECR_REPO_PROXY" "${CHANNEL}")"
docker build -t "$PROXY_IMAGE" "$(dirname "$0")/../proxy"
docker push "$PROXY_IMAGE"

# Slides push + build
SLIDES_IMAGE="$(image_ref "$ECR_REPO_SLIDES" "${CHANNEL}")"
docker build -t "$SLIDES_IMAGE" "$(dirname "$0")/../slides"
docker push "$SLIDES_IMAGE"

info "\tDone. Pushed:\n\t$PROXY_IMAGE\n\t$SLIDES_IMAGE"