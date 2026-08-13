#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

IMAGE="${DOCKER_IMAGE:-ghcr.io/alex-tolch/devops-engineer-from-scratch-project-318:latest}"
HOST="${DEPLOY_HOST:-64.226.67.71}"
SSH_USER="${DEPLOY_SSH_USER:-root}"
NO_CACHE="${NO_CACHE:-}"

BUILD_ARGS=(--build-arg "APP_REPO=${APP_REPO:-https://github.com/hexlet-components/project-devops-deploy.git}")
BUILD_ARGS+=(--build-arg "APP_REF=${APP_REF:-main}")
if [[ -n "$NO_CACHE" ]]; then
  BUILD_ARGS+=(--no-cache)
fi

echo "Building ${IMAGE} (APP_REPO=${APP_REPO:-https://github.com/hexlet-components/project-devops-deploy.git})..."
docker build "${BUILD_ARGS[@]}" -t "$IMAGE" .

echo "Uploading image to ${SSH_USER}@${HOST}..."
docker save "$IMAGE" | ssh "${SSH_USER}@${HOST}" docker load

echo "Recreating containers..."
ssh "${SSH_USER}@${HOST}" "cd /opt/bulletins && docker compose up -d --force-recreate --pull never"

echo "Done. Open http://${HOST}:8080/ (hard refresh: Ctrl+Shift+R)."
