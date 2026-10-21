# EnvFlow · Multi-Environment CI/CD Pipeline

Automated build, test and deployment of a Flask web app across **Development**, **Staging** and **Production** with **GitHub Actions**, **Docker** and **Nginx**.

DevOps Lab Project · K.J. Somaiya School of Engineering · Om Anand Jha (16010123214), Om Dwivedi (16010123213), Paaras Kokate (16010123224)

📄 **Project report:** [docs/report/EnvFlow_Report.pdf](docs/report/EnvFlow_Report.pdf)

| Environment | URL | Deploys when | Protection |
|---|---|---|---|
| Development | http://localhost:8081 | push to `main`, `dev`, `feature/**` | smoke test |
| Staging | http://localhost:8082 | push to `main`, after Development passes | smoke test |
| Production | http://localhost:8083 | after Staging passes | **required reviewer** + smoke test |

## Architecture

```mermaid
flowchart TB
  dev([Developer]) -->|git push / PR| gh[(GitHub repository)]
  gh -->|event| t
  subgraph gha[GitHub Actions workflow]
    direction LR
    t[Validate<br/>pytest + coverage ≥ 85%] --> b[Build<br/>envflow-app:SHA<br/>envflow-nginx:SHA]
  end
  b -->|same image tag| d1
  subgraph mac[Self-hosted runner · Mac with OrbStack Docker]
    direction LR
    d1[Development<br/>:8081] --> d2[Staging<br/>:8082] --> gate{{Manual approval}} --> d3[Production<br/>:8083]
  end
  mac -.->|after every deploy| v[Smoke test via Nginx<br/>HTTP 200 · status healthy · version = SHA · Server: nginx]
```

## Pipeline jobs

```mermaid
flowchart TB
  trig{{push · pull_request<br/>workflow_dispatch}} --> test
  test[test<br/><small>ubuntu-latest</small>] --> build[build<br/><small>self-hosted</small>]
  build -->|not a PR| dd[deploy-dev<br/>env: development]
  dd -->|branch = main| ds[deploy-staging<br/>env: staging]
  ds --> ap{{required reviewer}} --> dp[deploy-production<br/>env: production]
  test -. fails .-> stop1[[Pipeline stops<br/>nothing deployed]]
  dd -. health fails .-> stop2[[Restore last good image<br/>staging + prod untouched]]
```

## Runtime: one compose project per environment

```mermaid
flowchart LR
  img[(One image pair per commit<br/>envflow-app:SHA · envflow-nginx:SHA)]
  browser([Browser / curl])
  subgraph D[compose project envflow-development]
    n1[nginx:1.26-alpine<br/>host :8081 → 80] --> a1[Gunicorn + Flask<br/>app:5000<br/>APP_ENV=development]
  end
  subgraph S[compose project envflow-staging]
    n2[nginx<br/>host :8082 → 80] --> a2[Gunicorn + Flask<br/>APP_ENV=staging]
  end
  subgraph P[compose project envflow-production]
    n3[nginx<br/>host :8083 → 80] --> a3[Gunicorn + Flask<br/>APP_ENV=production]
  end
  browser --> n1 & n2 & n3
  img ~~~ browser
```

## What deploy.sh does

```mermaid
flowchart TB
  s([deploy.sh ENV PORT SHA]) --> up[docker compose up -d<br/>IMAGE_TAG = SHA]
  up --> sm([smoke_test.sh<br/>200 · healthy · version · nginx])
  sm -->|pass| ok[Save SHA as last good<br/>~/.envflow/ENV.last_good]
  ok --> done([Job green · next environment runs])
  sm -->|fail| logs[Print app container logs]
  logs --> rb[Redeploy last good SHA<br/>and verify it]
  rb --> fail([Job red · promotion stops])
```

Rendered SVG and PNG versions of every diagram (plus the Nginx routing and sequence diagrams) are in [`docs/diagrams`](docs/diagrams).

## Repository layout

```
app.py                         Flask app: dashboard, /add, /delete/<id>, /health
templates/index.html           Environment aware dashboard
static/style.css               Served directly by Nginx
tests/test_app.py              8 pytest cases, coverage gate 85%
Dockerfile                     App image (python:3.12-slim + Gunicorn), SHA baked in
nginx/Dockerfile, nginx.conf   Nginx image: reverse proxy + static files
docker-compose.yml             One stack (app + nginx), parameterised by APP_ENV / HOST_PORT / IMAGE_TAG
.github/workflows/cicd-pipeline.yml   test → build → deploy-dev → deploy-staging → deploy-production
scripts/deploy.sh              compose up, smoke test, record last good SHA, restore on failure
scripts/smoke_test.sh          Checks HTTP 200, status healthy, version = SHA, Server: nginx
scripts/setup_github.sh        Creates repo, environments, reviewer rule, secrets via gh
scripts/demo_helper.sh         status / open / break-test / break-health helpers for the demo
docs/                          Diagrams, screenshots, report PDF
```

## Setup (macOS + OrbStack)

1. Start OrbStack, then check `docker compose version`.
2. Run `./scripts/setup_github.sh`. It creates the repo, the 3 environments, the production reviewer rule and the secrets.
3. Add a self-hosted runner. Open the link the script prints, then run the `config.sh` commands it shows in `~/actions-runner`. Keep the default labels.
4. Start the runner in a terminal: `cd ~/actions-runner && ./run.sh`
5. Push: `git push -u origin main`

## Demo commands

```bash
./scripts/demo_helper.sh status        # /health of all 3 environments
./scripts/demo_helper.sh containers    # running containers and port mappings
./scripts/demo_helper.sh open          # open :8081 :8082 :8083
curl -sI localhost:8083                # Server: nginx
./scripts/demo_helper.sh break-test    # make a test fail, then commit + push
./scripts/demo_helper.sh fix-test
./scripts/demo_helper.sh break-health  # dispatch a run where the new Dev container is unhealthy
```

## Run locally without GitHub

```bash
pip install -r requirements.txt && pytest
./scripts/demo_helper.sh local-up
```
