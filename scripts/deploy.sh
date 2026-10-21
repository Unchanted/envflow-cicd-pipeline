#!/usr/bin/env bash
set -u

ENVIRONMENT="${1:?usage: deploy.sh <development|staging|production> <port> <image_tag>}"
PORT="${2:?missing port}"
TAG="${3:?missing image tag}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE_DIR="${ENVFLOW_STATE_DIR:-$HOME/.envflow}"
LAST_GOOD_FILE="${STATE_DIR}/${ENVIRONMENT}.last_good"
mkdir -p "$STATE_DIR"

compose_up() {
  APP_ENV="$ENVIRONMENT" HOST_PORT="$PORT" IMAGE_TAG="$1" BREAK_HEALTH="${2:-0}" \
    docker compose -f "${ROOT}/docker-compose.yml" up -d --remove-orphans
}

echo "Deploying envflow:${TAG} to ${ENVIRONMENT} on port ${PORT}"
compose_up "$TAG" "${BREAK_HEALTH:-0}"

if "${ROOT}/scripts/smoke_test.sh" "http://localhost:${PORT}" "$TAG"; then
  echo "$TAG" > "$LAST_GOOD_FILE"
  echo "${ENVIRONMENT} is live on http://localhost:${PORT} with envflow:${TAG}"
  exit 0
fi

echo "Deployment of ${TAG} to ${ENVIRONMENT} failed. Container logs:"
APP_ENV="$ENVIRONMENT" docker compose -f "${ROOT}/docker-compose.yml" logs --tail 30 app || true

if [ -f "$LAST_GOOD_FILE" ]; then
  previous="$(cat "$LAST_GOOD_FILE")"
  echo "Restoring last good version envflow:${previous} on ${ENVIRONMENT}"
  compose_up "$previous" 0
  "${ROOT}/scripts/smoke_test.sh" "http://localhost:${PORT}" "$previous" || true
else
  echo "No previous good version recorded for ${ENVIRONMENT}"
fi

exit 1
