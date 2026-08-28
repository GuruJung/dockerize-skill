#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_dir() {
  [[ -d "$1" && ! -L "$1" ]] || fail "expected directory: $1"
}

assert_absent() {
  [[ ! -e "$1" && ! -L "$1" ]] || fail "expected absent path: $1"
}

count_backups() {
  local root="$1" path count=0
  for path in \
    "$root"/????????T??????Z-??????-install \
    "$root"/????????T??????Z-??????-uninstall \
    "$root"/????????T??????Z-??????-migration; do
    if [[ -d "$path" && ! -L "$path" ]]; then
      count=$((count + 1))
    fi
  done
  printf '%s\n' "$count"
}

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd -P)"
install_script="$repo_root/scripts/install.sh"
uninstall_script="$repo_root/scripts/uninstall.sh"
check_sync_script="$repo_root/scripts/check-sync.sh"
record_sync_script="$repo_root/scripts/record-sync.sh"
source_dir="$repo_root/skills/dockerize"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/dockerize-skill-tests.XXXXXX")"

# Windows target discovery must use case-insensitive provider semantics. Direct
# lookup handles normal paths; parent enumeration also detects broken links.
for powershell_script in "$repo_root/scripts/install.ps1" "$repo_root/scripts/uninstall.ps1"; do
  grep -Fq 'Get-Item -LiteralPath $LiteralPath -Force -ErrorAction SilentlyContinue' "$powershell_script" ||
    fail "PowerShell direct target lookup is missing: $powershell_script"
  grep -Fq 'Where-Object { $_.Name -eq $leaf }' "$powershell_script" ||
    fail "PowerShell case-insensitive fallback lookup is missing: $powershell_script"
  if grep -Fq 'Where-Object { $_.Name -ceq $leaf }' "$powershell_script"; then
    fail "PowerShell target lookup is incorrectly case-sensitive: $powershell_script"
  fi
done

for powershell_script in "$repo_root/scripts/check-sync.ps1" "$repo_root/scripts/record-sync.ps1"; do
  grep -Fq 'Get-FileHash -LiteralPath' "$powershell_script" ||
    fail "PowerShell SHA-256 hashing is missing: $powershell_script"
done
grep -Fq 'Korean skill changed after the last semantic sync review; synchronize both skill files and record sync again' \
  "$repo_root/scripts/check-sync.ps1" ||
  fail 'PowerShell Korean stale-sync guidance is not direction-neutral'
grep -Fq 'English skill changed after the last semantic sync review; synchronize both skill files and record sync again' \
  "$repo_root/scripts/check-sync.ps1" ||
  fail 'PowerShell English stale-sync guidance is not direction-neutral'
grep -Fq "& (Join-Path \$PSScriptRoot 'check-sync.ps1')" "$repo_root/scripts/install.ps1" ||
  fail 'PowerShell installer does not enforce the sync check'
grep -Fq '[IO.File]::WriteAllText' "$repo_root/scripts/record-sync.ps1" ||
  fail 'PowerShell record command does not write its temporary manifest explicitly'
grep -Fq '[IO.File]::Replace' "$repo_root/scripts/record-sync.ps1" ||
  fail 'PowerShell record command does not atomically replace an existing manifest'

cleanup() {
  case "$test_root" in
    "${TMPDIR:-/tmp}"/dockerize-skill-tests.*) rm -rf -- "$test_root" ;;
    *) printf 'Refusing unsafe test cleanup: %s\n' "$test_root" >&2 ;;
  esac
}
trap cleanup EXIT

# Sync checking is deterministic and blocks installation before target changes.
sync_repo="$test_root/sync repo"
mkdir -p -- \
  "$sync_repo/scripts" \
  "$sync_repo/skills/dockerize" \
  "$sync_repo/locales/ko/dockerize" \
  "$sync_repo/sync"
cp "$install_script" "$check_sync_script" "$record_sync_script" "$sync_repo/scripts/"
cp "$repo_root/skills/dockerize/SKILL.md" "$sync_repo/skills/dockerize/SKILL.md"
cp "$repo_root/locales/ko/dockerize/SKILL.md" "$sync_repo/locales/ko/dockerize/SKILL.md"
cp "$repo_root/sync/dockerize.sha256" "$sync_repo/sync/dockerize.sha256"

