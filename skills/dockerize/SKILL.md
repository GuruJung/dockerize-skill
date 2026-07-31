---
name: dockerize
description: Build Docker Compose based project environments that avoid host pollution from global packages, virtualenvs, node_modules, generated files, ports, databases, queues, caches, ML models, and GPU workloads. Use when the user explicitly asks to dockerize, containerize, isolate with Docker, or create Dockerfile/compose.yaml workflows; otherwise use only when a project has no existing Compose setup and containerization is needed. Do not use for routine changes in already Compose-managed projects unless Docker or Compose is the requested subject.
---

# Dockerize

## Core Workflow

1. Inspect the project before writing Docker files: existing `compose.yaml`, `docker-compose.yaml`, wrapper scripts, `.env.example`, dependency manifests, entrypoints, scripts, expected outputs, large data/model folders, side services, ports, and GPU needs.
2. Prefer a `Dockerfile` plus `compose.yaml` that copies source into the image. Avoid bind-mounting the full repo by default because container-created files can pollute the host checkout or become root-owned.
3. Add a `.dockerignore` early. Exclude generated dependencies, build outputs, caches, secrets/local-only config, VCS files, root `/dev/` and `/dev_*/` directories, and large model/data/output folders unless they must be copied into the image.
4. Keep databases, queues, object stores, caches, and similar side services on the internal Compose network. Do not publish host ports unless the user needs direct host access.
5. Use named volumes for persistent outputs, results, model caches, database data, and other files that must survive container removal. Base volume names on `COMPOSE_PROJECT_NAME` by default and provide per-volume env overrides so worktrees can isolate stacks while sharing selected heavy volumes.
6. Add basic Compose wrapper scripts in the project root: `compose-up.sh`, `compose-down.sh`, and `compose-logs.sh`.
7. Run validation through Compose, not host-local package managers. At minimum run `docker compose config`; use test-profile services when present.

## Decisions To Make

- **Source handling**: copy source into the image unless live editing or host-visible output is explicitly required.
- **Secrets and config**: never `COPY` secrets or local-only config such as `.env`, credentials, private keys, tokens, or untracked machine-local config into images. Use `env_file` for environment injection, or targeted read-only bind mounts when the app needs secret files at runtime. Non-secret project config that is versioned and part of the application source can be copied normally.
- **Large assets**: prefer targeted read-only binds or named volumes for very large folders such as `assets/`, `examples/`, `samples/`, `dataset_dir/`, model weights, datasets, and caches. If it is unclear whether a large folder should be copied into the image, bind-mounted from the host, or stored in a named volume, ask the user.
- **User identity**: do not force non-root containers. Use a documented non-root user when the base image or project already supports it cleanly; otherwise keep the base image default user.
- **Outputs**: default to named volumes such as `results:` or `artifacts:`. Use host bind mounts only when immediate host access is more important than isolation.
- **Project and volume names**: add `COMPOSE_PROJECT_NAME` to `.env.example`, add top-level Compose `name: ${COMPOSE_PROJECT_NAME:-<repo-name>}`, and define volume names like `${RESULTS_VOLUME_NAME:-${COMPOSE_PROJECT_NAME:-<repo-name>}_results}`.
- **GPU**: for ML projects, add GPU support when training, finetuning, inference, CUDA, PyTorch, TensorFlow, or similar tooling is detected or requested.
- **Train vs inference**: use separate services or Dockerfile targets when dependency/runtime needs differ.
- **Utility scripts**: prefer `docker compose run --rm <service> <command>` or a dedicated `tools` service instead of host-local script execution.
- **Compose wrappers**: create `compose-up.sh`, `compose-down.sh`, and `compose-logs.sh` so common operations are repeatable without memorizing project-specific Compose flags.

## References

Read only the files needed for the task:

- `references/policy.md`: default Dockerization rules and tradeoffs.
- `references/ml.md`: GPU, model weights, train/finetune, and inference patterns.
- `references/utilities.md`: one-off commands, scripts, and export workflows.

## Templates

Use templates as starting points, then adapt to the discovered stack:

- `assets/Dockerfile.template`
- `assets/compose.yaml.template`
- `assets/.dockerignore.template`
- `assets/compose-up.sh.template`
- `assets/compose-down.sh.template`
- `assets/compose-logs.sh.template`
