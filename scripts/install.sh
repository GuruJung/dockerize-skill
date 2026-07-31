#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s [--agents-root <path>]\n' "${0##*/}"
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

new_backup_path() {
  local kind="$1"
  local stamp candidate existing name existing_sequence sequence=0
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  for existing in "$backup_root/$stamp"-??????-*; do
    if [[ -e "$existing" || -L "$existing" ]]; then
      name="${existing##*/}"
      existing_sequence="${name#"$stamp-"}"
      existing_sequence="${existing_sequence%%-*}"
      if [[ "$existing_sequence" =~ ^[0-9]{6}$ ]] && ((10#$existing_sequence >= sequence)); then
        sequence=$((10#$existing_sequence + 1))
      fi
    fi
  done
  printf -v candidate '%s/%s-%06d-%s' "$backup_root" "$stamp" "$sequence" "$kind"
  while [[ -e "$candidate" || -L "$candidate" ]]; do
    sequence=$((sequence + 1))
    printf -v candidate '%s/%s-%06d-%s' "$backup_root" "$stamp" "$sequence" "$kind"
  done
  printf '%s\n' "$candidate"
}

prune_backups() {
  local path
  local -a backups=()

  [[ -d "$backup_root" && ! -L "$backup_root" ]] || return 0
  while IFS= read -r path; do
    backups+=("$path")
  done < <(
    for path in \
      "$backup_root"/????????T??????Z-??????-install \
      "$backup_root"/????????T??????Z-??????-uninstall \
      "$backup_root"/????????T??????Z-??????-migration; do
      if [[ -d "$path" && ! -L "$path" ]]; then
        printf '%s\n' "$path"
      fi
    done | sort
  )

  while ((${#backups[@]} > 5)); do
    rm -rf -- "${backups[0]}"
    backups=("${backups[@]:1}")
  done
}

agents_root="${HOME:?HOME must be set}/.agents"
while (($# > 0)); do
  case "$1" in
    --agents-root)
      (($# >= 2)) || die '--agents-root requires a path'
      agents_root="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown argument: $1"
      ;;
  esac
done

[[ -n "$agents_root" ]] || die 'agents root must not be empty'

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd -P)"
source_dir="$repo_root/skills/dockerize"
skills_root="$agents_root/skills"
target="$skills_root/dockerize"
backup_root="$agents_root/skill-backups/dockerize"

[[ -d "$source_dir" ]] || die "source directory not found: $source_dir"
[[ -f "$source_dir/SKILL.md" ]] || die "source SKILL.md not found: $source_dir/SKILL.md"

for managed_root in "$agents_root" "$skills_root" "$backup_root"; do
  if [[ -L "$managed_root" ]]; then
    die "refusing to use symbolic-link directory: $managed_root"
  fi
done

if [[ -L "$target" ]]; then
  die "refusing to replace symbolic-link target: $target"
fi
if [[ -e "$target" && ! -d "$target" ]]; then
  die "refusing to replace non-directory target: $target"
fi
if [[ -d "$target" ]] && diff -qr "$source_dir" "$target" >/dev/null; then
  printf 'Dockerize skill is already up to date: %s\n' "$target"
  exit 0
fi

mkdir -p -- "$agents_root" "$skills_root"

stage_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
stage_dir="$agents_root/.dockerize-stage-${stage_stamp}-$$"
stage_suffix=0
while [[ -e "$stage_dir" || -L "$stage_dir" ]]; do
  stage_suffix=$((stage_suffix + 1))
  stage_dir="$agents_root/.dockerize-stage-${stage_stamp}-$$-$stage_suffix"
done

cleanup_stage() {
  if [[ -n "${stage_dir:-}" && -d "$stage_dir" && ! -L "$stage_dir" ]]; then
    rm -rf -- "$stage_dir"
  fi
}
trap cleanup_stage EXIT

mkdir -- "$stage_dir"
cp -R "$source_dir"/. "$stage_dir"/
[[ -f "$stage_dir/SKILL.md" ]] || die 'staged copy is missing SKILL.md'
diff -qr "$source_dir" "$stage_dir" >/dev/null || die 'staged copy differs from source'

if [[ -d "$target" ]]; then
  mkdir -p -- "$backup_root"
  backup_path="$(new_backup_path install)"
  mv -- "$target" "$backup_path"
  if ! mv -- "$stage_dir" "$target"; then
    if mv -- "$backup_path" "$target"; then
      die 'install promotion failed; previous installation was restored'
    fi
    die "install promotion failed and automatic restore failed; backup remains at: $backup_path"
  fi
  stage_dir=''
  prune_backups
  printf 'Updated Dockerize skill: %s\n' "$target"
  printf 'Previous installation backed up to: %s\n' "$backup_path"
else
  mv -- "$stage_dir" "$target"
  stage_dir=''
  printf 'Installed Dockerize skill: %s\n' "$target"
fi
