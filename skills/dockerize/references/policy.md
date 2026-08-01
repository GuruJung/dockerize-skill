# Dockerization Policy

## Default stance

Build project environments around Docker Compose so project dependencies and side services run inside containers. The default output is a `Dockerfile`, `compose.yaml`, and `.dockerignore` that can be run from the repo root.

Use this skill when the user explicitly asks for Docker, Docker Compose, containerization, or dependency isolation through containers. If the user does not explicitly ask for Docker and the project already has a Compose setup, treat routine Docker edits as ordinary repo work instead of invoking this skill. If the project has no Compose setup and containerization is needed to solve the task, use the skill.

Before writing Docker files, inspect for existing `compose.yaml`, `docker-compose.yaml`, wrapper scripts, `.env.example`, dependency manifests, entrypoints, large local folders, side services, ports, and GPU needs.

Prefer source-copy images:

```dockerfile
COPY package*.json ./
RUN npm ci
COPY . .
```

Do not bind-mount the whole source tree unless the user needs live development. Full bind mounts can create host files owned by container users and can leak generated dependency trees into the checkout.

Never copy secrets or local-only config into images. Use `env_file` for env injection, or targeted read-only bind mounts when the app needs secret files such as `.env`, credentials, private keys, tokens, or untracked machine-local config at runtime. Ordinary versioned, non-secret project config can be copied into the image as part of the application source.

## `.dockerignore`

Add `.dockerignore` before relying on build caching. Exclude generated and host-specific paths:

- dependency trees such as `node_modules/`, `.venv/`, `venv/`
- build outputs such as `dist/`, `build/`, `target/`
- caches such as `.cache/`, `.pytest_cache/`, `__pycache__/`
- secrets and local-only config such as `.env`, keys, credentials, tokens, and untracked machine-local config
- root project scratch folders `/dev/` and `/dev_*/`
- large or persistent folders such as `models/`, `weights/`, `data/`, `datasets/`, `outputs/`, `results/`, `assets/`, `examples/`, `samples/`, and `dataset_dir/` when they are handled by volumes or targeted binds

If a Dockerfile first copies a large folder to create a stable cache layer, do not later copy it again with `COPY . .`. Exclude that path in `.dockerignore` and explicitly copy only what is needed.

## Compose project and volume names

Let Compose determine the project name from its normal precedence rules. Do not add `COMPOSE_PROJECT_NAME` to `.env.example` or add a top-level Compose `name:` solely to force a default. Define shareable named volumes with overrideable names:

```yaml
volumes:
  results:
    name: ${RESULTS_VOLUME_NAME:-${COMPOSE_PROJECT_NAME}_results}
```

Compose exposes the selected project name as `COMPOSE_PROJECT_NAME` for interpolation. Its directory-based default keeps separate worktrees isolated, while explicit volume-name env vars still allow selected heavy volumes to be shared.

## Services and ports

Keep side services internal by default. Compose services can reach each other by service name, so databases and queues usually do not need host `ports:`.

Expose ports only for user-facing apps, debuggers, notebooks, or when the user asks for host access:

```yaml
services:
  app:
    ports:
      - "127.0.0.1:8080:8080"
```

Prefer loopback bindings for local-only access.

## User identity

Do not add non-root execution as a blanket rule. If the base image documents a non-root user or the project already handles UID/GID cleanly, use or preserve that setup. Otherwise keep the base image default user to avoid breaking package installs, GPU runtimes, language toolchains, or entrypoints.

When writing to bind-mounted host folders is unavoidable, consider UID/GID handling or document an export workflow that avoids root-owned files.
