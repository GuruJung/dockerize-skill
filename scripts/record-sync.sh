#!/usr/bin/env bash
set -euo pipefail

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

hash_file() {
  local path="$1" digest
  if command -v sha256sum >/dev/null 2>&1; then
    read -r digest _ < <(sha256sum "$path")
  elif command -v shasum >/dev/null 2>&1; then
    read -r digest _ < <(shasum -a 256 "$path")
  else
    die 'sha256sum or shasum is required'
  fi
  printf '%s\n' "$digest" | tr '[:upper:]' '[:lower:]'
}

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd -P)"
korean_file="$repo_root/locales/ko/dockerize/SKILL.md"
english_file="$repo_root/skills/dockerize/SKILL.md"
sync_dir="$repo_root/sync"
manifest="$sync_dir/dockerize.sha256"

[[ -f "$korean_file" ]] || die "Korean source not found: $korean_file"
[[ -f "$english_file" ]] || die "English skill not found: $english_file"
[[ ! -L "$sync_dir" ]] || die "refusing symbolic-link sync directory: $sync_dir"
[[ ! -L "$manifest" ]] || die "refusing symbolic-link sync manifest: $manifest"

mkdir -p -- "$sync_dir"
temp_manifest="$sync_dir/.dockerize.sha256.tmp.$$"
cleanup() {
  if [[ -f "$temp_manifest" && ! -L "$temp_manifest" ]]; then
    rm -f -- "$temp_manifest"
  fi
}
trap cleanup EXIT

printf 'version=1\nkorean_sha256=%s\nenglish_sha256=%s\n' \
  "$(hash_file "$korean_file")" \
  "$(hash_file "$english_file")" >"$temp_manifest"
mv -- "$temp_manifest" "$manifest"

printf 'Recorded Dockerize skill sync hashes after semantic review.\n'
