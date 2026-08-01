# Utility Script Policy

## One-off commands

Run project utilities through Compose:

```bash
docker compose run --rm app python scripts/task.py
docker compose run --rm app npm run migrate
docker compose run --rm tools bash
```

Use `run --rm` for finite commands so containers do not accumulate. Use `exec` only for commands that must run inside an already-running service.

When a repo has a representative one-off executable or command, add `compose-run.sh`. Fix the discovered service and default command in the generated wrapper, forward user arguments, and use `docker compose run --rm`. Do not add the wrapper when the project has no one-off workflow.

## Compose wrapper scripts

When the project has a long-lived service or daemon, create these root-level scripts:

- `compose-up.sh`: build and start the Compose stack.
- `compose-down.sh`: stop the stack without deleting named volumes by default.
- `compose-logs.sh`: follow logs, optionally for a named service.

Keep the scripts thin wrappers around `docker compose` so users can inspect and modify them easily. Use `set -euo pipefail`, resolve the script directory, and run Compose from the project root. Do not make `compose-down.sh` remove volumes unless the user explicitly asks for reset/destructive cleanup behavior.

Always create `compose-test.sh`. When a named volume contains outputs that users need to export to the host, also create `compose-export.sh`. Do not create `compose-up.sh`, `compose-down.sh`, or `compose-logs.sh` for a project that only runs finite commands.

Use the templates in `assets/` as starting points.

## Compose validation and tests

Validate through Compose rather than host-local package managers:

```bash
docker compose config
docker compose config --services
docker compose build <test-service>
docker compose run --rm <test-service>
```

Always add a thin `compose-test.sh` wrapper. Follow this pattern:

- resolve the repo root and `cd` there
- verify required `.env` files exist
- pass every needed `--env-file`
- enable `--profile test`
- merge every required compose file with `-f`
- when no test service names are passed, auto-discover services ending in `-test` from `docker compose config --services`
- build selected test services, then run each with `docker compose run --rm`
- propagate Compose configuration or discovery failures; only when successful discovery finds no runnable test service, print an explanatory message and exit successfully

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

When outputs are in a named volume, add `compose-export.sh` to provide an explicit export path instead of defaulting to host bind mounts. Fix the service and container output path for the discovered project, accept an optional host destination that defaults to `./results-export`, and use:

```bash
docker compose create --no-deps --no-recreate app
docker compose cp app:/work/results ./results-export
```

Before copying, use a finite container for the selected service to verify that the source directory exists and is non-empty. Creating the service with `--no-recreate` when needed then makes its named volume available without replacing or stopping an existing container. Copy from the container with `docker compose cp`, fail when the source is missing, empty, or copying fails, and leave the named-volume source unchanged. Use a temporary helper service instead when no suitable project service mounts the output volume or its image cannot run the required inspection command.
