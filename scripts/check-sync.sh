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
manifest="$repo_root/sync/dockerize.sha256"

[[ -f "$korean_file" ]] || die "Korean skill not found: $korean_file"
[[ -f "$english_file" ]] || die "English skill not found: $english_file"
[[ -f "$manifest" && ! -L "$manifest" ]] || die "sync manifest not found or unsafe: $manifest"

version=''
korean_sha256=''
english_sha256=''
seen_version=false
seen_korean=false
seen_english=false
while IFS='=' read -r key value; do
  value="${value%$'\r'}"
  case "$key" in
    version)
      [[ "$seen_version" == false ]] || die 'duplicate sync manifest key: version'
      version="$value"
      seen_version=true
      ;;
    korean_sha256)
      [[ "$seen_korean" == false ]] || die 'duplicate sync manifest key: korean_sha256'
      korean_sha256="$value"
      seen_korean=true
      ;;
    english_sha256)
      [[ "$seen_english" == false ]] || die 'duplicate sync manifest key: english_sha256'
      english_sha256="$value"
      seen_english=true
      ;;
    '') ;;
    *) die "unknown sync manifest key: $key" ;;
  esac
done <"$manifest"

[[ "$version" == 1 ]] || die 'sync manifest version must be 1'
[[ "$korean_sha256" =~ ^[0-9a-fA-F]{64}$ ]] || die 'invalid korean_sha256 in sync manifest'
[[ "$english_sha256" =~ ^[0-9a-fA-F]{64}$ ]] || die 'invalid english_sha256 in sync manifest'

actual_korean="$(hash_file "$korean_file")"
actual_english="$(hash_file "$english_file")"
recorded_korean="$(printf '%s\n' "$korean_sha256" | tr '[:upper:]' '[:lower:]')"
recorded_english="$(printf '%s\n' "$english_sha256" | tr '[:upper:]' '[:lower:]')"
[[ "$recorded_korean" == "$actual_korean" ]] || die 'Korean skill changed after the last semantic sync review; synchronize both skill files and record sync again'
[[ "$recorded_english" == "$actual_english" ]] || die 'English skill changed after the last semantic sync review; synchronize both skill files and record sync again'

printf 'Korean and English skill files are in sync.\n'
