# Dockerize skill development

This repository is the canonical source for the personal `dockerize` skill. The
skill itself lives in `skills/dockerize`; development scripts and documentation
stay outside that directory so they are not copied into the installed skill.

Codex loads personal skills from `$HOME/.agents/skills`. See the official
[Build skills documentation](https://learn.chatgpt.com/docs/build-skills).

## Requirements

- Bash 3.2 or newer on Linux or macOS, or Windows PowerShell 5.1 or newer.
- No administrator privileges or third-party packages are required.
- The PowerShell scripts are maintained for parity but are statically reviewed
  rather than runtime-tested in the current Linux development environment.

## Install and update

Edit the canonical files under `skills/dockerize`, validate them, and then copy
the current version into the global user-skill directory.

```bash
python "$HOME/.codex/skills/.system/skill-creator/scripts/quick_validate.py" skills/dockerize
./scripts/install.sh
```

From PowerShell:

```powershell
.\scripts\install.ps1
```

Both installers default to `$HOME/.agents`. For isolated testing or a custom
location, use `--agents-root <path>` in Bash or `-AgentsRoot <path>` in
PowerShell.

An identical installation is a no-op. When the installed copy differs, the
installer stages and verifies the new copy, backs up the installed copy, and
then promotes the new version. The five newest managed backups are retained in
`$HOME/.agents/skill-backups/dockerize`. Files or links at the target location
are refused instead of overwritten.

## Uninstall

```bash
./scripts/uninstall.sh
```

```powershell
.\scripts\uninstall.ps1
```

Uninstall moves the current installation into the backup directory. Running it
when the skill is already absent succeeds without changing anything.

## Restore a backup manually

Choose a backup only after confirming that `$HOME/.agents/skills/dockerize` is
absent. In Bash:

```bash
mkdir -p "$HOME/.agents/skills"
cp -R "$HOME/.agents/skill-backups/dockerize/<backup-name>" "$HOME/.agents/skills/dockerize"
```

In PowerShell:

```powershell
New-Item -ItemType Directory -Path (Join-Path $HOME '.agents/skills') -Force
Copy-Item -Recurse -LiteralPath (Join-Path $HOME '.agents/skill-backups/dockerize/<backup-name>') -Destination (Join-Path $HOME '.agents/skills/dockerize')
```

Validate the restored directory. Codex normally detects skill changes
automatically; restart Codex if the restored skill does not appear.

## Legacy location

The reusable installers intentionally do not inspect or modify
`$HOME/.codex/skills`. A legacy `dockerize` copy must be compared, backed up,
and removed as a separate one-time migration after the official installation
has been verified. Other legacy skills must remain untouched.

## Tests

The Bash test suite uses only temporary directories and never touches the real
home directory:

```bash
bash -n scripts/install.sh scripts/uninstall.sh tests/test-install.sh
bash tests/test-install.sh
```
