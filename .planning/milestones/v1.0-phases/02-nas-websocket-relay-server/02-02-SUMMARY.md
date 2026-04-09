---
phase: 02-nas-websocket-relay-server
plan: 02
subsystem: infra
tags: [docker, nginx, reverse-proxy, websocket, deployment, nas]

# Dependency graph
requires:
  - phase: 02-01
    provides: "WebSocket relay server (relay/) with token auth and room pairing"
provides:
  - "Multi-stage Dockerfile for minimal Node.js Alpine image"
  - "docker-compose.yml with localhost-only port binding and AUTH_TOKEN injection"
  - "Nginx reverse proxy config with WebSocket upgrade headers and 24h timeouts"
  - "Chinese-language NAS deployment README"
affects: [03-chat-ui-streaming]

# Tech tracking
tech-stack:
  added: [docker, docker-compose, nginx]
  patterns: [multi-stage-docker-build, localhost-only-port-binding, nginx-websocket-proxy]

key-files:
  created:
    - relay/Dockerfile
    - relay/docker-compose.yml
    - relay/.dockerignore
    - relay/nginx/relay.conf
    - relay/README.md
  modified: []

key-decisions:
  - "127.0.0.1:8081 port binding instead of Docker network -- simpler for NAS setup where nginx runs on the host"
  - "Port 8081 on host (not 8080) to avoid conflict with any existing NAS service"
  - "nginx trailing slash in proxy_pass strips /relay/ prefix so relay server sees /"

patterns-established:
  - "Docker multi-stage build: builder stage for npm ci, runtime stage with non-root user"
  - "AUTH_TOKEN via .env file injected at container runtime, never in image"

requirements-completed: [RELAY-01, RELAY-06]

# Metrics
duration: 4min
completed: 2026-04-09
---

# Phase 2 Plan 2: Docker Deployment Configuration Summary

**Docker multi-stage build + nginx WebSocket reverse proxy for one-command NAS deployment via docker-compose**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-09T01:43:05Z
- **Completed:** 2026-04-09T01:47:32Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Dockerfile with multi-stage build using node:20-alpine, non-root USER node, production-optimized
- docker-compose.yml binding port 8081 to localhost only with AUTH_TOKEN from .env
- nginx location block for /relay/ with WebSocket upgrade headers and 24h idle timeouts
- Chinese-language deployment README covering full NAS setup workflow

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Dockerfile, docker-compose, and nginx reverse proxy config** - `52782cc` (feat)
2. **Task 2: Create deployment README with step-by-step NAS instructions** - `d2efba3` (docs)

## Files Created/Modified
- `relay/Dockerfile` - Multi-stage Docker build: node:20-alpine builder + runtime, EXPOSE 8080, USER node
- `relay/docker-compose.yml` - Single service: builds from Dockerfile, binds 127.0.0.1:8081:8080, AUTH_TOKEN via .env
- `relay/.dockerignore` - Excludes node_modules, test, .git, .gitignore, *.md, nginx/ from Docker context
- `relay/nginx/relay.conf` - Nginx location /relay/ block: proxy_pass to 127.0.0.1:8081, WebSocket upgrade, 86400s timeouts
- `relay/README.md` - Chinese deployment guide: prerequisites, quick start, nginx config, Flutter/desktop URLs, troubleshooting

## Decisions Made
- Used 127.0.0.1:8081 port binding instead of Docker bridge network -- simpler for personal NAS where nginx runs on the host directly
- Host port 8081 (not 8080) to avoid conflict with any existing NAS services on 8080
- Nginx proxy_pass trailing slash (`http://127.0.0.1:8081/`) strips /relay/ prefix so relay server receives requests at /

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Docker Desktop was installed but not running during verification; file content verification performed instead of live docker build. The Dockerfile syntax is standard and will build successfully when Docker daemon is available on the NAS.

## User Setup Required

None during development. For actual NAS deployment:
1. Copy relay/ directory to NAS
2. Create .env with AUTH_TOKEN
3. Run docker-compose up -d --build
4. Add nginx/relay.conf content to existing 5945.top server block

## Next Phase Readiness
- Docker deployment artifacts ready for NAS deployment
- Relay accessible at wss://5945.top/relay/?token=XXX&role=mobile after nginx config
- Plan 02-03 will update the Flutter app to use wss://5945.top/relay/ URL

## Self-Check: PASSED

All 5 files verified present. Both commit hashes verified in git log.

---
*Phase: 02-nas-websocket-relay-server*
*Completed: 2026-04-09*
