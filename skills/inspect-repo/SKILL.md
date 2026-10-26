---
name: inspect-repo
description: Inspect a local codebase to determine what should be deployed, whether to use Dockerfile or docker-compose, likely ports, env vars, service boundaries, and deployment risks.
---

# Inspect Repo for Deployment

For an identified existing app, first load `get_agents_md` and relevant linked governance.
After meaningful changes, follow `manage-knowledge` to save verified decisions and instructions.


Use this skill when the user asks to deploy an app from a local codebase, wants to know whether the repo is deployable, or needs help choosing image vs docker-compose.

## Goals
- identify deployable units
- analyze the whole app shape first: frontend, backend, workers, queues, DBs, caches, storage, and external services
- decide Dockerfile vs docker-compose
- decide whether the current repo should be built locally and then deployed as an image
- detect likely framework/runtime
- find build/start commands
- infer likely port
- detect required environment variables
- highlight missing deployment prerequisites

## What to inspect
1. Root files:
- `Dockerfile`
- `docker-compose.yml` / `compose.yaml`
- `package.json`
- `pnpm-workspace.yaml`
- `turbo.json`
- `pyproject.toml`
- `requirements.txt`
- `go.mod`
- `Cargo.toml`
- `.env.example`
- framework config files

2. Candidate app directories
- `apps/*`
- `services/*`
- `packages/*`
- `backend/`, `frontend/`, `api/`, `web/`

3. Runtime hints
- exposed ports in code or config
- `PORT` env usage
- server bind host
- health endpoints
- database/cache dependencies
- queues / workers / cron jobs
- file storage and volume needs

## Output format
Provide a compact structured summary:
- deployable unit(s)
- components involved
- recommended deploy path: `dockerfile` or `compose`
- detected framework/runtime
- likely port
- likely build/start command
- required env vars
- confidence/risk notes
- step-by-step deployment plan

## Decision rules
- If a single app can run alone, prefer Dockerfile deployment.
- If multiple tightly coupled services are required together, prefer docker-compose deployment.
- If a Dockerfile exists but is obviously incomplete, say so and propose a patch.
- If no Dockerfile exists but confidence is high, recommend generating one.
- If a Dockerfile is needed, make it low-size, secure, and architecture-agnostic.
- Call out env vars that may differ between local and deployed environments.
- If the repo actually contains two separate full software systems, recommend splitting them into separate projects.

## Runtime compatibility

Check Dockerfile USER and writable application paths before building. Prefer an explicit non-zero UID:GID for custom images; named non-root accounts are resolved from the built image by the backend. Dockerfile inspection is advisory, and the backend image preflight is authoritative. Image-layer chown does not set permissions on a mounted PVC. Declare durable data paths and use existing deployment storage fields; never weaken the workload security baseline to make an image launch.
