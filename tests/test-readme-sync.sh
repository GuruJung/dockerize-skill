#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local path="$1" text="$2"
  grep -Fq -- "$text" "$path" || fail "expected '$text' in $path"
}

assert_absent() {
  local path="$1" text="$2"
  if grep -Fq -- "$text" "$path"; then
    fail "unexpected '$text' in $path"
  fi
}

assert_order() {
  local path="$1" first="$2" second="$3" first_line second_line
  first_line="$(grep -Fn -- "$first" "$path" | head -n 1 | cut -d: -f1)"
  second_line="$(grep -Fn -- "$second" "$path" | head -n 1 | cut -d: -f1)"
  [[ -n "$first_line" && -n "$second_line" && "$first_line" -lt "$second_line" ]] ||
    fail "expected '$first' before '$second' in $path"
}

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd -P)"
english_readme="$repo_root/README.md"
korean_readme="$repo_root/README-ko.md"
agents_file="$repo_root/AGENTS.md"
license_file="$repo_root/LICENSE"

for path in "$english_readme" "$korean_readme" "$agents_file" "$license_file"; do
  [[ -f "$path" && ! -L "$path" ]] || fail "required plain file is missing: $path"
done

if LC_ALL=C grep -q '[^[:print:][:space:]]' "$english_readme"; then
  fail 'English README contains non-ASCII text'
fi
assert_contains "$korean_readme" 'Dockerize Skill은'
if LC_ALL=C grep -q '[^[:print:][:space:]]' "$agents_file"; then
  fail 'AGENTS.md contains non-ASCII text'
fi

assert_contains "$english_readme" '[Korean](README-ko.md)'
assert_contains "$korean_readme" '[English](README.md)'
assert_contains "$english_readme" 'https://github.com/GuruJung/dockerize-skill.git'
assert_contains "$korean_readme" 'https://github.com/GuruJung/dockerize-skill.git'
assert_contains "$english_readme" '$dockerize Add a Docker Compose setup for this project while avoiding host pollution.'
assert_contains "$korean_readme" '$dockerize Add a Docker Compose setup for this project while avoiding host pollution.'
assert_contains "$english_readme" './scripts/install.sh'
assert_contains "$korean_readme" './scripts/install.sh'
assert_contains "$english_readme" '.\scripts\install.ps1'
assert_contains "$korean_readme" '.\scripts\install.ps1'
assert_contains "$english_readme" "stat -f '%.9Fm %N' -- README.md README-ko.md"
assert_contains "$korean_readme" "stat -f '%.9Fm %N' -- README.md README-ko.md"
assert_contains "$english_readme" "@{Name='LastWriteTimeUtcTicks'; Expression={\$_.LastWriteTimeUtc.Ticks}}"
assert_contains "$korean_readme" "@{Name='LastWriteTimeUtcTicks'; Expression={\$_.LastWriteTimeUtc.Ticks}}"
assert_contains "$english_readme" '.\scripts\record-sync.ps1'
assert_contains "$korean_readme" '.\scripts\record-sync.ps1'
assert_contains "$english_readme" '.\scripts\check-sync.ps1'
assert_contains "$korean_readme" '.\scripts\check-sync.ps1'
assert_contains "$english_readme" '[MIT License](LICENSE)'
assert_contains "$korean_readme" '[MIT License](LICENSE)'
assert_contains "$license_file" 'MIT License'
assert_contains "$license_file" 'Copyright (c) 2026 GuruJung'

assert_order "$english_readme" '## Installation' '## Quick start'
assert_order "$english_readme" '## Quick start' '## What the skill does'
assert_order "$english_readme" '## What the skill does' '## Updating, uninstalling, and restoring'
assert_order "$english_readme" '## Updating, uninstalling, and restoring' '## Maintainer guide'
assert_order "$korean_readme" '## 설치' '## 빠른 시작'
assert_order "$korean_readme" '## 빠른 시작' '## 스킬 동작'
assert_order "$korean_readme" '## 스킬 동작' '## 업데이트·제거·복원'
assert_order "$korean_readme" '## 업데이트·제거·복원' '## 유지보수자 안내'

assert_contains "$agents_file" '`README.md` is the English document and `README-ko.md` is its Korean counterpart.'
assert_contains "$agents_file" 'Neither language is a fixed source.'
assert_contains "$agents_file" 'A normal modification candidate is a file with exactly ` M`, `M `, or `MM` status.'
assert_contains "$agents_file" 'then pass `tests/test-readme-sync.sh`.'
assert_contains "$agents_file" '`locales/ko/dockerize/SKILL.md` and `skills/dockerize/SKILL.md`'
assert_contains "$agents_file" 'Do not edit the globally installed copy at `$HOME/.agents/skills/dockerize` directly.'
assert_absent "$korean_readme" '한글 원본'

for path in "$english_readme" "$agents_file"; do
  assert_absent "$path" '/home/example'
  assert_absent "$path" 'docs/superpowers'
done

english_blocks="$(mktemp "${TMPDIR:-/tmp}/dockerize-readme-english.XXXXXX")"
korean_blocks="$(mktemp "${TMPDIR:-/tmp}/dockerize-readme-korean.XXXXXX")"
cleanup() {
  rm -f -- "$english_blocks" "$korean_blocks"
}
trap cleanup EXIT

extract_fenced_blocks() {
  awk '
    /^```/ {
      inside = !inside
      print
      next
    }
    inside { print }
    END { if (inside) exit 2 }
  ' "$1"
}

extract_fenced_blocks "$english_readme" >"$english_blocks"
extract_fenced_blocks "$korean_readme" >"$korean_blocks"
cmp -s -- "$english_blocks" "$korean_blocks" ||
  fail 'English and Korean README code blocks differ'

english_level_two="$(grep -c '^## ' "$english_readme")"
korean_level_two="$(grep -c '^## ' "$korean_readme")"
[[ "$english_level_two" == "$korean_level_two" ]] ||
  fail 'English and Korean README top-level section counts differ'

printf 'Bilingual README synchronization tests passed.\n'
