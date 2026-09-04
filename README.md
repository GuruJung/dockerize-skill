# Dockerize Skill

[Korean](README-ko.md)

Dockerize Skill is a Codex skill for building Docker Compose environments without polluting the
host with global packages, virtual environments, `node_modules`, generated files, service ports,
databases, queues, caches, ML models, or GPU tooling.

It inspects the project before generating files, adapts the result to finite jobs or long-lived
services, and keeps the generated workflow reproducible through Compose. The repository contains
equivalent Korean and English skill instructions, reusable templates, references, safe global
installation tools, and regression tests.

## Installation

Linux and macOS require Bash 3.2 or later plus `sha256sum` or `shasum`. Windows requires Windows
PowerShell 5.1 or later. Administrator privileges and third-party packages are not required.

On Linux or macOS, clone the repository, install the skill, and confirm that its entry point is
present:

```bash
git clone https://github.com/GuruJung/dockerize-skill.git
cd dockerize-skill
./scripts/install.sh
test -f "$HOME/.agents/skills/dockerize/SKILL.md"
```

On Windows PowerShell:

```powershell
git clone https://github.com/GuruJung/dockerize-skill.git
Set-Location dockerize-skill
.\scripts\install.ps1
Test-Path (Join-Path $HOME '.agents/skills/dockerize/SKILL.md')
```

The installer first verifies the Korean-English synchronization state, then copies only the
English `skills/dockerize` directory to `$HOME/.agents/skills/dockerize`. The Korean counterpart,
development instructions, and synchronization metadata are not installed. If Codex does not
recognize the installed skill, start a new session.

Both installers use `$HOME/.agents` by default. For an isolated or custom destination, use
`--agents-root <path>` with Bash or `-AgentsRoot <path>` with PowerShell.

## Quick start

Ask Codex to use the skill while describing the project outcome. The `$` character is part of the
skill name; this is a Codex prompt, not a shell command.

```text
$dockerize Add a Docker Compose setup for this project while avoiding host pollution.
```

You can add constraints such as live editing, host-visible outputs, GPU support, shared model
caches, or a particular service that must be reachable from the host. When a material storage or
runtime choice cannot be inferred safely, the skill asks before generating the setup.

## What the skill does

The skill follows the project rather than applying one fixed Compose layout:

- It inspects dependency manifests, entry points, commands, outputs, side services, ports, GPU
  needs, large assets, and Hugging Face usage before writing Docker files.
- It normally copies source into an image instead of bind-mounting the whole checkout, and creates
  a `.dockerignore` early.
- It distinguishes finite commands from processes that keep waiting for work. Lifecycle wrappers
  are added only for long-lived stacks; finite workloads use `docker compose run --rm`.
- It uses named volumes for persistent outputs and data, adds an export wrapper when users need
  host access, and supports isolated worktrees without duplicating selected heavy caches.
- It validates through Compose rather than installing project dependencies on the host.

The generated environment keeps these safety boundaries:

- Secrets and local-only configuration are never copied into images. Runtime environment or
  targeted read-only mounts are used instead.
- Databases, queues, object stores, and caches stay on the internal Compose network unless direct
  host access is required.
- Host ports are not published merely because a service exists.
- Non-root containers are used when the selected base image or project supports them cleanly; they
  are not forced when that would make the setup fragile.
- Hugging Face projects use a stable shared external `HF_HOME` volume by default, with explicit
  handling for `HF_TOKEN`, host-cache reuse, ownership, and worktree naming.
- GPU support is added when training, finetuning, inference, CUDA, or a compatible ML stack makes
  it necessary.

The detailed behavior contract is in `skills/dockerize/SKILL.md`; topic-specific guidance is in
`skills/dockerize/references/`.

## Updating, uninstalling, and restoring

### Update

Pull the desired repository revision and run the installer again. An identical installation exits
without creating a backup.

```bash
git pull --ff-only
./scripts/install.sh
```

```powershell
git pull --ff-only
.\scripts\install.ps1
```

When installed contents differ, the installer stages and verifies the replacement, backs up the
current installation, and then promotes the new copy. It keeps the five most recent managed
backups under `$HOME/.agents/skill-backups/dockerize` and restores the previous installation if
promotion fails. Files and symbolic links at the managed destination are refused rather than
overwritten.

### Uninstall

```bash
./scripts/uninstall.sh
```

```powershell
.\scripts\uninstall.ps1
```

Uninstalling moves the current installation into the backup directory. It succeeds without
changes when the skill is not installed.

### Restore a backup manually

First verify that `$HOME/.agents/skills/dockerize` does not exist, then select one `<backup-name>`.
On Linux or macOS:

