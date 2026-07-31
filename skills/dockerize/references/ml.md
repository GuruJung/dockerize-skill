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
    name: ${MODEL_CACHE_VOLUME_NAME:-${COMPOSE_PROJECT_NAME:-my-project}_model-cache}
  results:
    name: ${RESULTS_VOLUME_NAME:-${COMPOSE_PROJECT_NAME:-my-project}_results}
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
