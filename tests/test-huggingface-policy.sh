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

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd -P)"
korean_skill="$repo_root/locales/ko/dockerize/SKILL.md"
english_skill="$repo_root/skills/dockerize/SKILL.md"
ml_reference="$repo_root/skills/dockerize/references/ml.md"
compose_template="$repo_root/skills/dockerize/assets/compose.yaml.template"
volume_preamble="$repo_root/skills/dockerize/assets/compose-hf-volume-preamble.sh.template"
bind_preamble="$repo_root/skills/dockerize/assets/compose-hf-bind-linux-preamble.sh.template"

for path in "$korean_skill" "$english_skill" "$ml_reference" "$compose_template"; do
  assert_contains "$path" 'HF_CACHE_VOLUME_NAME'
  assert_contains "$path" 'HF_TOKEN'
done
for path in "$korean_skill" "$english_skill" "$ml_reference"; do
  assert_contains "$path" 'HF_CACHE_DIR'
  assert_contains "$path" 'HOST_UID'
  assert_contains "$path" 'HOST_GID'
done

assert_contains "$korean_skill" 'main worktree'
assert_contains "$english_skill" 'main worktree'
assert_contains "$ml_reference" 'external: true'
assert_contains "$compose_template" 'name: ${HF_CACHE_VOLUME_NAME:-replace-with-main-project-name_hf-cache}'
assert_contains "$compose_template" 'external: true'
for path in "$korean_skill" "$english_skill" "$ml_reference" "$compose_template"; do
  assert_absent "$path" '${HF_CACHE_VOLUME_NAME:-${COMPOSE_PROJECT_NAME}_hf-cache}'
done

test_root="$(mktemp -d "${TMPDIR:-/tmp}/dockerize-hf-policy-tests.XXXXXX")"
cleanup() {
  case "$test_root" in
    "${TMPDIR:-/tmp}"/dockerize-hf-policy-tests.*) rm -rf -- "$test_root" ;;
    *) printf 'Refusing unsafe test cleanup: %s\n' "$test_root" >&2 ;;
  esac
}
trap cleanup EXIT

fake_bin="$test_root/fake-bin"
mkdir -p -- "$fake_bin"
cat >"$fake_bin/docker" <<'FAKE_DOCKER'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$FAKE_DOCKER_LOG"
case "${1:-} ${2:-}" in
  'volume inspect')
    [[ -f "$FAKE_DOCKER_STATE" ]]
    ;;
  'volume create')
    [[ "${FAKE_DOCKER_CREATE_FAIL:-0}" != 1 ]] || exit 1
    touch "$FAKE_DOCKER_STATE"
    ;;
  *)
    exit 97
    ;;
esac
FAKE_DOCKER
chmod 0755 "$fake_bin/docker"

docker_log="$test_root/docker.log"
docker_state="$test_root/docker.state"
for iteration in 1 2; do
  PATH="$fake_bin:$PATH" \
    FAKE_DOCKER_LOG="$docker_log" \
    FAKE_DOCKER_STATE="$docker_state" \
    HF_CACHE_VOLUME_NAME='shared-hf-cache' \
    bash -c 'source "$1"; [[ "$HF_CACHE_VOLUME_NAME" == shared-hf-cache ]]' \
    bash "$volume_preamble"
done
[[ "$(grep -Fc 'volume create shared-hf-cache' "$docker_log")" == 1 ]] ||
  fail 'shared Hugging Face volume was not created exactly once'
[[ "$(grep -Fc 'volume inspect shared-hf-cache' "$docker_log")" == 2 ]] ||
  fail 'shared Hugging Face volume was not inspected on every run'

rm -f -- "$docker_log" "$docker_state"
PATH="$fake_bin:$PATH" \
  FAKE_DOCKER_LOG="$docker_log" \
  FAKE_DOCKER_STATE="$docker_state" \
  bash -c 'unset HF_CACHE_VOLUME_NAME; source "$1"; [[ "$HF_CACHE_VOLUME_NAME" == replace-with-main-project-name_hf-cache ]]' \
  bash "$volume_preamble"
assert_contains "$docker_log" 'volume create replace-with-main-project-name_hf-cache'

rm -f -- "$docker_log" "$docker_state"
if PATH="$fake_bin:$PATH" \
    FAKE_DOCKER_LOG="$docker_log" \
    FAKE_DOCKER_STATE="$docker_state" \
    FAKE_DOCKER_CREATE_FAIL=1 \
    HF_CACHE_VOLUME_NAME='failed-hf-cache' \
    bash -c 'source "$1"' bash "$volume_preamble" >/dev/null 2>&1; then
  fail 'volume preamble accepted a failed external-volume creation'
fi

bind_home="$test_root/home"
mkdir -p -- "$bind_home"
HOME="$bind_home" bash -c '
  unset HF_CACHE_DIR HOST_UID HOST_GID
  source "$1"
  [[ "$HF_CACHE_DIR" == "$HOME/.cache/huggingface" ]]
  [[ -d "$HF_CACHE_DIR" && -w "$HF_CACHE_DIR" ]]
  [[ "$HOST_UID" == "$(id -u)" ]]
  [[ "$HOST_GID" == "$(id -g)" ]]
' bash "$bind_preamble"

custom_cache="$test_root/custom-cache"
HF_CACHE_DIR="$custom_cache" HOST_UID=1234 HOST_GID=5678 bash -c '
  source "$1"
  [[ "$HF_CACHE_DIR" == "$2" ]]
  [[ "$HOST_UID" == 1234 && "$HOST_GID" == 5678 ]]
' bash "$bind_preamble" "$custom_cache"
[[ -d "$custom_cache" ]] || fail 'custom Hugging Face bind cache was not created'

if HOME="$bind_home" HOST_UID=invalid HOST_GID=5678 \
    bash -c 'source "$1"' bash "$bind_preamble" >/dev/null 2>&1; then
  fail 'bind preamble accepted a non-numeric HOST_UID'
fi

printf 'Hugging Face policy tests passed.\n'
