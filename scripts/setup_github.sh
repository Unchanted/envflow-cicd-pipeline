#!/usr/bin/env bash
set -euo pipefail

REPO_NAME="${1:-envflow-cicd-pipeline}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

gh auth status >/dev/null 2>&1 || gh auth login

if [ ! -d .git ]; then
  git init -b main
  git add .
  git commit -m "EnvFlow: multi-environment CI/CD pipeline"
fi

OWNER="$(gh api user -q .login)"
USER_ID="$(gh api user -q .id)"

if ! gh repo view "${OWNER}/${REPO_NAME}" >/dev/null 2>&1; then
  gh repo create "$REPO_NAME" --public --source=. --remote=origin \
    --description "EnvFlow: automated multi-environment CI/CD pipeline with GitHub Actions, Docker and Nginx"
fi

echo "Creating GitHub Environments"
gh api -X PUT "repos/${OWNER}/${REPO_NAME}/environments/development" >/dev/null
gh api -X PUT "repos/${OWNER}/${REPO_NAME}/environments/staging" >/dev/null
gh api -X PUT "repos/${OWNER}/${REPO_NAME}/environments/production" --input - >/dev/null <<JSON
{
  "reviewers": [{ "type": "User", "id": ${USER_ID} }],
  "deployment_branch_policy": { "protected_branches": false, "custom_branch_policies": true }
}
JSON
gh api -X POST "repos/${OWNER}/${REPO_NAME}/environments/production/deployment-branch-policies" \
  -f name=main -f type=branch >/dev/null 2>&1 || true

echo "Setting environment scoped secrets"
for env in development staging production; do
  gh secret set APP_SECRET_KEY --env "$env" --repo "${OWNER}/${REPO_NAME}" \
    --body "$(openssl rand -hex 24)"
done
gh variable set HEALTHCHECK_TIMEOUT --repo "${OWNER}/${REPO_NAME}" --body 30

echo
echo "Done: https://github.com/${OWNER}/${REPO_NAME}"
echo "Next: add a self-hosted runner"
echo "  https://github.com/${OWNER}/${REPO_NAME}/settings/actions/runners/new?arch=arm64&os=osx"
echo "Then push to main: git push -u origin main"
