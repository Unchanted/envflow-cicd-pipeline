#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

status() {
  for pair in development:8081 staging:8082 production:8083; do
    env="${pair%%:*}"
    port="${pair##*:}"
    printf '%-12s :%s  ' "$env" "$port"
    curl -s --max-time 3 "http://localhost:${port}/health" || printf 'not running'
    echo
  done
}

case "${1:-help}" in
  status)
    status
    ;;
  containers)
    docker ps --filter "name=envflow" --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}'
    ;;
  open)
    open http://localhost:8081 http://localhost:8082 http://localhost:8083
    ;;
  local-up)
    tag="$(git -C "$ROOT" rev-parse --short=7 HEAD)"
    docker build --build-arg GIT_SHA="$tag" -t "envflow-app:${tag}" "$ROOT"
    docker build -f "$ROOT/nginx/Dockerfile" -t "envflow-nginx:${tag}" "$ROOT"
    "$ROOT/scripts/deploy.sh" development 8081 "$tag"
    "$ROOT/scripts/deploy.sh" staging 8082 "$tag"
    "$ROOT/scripts/deploy.sh" production 8083 "$tag"
    ;;
  down)
    for env in development staging production; do
      APP_ENV="$env" docker compose -f "$ROOT/docker-compose.yml" down
    done
    ;;
  break-test)
    sed -i.bak 's/assert body\["status"\] == "healthy"/assert body["status"] == "broken"/' "$ROOT/tests/test_app.py"
    rm -f "$ROOT/tests/test_app.py.bak"
    echo "tests/test_app.py now has a failing assertion. Commit and push to see the pipeline stop."
    ;;
  fix-test)
    git -C "$ROOT" checkout -- tests/test_app.py
    echo "tests/test_app.py restored."
    ;;
  break-health)
    gh workflow run cicd-pipeline.yml -f break_health=true
    echo "Started a run where the new Development container reports unhealthy."
    ;;
  *)
    echo "usage: demo_helper.sh {status|containers|open|local-up|down|break-test|fix-test|break-health}"
    ;;
esac