```bash
mkdir -p "$HOME/.agents/skills"
cp -R "$HOME/.agents/skill-backups/dockerize/<backup-name>" "$HOME/.agents/skills/dockerize"
```

On Windows PowerShell:

```powershell
New-Item -ItemType Directory -Path (Join-Path $HOME '.agents/skills') -Force
Copy-Item -Recurse -LiteralPath (Join-Path $HOME '.agents/skill-backups/dockerize/<backup-name>') -Destination (Join-Path $HOME '.agents/skills/dockerize')
```

Validate the restored directory and start a new Codex session if the skill is not recognized.

## Maintainer guide

### Repository layout

- Korean skill: `locales/ko/dockerize/SKILL.md`
- English installed skill: `skills/dockerize/SKILL.md`
- Translation state: `sync/dockerize.sha256`
- Templates and references: `skills/dockerize/assets/` and `skills/dockerize/references/`
- Repository rules: `AGENTS.md`

For the general skill format, see the official
[Build skills documentation](https://learn.chatgpt.com/docs/build-skills).

### Keep README translations synchronized

`README.md` and `README-ko.md` must retain the same meaning and strength, structure, commands,
paths, identifiers, and constraints. Neither language is a fixed editing source.

For an existing tracked pair, modify the intended source first. Before translating the
counterpart, snapshot both Git states and filesystem mtimes once. On Linux:

```bash
git status --short -- README.md README-ko.md
stat -c '%y %n' -- README.md README-ko.md
```

On macOS, use BSD `stat`:

```bash
git status --short -- README.md README-ko.md
stat -f '%.9Fm %N' -- README.md README-ko.md
```

On Windows PowerShell:

```powershell
git status --short -- README.md README-ko.md
Get-Item README.md, README-ko.md | Select-Object FullName, @{Name='LastWriteTimeUtcTicks'; Expression={$_.LastWriteTimeUtc.Ticks}}
```

A normal source candidate has exactly ` M`, `M `, or `MM` status. If only one file is a candidate,
use it as the source. If both are candidates, use the file with the newer snapshotted mtime. A
clean pair is not a synchronization target. Stop for the user's explicit choice if the mtimes are
equal or either file has an `A`, `D`, `R`, `U`, untracked, or other non-`M` change.

Keep that selection fixed until synchronization finishes, translate the complete counterpart,
compare both documents, and run `tests/test-readme-sync.sh`. The test checks structural and key
contract equivalence but does not replace semantic review.

### Edit and synchronize skill translations

Before editing either tracked `SKILL.md`, inspect both files' Git status and filesystem mtime once.
Only existing files modified relative to `HEAD` are candidates. Select the sole candidate or the
newer of two candidates. If both files are clean, begin in the natural language of the request.
Stop for a missing file, equal candidate mtimes, deletion, rename, unmerged state, or any other
unsafe status.

Keep the selected source fixed through the task. Translate the other `SKILL.md` with the same
rules, conditions, precedence, and list order while preserving commands, paths, environment
variables, and code keywords. Do not edit `$HOME/.agents/skills/dockerize` directly.

After semantic comparison, record and verify the synchronization state before running the full
suite:

```bash
./scripts/record-sync.sh
./scripts/check-sync.sh
python "$HOME/.codex/skills/.system/skill-creator/scripts/quick_validate.py" locales/ko/dockerize
python "$HOME/.codex/skills/.system/skill-creator/scripts/quick_validate.py" skills/dockerize
bash -n scripts/*.sh tests/*.sh
bash tests/test-readme-sync.sh
bash tests/test-install.sh
bash tests/test-huggingface-policy.sh
```

On Windows PowerShell, record and check the synchronization state with:

```powershell
.\scripts\record-sync.ps1
.\scripts\check-sync.ps1
```

The manifest proves that neither skill file changed after the last semantic review; it does not
prove translation quality. A missing, damaged, or stale manifest blocks checks and installation.
Changes limited to references, assets, `agents/openai.yaml`, installation tools, or repository
documentation do not require skill translation synchronization. Review
`skills/dockerize/agents/openai.yaml` separately when scope or the default prompt changes.

PowerShell scripts are reviewed statically in the current Linux development environment.

### Improve the skill safely

Do not edit a globally installed copy when a problem is discovered in another project. Preserve
the consumer project's work, report the skill name and repository commit together with the
invocation, expected and actual behavior, minimal reproduction, relevant output and diff, and
whether work is blocked. Make and validate the fix in this repository, use a feature worktree for
candidate changes, integrate the verified result into `main`, and only then update the installed
copy with the installer.

This project is licensed under the [MIT License](LICENSE).
