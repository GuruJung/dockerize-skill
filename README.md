# Dockerize 스킬 개발

이 저장소는 개인용 `dockerize` 스킬의 의미가 동등한 한국어본과 영어본을 관리한다. 사용자가 미리 수정한 파일이 있으면 작업 시작 시 Git 상태와 mtime으로 해당 작업의 정본을 판정하며, Codex가 실제로 읽고 전역 설치하는 파일은 영어본이다.

- 한국어 스킬: `locales/ko/dockerize/SKILL.md`
- 영어 배포본: `skills/dockerize/SKILL.md`
- 동기화 상태: `sync/dockerize.sha256`
- 저장소 작업 규칙: `AGENTS.md`

Codex의 사용자 스킬 설치 위치는 `$HOME/.agents/skills`이다. 자세한 내용은 공식 [Build skills 문서](https://learn.chatgpt.com/docs/build-skills)를 참고한다.

## 요구사항

- Linux/macOS에서는 Bash 3.2 이상과 `sha256sum` 또는 `shasum`이 필요하다.
- Windows에서는 Windows PowerShell 5.1 이상이 필요하다.
- 관리자 권한이나 서드파티 패키지는 필요하지 않는다.
- 현재 Linux 개발 환경에서는 PowerShell 스크립트를 실행하지 않고 정적으로 검토한다.

## 스킬 수정 흐름

이 저장소에서는 `AGENTS.md`에 따라 다음 순서로 작업한다.

1. 두 `SKILL.md`를 편집하기 전에 HEAD 대비 staged 또는 unstaged modified 상태와 filesystem mtime을 한 번 확인한다.
2. modified 후보가 하나면 그 파일을, 둘이면 mtime이 더 최신인 파일을 해당 작업의 정본으로 선택한다.
3. 후보가 없으면 요청에 자연스러운 언어로 시작한다. exact mtime 동률, 파일 누락 또는 modified 이외의 삭제·rename·unmerged 등 안전하지 않은 Git 상태에서는 사용자에게 정본 또는 복구 방법을 묻는다.
4. 선택한 정본의 규칙과 조건을 보존해 다른 언어의 `SKILL.md`를 의미가 동등한 명령문으로 맞춘다. 작업 중 바뀐 mtime으로 정본을 다시 판정하지 않는다.
5. 두 파일의 의미 동등성을 검토하고 동기화 해시를 기록·검사한 뒤, 양쪽 스킬과 전체 회귀 테스트를 실행한다.

`$HOME/.agents/skills/dockerize`의 설치본은 직접 수정하지 않는다. References, assets 및 `agents/openai.yaml`은 영어 단일본으로 관리한다.

## 동기화 기록과 검사

번역의 의미 동등성을 검토한 뒤에만 다음 명령을 실행한다.

```bash
./scripts/record-sync.sh
./scripts/check-sync.sh
```

PowerShell에서는 다음과 같다.

```powershell
.\scripts\record-sync.ps1
.\scripts\check-sync.ps1
```

Record 명령은 두 파일의 SHA-256을 `sync/dockerize.sha256`에 원자적으로 기록한다. 해시는 번역 품질을 판단하지 않으며, 마지막 의미 검토 후 어느 한쪽이 변경되었는지만 검출한다.

동기화 manifest가 없거나 손상되었거나 실제 파일과 일치하지 않으면 검사와 전역 설치가 모두 실패한다.

## 검증과 설치

```bash
python "$HOME/.codex/skills/.system/skill-creator/scripts/quick_validate.py" locales/ko/dockerize
python "$HOME/.codex/skills/.system/skill-creator/scripts/quick_validate.py" skills/dockerize
./scripts/check-sync.sh
./scripts/install.sh
```

PowerShell에서는 다음 명령으로 설치한다.

```powershell
.\scripts\install.ps1
```

설치기는 동기화를 먼저 검사한 뒤 영어 `skills/dockerize` 폴더만 `$HOME/.agents/skills/dockerize`에 복사한다. 한국어 스킬 파일, 동기화 파일 및 개발 지침은 설치본에 포함되지 않는다.

두 설치기는 기본적으로 `$HOME/.agents`를 사용한다. 격리 테스트나 사용자 지정 위치에는 Bash의 `--agents-root <path>` 또는 PowerShell의 `-AgentsRoot <path>`를 사용한다.

설치본이 영어 배포본과 같으면 아무 작업도 하지 않는다. 내용이 다르면 새 복사본을 staging하고 검증한 뒤 기존 설치본을 백업하고 교체한다. 최근 관리 백업 5개를 `$HOME/.agents/skill-backups/dockerize`에 유지하며, 대상 위치의 파일이나 링크는 덮어쓰지 않는다.

## 제거

```bash
./scripts/uninstall.sh
```

```powershell
.\scripts\uninstall.ps1
```

제거 명령은 현재 설치본을 백업 폴더로 옮긴다. 이미 설치되어 있지 않으면 변경 없이 성공한다.

## 백업 수동 복원

먼저 `$HOME/.agents/skills/dockerize`가 없는지 확인한 뒤 백업 하나를 선택한다. Bash에서는 다음과 같이 복원한다.

```bash
mkdir -p "$HOME/.agents/skills"
cp -R "$HOME/.agents/skill-backups/dockerize/<backup-name>" "$HOME/.agents/skills/dockerize"
```

PowerShell에서는 다음과 같다.

```powershell
New-Item -ItemType Directory -Path (Join-Path $HOME '.agents/skills') -Force
Copy-Item -Recurse -LiteralPath (Join-Path $HOME '.agents/skill-backups/dockerize/<backup-name>') -Destination (Join-Path $HOME '.agents/skills/dockerize')
```

복원한 폴더를 검증한다. Codex는 보통 스킬 변경을 자동 감지하지만 나타나지 않으면 Codex를 재시작한다.

## 테스트

Bash 테스트는 임시 디렉터리만 사용하며 실제 홈 디렉터리를 변경하지 않는다.

```bash
bash -n scripts/*.sh tests/test-install.sh
./scripts/check-sync.sh
bash tests/test-install.sh
```