bash "$sync_repo/scripts/check-sync.sh" >/dev/null
printf '\n<!-- synchronization test -->\n' >>"$sync_repo/locales/ko/dockerize/SKILL.md"
korean_sync_error="$test_root/korean-sync-error"
if bash "$sync_repo/scripts/check-sync.sh" >/dev/null 2>"$korean_sync_error"; then
  fail 'sync check accepted a changed Korean skill'
fi
grep -Fq 'Korean skill changed after the last semantic sync review; synchronize both skill files and record sync again' \
  "$korean_sync_error" ||
  fail 'Korean stale-sync guidance is not direction-neutral'

stale_install_root="$test_root/stale sync install"
mkdir -p -- "$stale_install_root/skills/dockerize"
printf 'must remain unchanged\n' >"$stale_install_root/skills/dockerize/sentinel"
if bash "$sync_repo/scripts/install.sh" --agents-root "$stale_install_root" >/dev/null 2>&1; then
  fail 'installer accepted stale translation hashes'
fi
[[ "$(sed -n '1p' "$stale_install_root/skills/dockerize/sentinel")" == 'must remain unchanged' ]] ||
  fail 'stale sync check changed the existing installation'

printf '\n<!-- synchronization test -->\n' >>"$sync_repo/skills/dockerize/SKILL.md"
bash "$sync_repo/scripts/record-sync.sh" >/dev/null
bash "$sync_repo/scripts/check-sync.sh" >/dev/null
cp "$sync_repo/sync/dockerize.sha256" "$test_root/manifest-first"
bash "$sync_repo/scripts/record-sync.sh" >/dev/null
cmp -s "$test_root/manifest-first" "$sync_repo/sync/dockerize.sha256" ||
  fail 'recording unchanged files produced a different manifest'

cp "$sync_repo/skills/dockerize/SKILL.md" "$test_root/english-snapshot"
cp "$sync_repo/sync/dockerize.sha256" "$test_root/manifest-snapshot"
printf '\n<!-- English-only change -->\n' >>"$sync_repo/skills/dockerize/SKILL.md"
english_sync_error="$test_root/english-sync-error"
if bash "$sync_repo/scripts/check-sync.sh" >/dev/null 2>"$english_sync_error"; then
  fail 'sync check accepted an English-only change'
fi
grep -Fq 'English skill changed after the last semantic sync review; synchronize both skill files and record sync again' \
  "$english_sync_error" ||
  fail 'English stale-sync guidance is not direction-neutral'
cp "$test_root/english-snapshot" "$sync_repo/skills/dockerize/SKILL.md"

printf 'version=1\n' >>"$sync_repo/sync/dockerize.sha256"
if bash "$sync_repo/scripts/check-sync.sh" >/dev/null 2>&1; then
  fail 'sync check accepted a duplicate manifest key'
fi
cp "$test_root/manifest-snapshot" "$sync_repo/sync/dockerize.sha256"
mv "$sync_repo/sync/dockerize.sha256" "$sync_repo/sync/dockerize.sha256.missing"
if bash "$sync_repo/scripts/check-sync.sh" >/dev/null 2>&1; then
  fail 'sync check accepted a missing manifest'
fi

agents_root="$test_root/agents root"
target="$agents_root/skills/dockerize"
backup_root="$agents_root/skill-backups/dockerize"

# Fresh install and an identical idempotent update.
bash "$install_script" --agents-root "$agents_root"
assert_dir "$target"
diff -qr "$source_dir" "$target" >/dev/null || fail 'fresh install differs from source'
bash "$install_script" --agents-root "$agents_root"
[[ "$(count_backups "$backup_root")" == 0 ]] || fail 'idempotent install created a backup'

# Changed installations are backed up and only the newest five managed backups remain.
mkdir -p -- "$backup_root/keep-me"
for iteration in 1 2 3 4 5 6; do
  printf 'local change %s\n' "$iteration" >>"$target/SKILL.md"
  bash "$install_script" --agents-root "$agents_root"
  diff -qr "$source_dir" "$target" >/dev/null || fail "update $iteration differs from source"
done
[[ "$(count_backups "$backup_root")" == 5 ]] || fail 'backup retention did not keep exactly five managed backups'
assert_dir "$backup_root/keep-me"
newest_install_backup="$(find "$backup_root" -mindepth 1 -maxdepth 1 -type d -name '????????T??????Z-??????-install' | sort | tail -n 1)"
[[ "$(tail -n 1 "$newest_install_backup/SKILL.md")" == 'local change 6' ]] || fail 'latest update backup did not preserve the replaced installation'

