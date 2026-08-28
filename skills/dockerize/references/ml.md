# ML and GPU Policy

## GPU support

Add GPU support when the project uses CUDA, PyTorch, TensorFlow, JAX, training scripts, finetuning scripts, inference servers, or the user asks for GPU execution.

Use Compose GPU reservations for modern Docker Compose:

```yaml
services:
  train:
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
```

Mention that the host must have a working NVIDIA driver and NVIDIA Container Toolkit. Do not install host GPU drivers from the project containerization unless explicitly requested.

## Train, finetune, and inference

Separate train/finetune and inference when runtime needs differ:

- `train`: heavier dependencies, writable checkpoints/results volumes, optional dataset access.
- `infer`: smaller runtime, read-only model volume where practical, published app/API port only if needed.

Use either separate Dockerfile targets or separate services pointing at the same image with different commands.

## Model weights and datasets

Prefer named volumes for reusable model caches and generated checkpoints:

```yaml
volumes:
  model-cache:
    name: ${MODEL_CACHE_VOLUME_NAME:-${COMPOSE_PROJECT_NAME}_model-cache}
  results:
    name: ${RESULTS_VOLUME_NAME:-${COMPOSE_PROJECT_NAME}_results}
```

For very large existing host folders, use targeted read-only bind mounts instead of mounting the entire repo:

```yaml
volumes:
  - type: bind
    source: /abs/path/to/models
    target: /work/models
    read_only: true
```

Treat large local folders such as `assets/`, `examples/`, `samples/`, `dataset_dir/`, datasets, model weights, and caches as bind mounts or named volumes by default. Ask the user when the intended lifecycle is unclear: image-contained asset, host-owned source/input folder, reusable cache, or generated output.

If the user wants image-contained weights, copy them in a stable early layer and exclude them from broad later copies with `.dockerignore`.

## Hugging Face cache and authentication

When a project uses Hugging Face, default to one shared external named volume for the full `HF_HOME`. Unlike ordinary project volumes, its default name must not use the current worktree's `COMPOSE_PROJECT_NAME`, because doing so would download the same large models and datasets once per worktree.

Find the main worktree from the `branch refs/heads/main` entry in `git worktree list --porcelain`. Use its root basename as the default Compose project name and validate that it contains only lowercase letters, decimal digits, dashes, and underscores and begins with a lowercase letter or decimal digit. If the main worktree is unavailable, the repository uses another canonical branch, or the basename is invalid, ask the user for a stable project name instead of substituting the current worktree name. Do not incorporate a transient `-p` or shell `COMPOSE_PROJECT_NAME` override.

Write the resolved name as a literal fallback in the generated Compose file:

```yaml
services:
  train:
    environment:
      HF_HOME: /cache/huggingface
      HF_TOKEN: ${HF_TOKEN:-}
    volumes:
      - hf-cache:/cache/huggingface

volumes:
  hf-cache:
    name: ${HF_CACHE_VOLUME_NAME:-replace-with-main-project-name_hf-cache}
    external: true
```

Replace `replace-with-main-project-name` while dockerizing the project. The `HF_CACHE_VOLUME_NAME` shell override permits intentional separation and avoids collisions between unrelated clones that have the same root basename.

Keep the volume external so `docker compose down -v` from any worktree cannot delete the shared cache. Inline the logic from `assets/compose-hf-volume-preamble.sh.template` into every generated wrapper that can create a container using the cache, including applicable up, run, test, and export wrappers. The preamble must inspect the volume, create it only when absent, export the exact name for Compose interpolation, and fail before Compose if creation fails. Do not leave a separate helper in the generated project. For direct Compose use, document the equivalent `docker volume create "${HF_CACHE_VOLUME_NAME:-<main-project-name>_hf-cache}"` preparation command. Changing `HF_CACHE_VOLUME_NAME` selects a different cache; do not migrate data automatically.

Use a host bind instead only when the user needs to reuse an existing host cache, share it with host-side tools, manage its files directly, or keep downloads owned by the host account:

```yaml
services:
  train:
    environment:
      HF_HOME: /cache/huggingface
      HF_TOKEN: ${HF_TOKEN:-}
    user: "${HOST_UID:?set HOST_UID}:${HOST_GID:?set HOST_GID}"
    volumes:
      - type: bind
        source: ${HF_CACHE_DIR:-${HOME}/.cache/huggingface}
        target: /cache/huggingface
        read_only: false
```

On native Linux, inline `assets/compose-hf-bind-linux-preamble.sh.template` in each applicable wrapper so the host directory is created and checked by the host account and `HOST_UID`/`HOST_GID` default to `id -u`/`id -g`. Refuse unwritable paths, invalid numeric IDs, automatic `sudo` or `chown`, and root fallback. Do not force numeric UID/GID mapping on Docker Desktop; use its host file-sharing behavior and the image's supported user instead.

Keep application-specific `cache_dir` and `local_dir` settings and variables such as `HF_HUB_CACHE` and `HF_DATASETS_CACHE` under the selected `HF_HOME`, or mount their alternate locations with the same storage and ownership policy.

Treat `HF_TOKEN` as optional. Accept it from the shell or `.env`, pass it with `HF_TOKEN: ${HF_TOKEN:-}`, and never bake it into the image or retain a resolved secret in validation logs. A populated `HF_TOKEN` overrides a token stored under `HF_HOME`; an invalid value does not fall back to the stored token. Because the full `HF_HOME` is persisted, explain that `HF_HOME/token` is also persisted in the shared volume or exposed through the bind. Validate Compose with `HF_TOKEN` unset.
