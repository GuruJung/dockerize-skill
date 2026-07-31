# Utility Script Policy

## One-off commands

Run project utilities through Compose:

```bash
docker compose run --rm app python scripts/task.py
docker compose run --rm app npm run migrate
docker compose run --rm tools bash
```

Use `run --rm` for finite commands so containers do not accumulate. Use `exec` only for commands that must run inside an already-running service.

## Compose wrapper scripts

Create these root-level scripts by default when dockerizing a project:

- `compose-up.sh`: build and start the Compose stack.
- `compose-down.sh`: stop the stack without deleting named volumes by default.
- `compose-logs.sh`: follow logs, optionally for a named service.

Keep the scripts thin wrappers around `docker compose` so users can inspect and modify them easily. Use `set -euo pipefail`, resolve the script directory, and run Compose from the project root. Do not make `compose-down.sh` remove volumes unless the user explicitly asks for reset/destructive cleanup behavior.

Use the templates in `assets/` as starting points.

## Compose validation and tests

Validate through Compose rather than host-local package managers:

```bash
docker compose config
docker compose config --services
docker compose build <test-service>
docker compose run --rm <test-service>
```

If a repo has test-profile services, add a thin `compose-test.sh` wrapper. Follow this pattern:

- resolve the repo root and `cd` there
- verify required `.env` files exist
- pass every needed `--env-file`
- enable `--profile test`
- merge every required compose file with `-f`
- when no test service names are passed, auto-discover services ending in `-test` from `docker compose config --services`
- build selected test services, then run each with `docker compose run --rm`

When tests require heavy image builds, large downloads, or GPU resources, it is acceptable to stop at `docker compose config` unless the user asked for full execution.

## Dedicated tools service

Add a `tools` service when the repo has many scripts, CLIs, migrations, data preparation commands, or admin tasks. It can share the same image as the app and override the command:

```yaml
services:
  tools:
    build: .
    profiles: ["tools"]
    command: ["bash"]
```

Run it with:

```bash
docker compose run --rm tools <command>
```

## Exporting results

When outputs are in a named volume, provide an explicit export path instead of defaulting to host bind mounts:

```bash
docker compose cp app:/work/results ./results-export
```

If the producing container is not running, use a temporary helper service that mounts the named volume and copies files to a deliberate host path.