# Uninstall backs up the installation, preserves the five-backup limit, and is idempotent.
bash "$uninstall_script" --agents-root "$agents_root"
assert_absent "$target"
[[ "$(count_backups "$backup_root")" == 5 ]] || fail 'uninstall did not preserve five-backup retention'
uninstall_backups=("$backup_root"/????????T??????Z-??????-uninstall)
[[ -d "${uninstall_backups[0]}" ]] || fail 'uninstall backup was pruned instead of an older backup'
diff -qr "$source_dir" "${uninstall_backups[0]}" >/dev/null || fail 'uninstall backup differs from the removed installation'
bash "$uninstall_script" --agents-root "$agents_root"

# File and symbolic-link conflicts are refused without changing their contents or targets.
conflict_root="$test_root/file conflict"
mkdir -p -- "$conflict_root/skills"
printf 'keep this file\n' >"$conflict_root/skills/dockerize"
if bash "$install_script" --agents-root "$conflict_root" >/dev/null 2>&1; then
  fail 'installer accepted a file target'
fi
[[ "$(sed -n '1p' "$conflict_root/skills/dockerize")" == 'keep this file' ]] || fail 'file conflict was modified'

link_root="$test_root/link conflict"
outside_dir="$test_root/outside target"
mkdir -p -- "$link_root/skills" "$outside_dir"
printf 'outside sentinel\n' >"$outside_dir/sentinel"
ln -s "$outside_dir" "$link_root/skills/dockerize"
if bash "$install_script" --agents-root "$link_root" >/dev/null 2>&1; then
  fail 'installer accepted a symbolic-link target'
fi
if bash "$uninstall_script" --agents-root "$link_root" >/dev/null 2>&1; then
  fail 'uninstaller accepted a symbolic-link target'
fi
[[ -L "$link_root/skills/dockerize" ]] || fail 'symbolic-link conflict was removed'
[[ "$(sed -n '1p' "$outside_dir/sentinel")" == 'outside sentinel' ]] || fail 'symbolic-link destination was modified'

# A missing source SKILL.md fails before changing an existing installation.
broken_repo="$test_root/broken repo"
mkdir -p -- "$broken_repo/scripts" "$broken_repo/skills/dockerize"
cp "$install_script" "$broken_repo/scripts/install.sh"
broken_root="$test_root/broken source root"
mkdir -p -- "$broken_root/skills/dockerize"
printf 'existing installation\n' >"$broken_root/skills/dockerize/sentinel"
if bash "$broken_repo/scripts/install.sh" --agents-root "$broken_root" >/dev/null 2>&1; then
  fail 'installer accepted a source without SKILL.md'
fi
[[ "$(sed -n '1p' "$broken_root/skills/dockerize/sentinel")" == 'existing installation' ]] || fail 'invalid source changed the installation'

# If promotion fails after backup, the previous installation is restored.
rollback_root="$test_root/rollback root"
bash "$install_script" --agents-root "$rollback_root"
printf 'must survive rollback\n' >"$rollback_root/skills/dockerize/rollback-sentinel"
fake_bin="$test_root/fake bin"
mkdir -p -- "$fake_bin"
real_mv="$(command -v mv)"
cat >"$fake_bin/mv" <<'FAKE_MV'
#!/usr/bin/env bash
set -euo pipefail
count=0
if [[ -f "$FAKE_MV_COUNT_FILE" ]]; then
  count="$(sed -n '1p' "$FAKE_MV_COUNT_FILE")"
fi
count=$((count + 1))
printf '%s\n' "$count" >"$FAKE_MV_COUNT_FILE"
if [[ "$count" == 2 ]]; then
  exit 1
fi
exec "$REAL_MV" "$@"
FAKE_MV
chmod 0755 "$fake_bin/mv"
if PATH="$fake_bin:$PATH" REAL_MV="$real_mv" FAKE_MV_COUNT_FILE="$test_root/mv-count" \
    bash "$install_script" --agents-root "$rollback_root" >/dev/null 2>&1; then
  fail 'installer unexpectedly succeeded when promotion failed'
fi
assert_dir "$rollback_root/skills/dockerize"
[[ "$(sed -n '1p' "$rollback_root/skills/dockerize/rollback-sentinel")" == 'must survive rollback' ]] || fail 'promotion failure did not restore the previous installation'

printf 'All Bash installer tests passed.\n'
