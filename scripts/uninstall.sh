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
  printf -v candidate '%s/%s-%06d-uninstall' "$backup_root" "$stamp" "$sequence"
  while [[ -e "$candidate" || -L "$candidate" ]]; do
    sequence=$((sequence + 1))
    printf -v candidate '%s/%s-%06d-uninstall' "$backup_root" "$stamp" "$sequence"
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

skills_root="$agents_root/skills"
target="$skills_root/dockerize"
backup_root="$agents_root/skill-backups/dockerize"

for managed_root in "$agents_root" "$skills_root" "$backup_root"; do
  if [[ -L "$managed_root" ]]; then
    die "refusing to use symbolic-link directory: $managed_root"
  fi
done

if [[ -L "$target" ]]; then
  die "refusing to uninstall symbolic-link target: $target"
fi
if [[ ! -e "$target" ]]; then
  printf 'Dockerize skill is not installed: %s\n' "$target"
  exit 0
fi
if [[ ! -d "$target" ]]; then
  die "refusing to uninstall non-directory target: $target"
fi

mkdir -p -- "$backup_root"
backup_path="$(new_backup_path)"
mv -- "$target" "$backup_path"
prune_backups

printf 'Uninstalled Dockerize skill: %s\n' "$target"
printf 'Removed installation backed up to: %s\n' "$backup_path"
