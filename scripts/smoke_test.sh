#!/usr/bin/env bash
set -u

URL="${1:?usage: smoke_test.sh <base_url> <expected_sha>}"
EXPECTED_SHA="${2:?usage: smoke_test.sh <base_url> <expected_sha>}"
TIMEOUT="${HEALTHCHECK_TIMEOUT:-30}"

echo "Smoke test: ${URL} (expecting version ${EXPECTED_SHA}, timeout ${TIMEOUT}s)"

elapsed=0
while [ "$elapsed" -lt "$TIMEOUT" ]; do
  code=$(curl -s -o /tmp/envflow_health.json -w '%{http_code}' "${URL}/health" || echo 000)
  if [ "$code" = "200" ]; then
    break
  fi
  sleep 2
  elapsed=$((elapsed + 2))
done

body=$(cat /tmp/envflow_health.json 2>/dev/null || echo "")
echo "GET /health -> HTTP ${code}"
echo "Body: ${body}"

if [ "$code" != "200" ]; then
  echo "Health check FAILED: endpoint did not return 200 within ${TIMEOUT}s"
  exit 1
fi

if ! echo "$body" | grep -Eq '"status": ?"healthy"'; then
  echo "Health check FAILED: status is not healthy"
  exit 1
fi

if ! echo "$body" | grep -Eq "\"version\": ?\"${EXPECTED_SHA}\""; then
  echo "Health check FAILED: deployed version does not match ${EXPECTED_SHA}"
  exit 1
fi

server=$(curl -sI "${URL}/" | tr -d '\r' | awk -F': ' 'tolower($1)=="server"{print $2}')
echo "GET / -> Server: ${server}"
case "$server" in
  nginx*) ;;
  *) echo "Health check FAILED: response did not come through Nginx"; exit 1 ;;
esac

echo "Health check PASSED: status=healthy version=${EXPECTED_SHA} via ${server}"
