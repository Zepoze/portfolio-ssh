#!/usr/bin/env bash
set -euo pipefail

ECR_REPO_SLIDES="${ECR_REPO_PROXY:-tf-portfolio-ssh-slides-ecr}"
ECR_REPO_PROXY="${ECR_REPO_PROXY:-tf-portfolio-ssh-proxy-ecr}"

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required env: $name" >&2
    exit 1
  fi
}

git_sha() {
  git rev-parse HEAD
}

image_ref() {
  local repo="$1" tag="$2"
  echo "${ECR_REGISTRY}/${repo}:${tag}"
}

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

die() {
  echo -e "${RED}ERROR:${NC} $*" >&2
  exit 1
}

info() {
  echo -e "${GREEN}INFO:${NC} $*"
}

warn() {
  echo -e "${YELLOW}WARN:${NC} $*"
}
