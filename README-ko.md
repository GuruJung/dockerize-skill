# Dockerize Skill

[English](README.md)

Dockerize Skill은 전역 패키지, 가상환경, `node_modules`, 생성 파일, 서비스 포트,
데이터베이스, 큐, 캐시, ML 모델 또는 GPU 도구로 호스트를 오염시키지 않고 Docker Compose
환경을 구축하는 Codex 스킬이다.

파일을 생성하기 전에 프로젝트를 조사하고 종료형 작업 또는 장기 실행 서비스에 맞게 결과를
조정하며, 생성한 워크플로를 Compose로 재현 가능하게 유지한다. 이 저장소는 의미가 동등한
한글·영문 스킬 지침, 재사용 가능한 template과 reference, 안전한 전역 설치 도구 및 회귀
테스트를 제공한다.

## 설치

Linux와 macOS에는 Bash 3.2 이상과 `sha256sum` 또는 `shasum`이 필요하다. Windows에는
Windows PowerShell 5.1 이상이 필요하다. 관리자 권한이나 서드파티 패키지는 필요하지 않다.

Linux 또는 macOS에서는 저장소를 clone하고 스킬을 설치한 뒤 entry point가 있는지 확인한다.

```bash
git clone https://github.com/GuruJung/dockerize-skill.git
cd dockerize-skill
./scripts/install.sh
test -f "$HOME/.agents/skills/dockerize/SKILL.md"
```

Windows PowerShell에서는 다음과 같이 실행한다.

```powershell
git clone https://github.com/GuruJung/dockerize-skill.git
Set-Location dockerize-skill
.\scripts\install.ps1
Test-Path (Join-Path $HOME '.agents/skills/dockerize/SKILL.md')
```

설치기는 먼저 한영 동기화 상태를 검사한 다음 영어 `skills/dockerize` 디렉터리만
`$HOME/.agents/skills/dockerize`로 복사한다. 한글 대응본, 개발 지침과 동기화 metadata는
설치하지 않는다. Codex가 설치된 스킬을 인식하지 못하면 새 세션을 시작한다.

두 설치기는 기본적으로 `$HOME/.agents`를 사용한다. 격리 또는 사용자 지정 위치에는 Bash의
`--agents-root <path>` 또는 PowerShell의 `-AgentsRoot <path>`를 사용한다.

## 빠른 시작

원하는 프로젝트 결과를 설명하면서 Codex에 스킬 사용을 요청한다. `$`는 스킬 이름의
일부이며 아래 예시는 셸 명령이 아니라 Codex 프롬프트다.

```text
$dockerize Add a Docker Compose setup for this project while avoiding host pollution.
```

live editing, 호스트에서 보여야 하는 출력, GPU 지원, 공유 model cache 또는 호스트에서
접근해야 하는 특정 서비스 같은 제약을 함께 제시할 수 있다. 중요한 storage나 runtime 선택을
안전하게 추론할 수 없으면 스킬이 파일을 생성하기 전에 질문한다.

## 스킬 동작

이 스킬은 하나의 고정 Compose layout을 적용하지 않고 프로젝트에 맞춰 작업한다.

- Docker 파일을 작성하기 전에 dependency manifest, entry point, command, output, side
  service, port, GPU 필요 여부, 대용량 asset과 Hugging Face 사용 여부를 조사한다.
- 일반적으로 전체 checkout을 bind mount하지 않고 소스를 이미지에 복사하며,
  `.dockerignore`를 일찍 만든다.
- 종료형 command와 계속 작업을 기다리는 process를 구분한다. lifecycle wrapper는 장기 실행
  stack에만 추가하고 종료형 workload에는 `docker compose run --rm`을 사용한다.
- 영속 output과 data에는 named volume을 사용하고, 사용자가 호스트 접근을 요구하면 export
  wrapper를 추가하며, 선택한 대용량 cache를 중복하지 않고 worktree를 격리할 수 있게 한다.
- 프로젝트 dependency를 호스트에 설치하지 않고 Compose를 통해 검증한다.

생성한 환경은 다음 안전 경계를 지킨다.

- secret과 로컬 전용 설정을 이미지에 복사하지 않는다. 대신 runtime environment 또는
  대상이 제한된 read-only mount를 사용한다.
- 직접 호스트 접근이 필요하지 않으면 데이터베이스, 큐, object store와 cache를 Compose
  내부 network에 유지한다.
- service가 존재한다는 이유만으로 host port를 publish하지 않는다.
- 선택한 base image나 프로젝트가 깔끔하게 지원할 때 non-root container를 사용하며,
  구성을 취약하게 만들 때는 강제하지 않는다.
- Hugging Face 프로젝트는 기본적으로 안정적인 공용 external `HF_HOME` volume을 사용하고,
  `HF_TOKEN`, host cache 재사용, ownership과 worktree naming을 명시적으로 처리한다.
- training, finetuning, inference, CUDA 또는 호환 ML stack에 필요하면 GPU 지원을 추가한다.

상세 동작 계약은 `skills/dockerize/SKILL.md`에 있고 주제별 지침은
`skills/dockerize/references/`에 있다.

## 업데이트·제거·복원

### 업데이트

원하는 저장소 revision을 받은 뒤 설치기를 다시 실행한다. 설치본이 동일하면 backup을 만들지
않고 종료한다.

```bash
git pull --ff-only
./scripts/install.sh
```

```powershell
git pull --ff-only
.\scripts\install.ps1
```

설치 내용이 다르면 설치기가 교체본을 staging하고 검증한 뒤 현재 설치본을 backup하고 새
복사본을 승격한다. `$HOME/.agents/skill-backups/dockerize` 아래에 최근 관리 backup 5개를
유지하며 승격 실패 시 이전 설치본을 복원한다. 관리 대상 위치의 file이나 symbolic link는
덮어쓰지 않고 거부한다.

### 제거

```bash
./scripts/uninstall.sh
```

```powershell
.\scripts\uninstall.ps1
```

제거 시 현재 설치본을 backup 디렉터리로 옮긴다. 스킬이 설치되어 있지 않으면 변경 없이
성공한다.

### Backup 수동 복원

먼저 `$HOME/.agents/skills/dockerize`가 없는지 확인한 뒤 `<backup-name>` 하나를 선택한다.
Linux 또는 macOS에서는 다음과 같이 실행한다.

```bash
mkdir -p "$HOME/.agents/skills"
cp -R "$HOME/.agents/skill-backups/dockerize/<backup-name>" "$HOME/.agents/skills/dockerize"
```

Windows PowerShell에서는 다음과 같이 실행한다.

```powershell
New-Item -ItemType Directory -Path (Join-Path $HOME '.agents/skills') -Force
Copy-Item -Recurse -LiteralPath (Join-Path $HOME '.agents/skill-backups/dockerize/<backup-name>') -Destination (Join-Path $HOME '.agents/skills/dockerize')
```

복원한 디렉터리를 검증하고 스킬을 인식하지 못하면 새 Codex 세션을 시작한다.

## 유지보수자 안내

### 저장소 구조

- 한글 스킬: `locales/ko/dockerize/SKILL.md`
- 영문 설치 스킬: `skills/dockerize/SKILL.md`
- 번역 상태: `sync/dockerize.sha256`
- Template 및 reference: `skills/dockerize/assets/` 및 `skills/dockerize/references/`
- 저장소 규칙: `AGENTS.md`

일반적인 스킬 형식은 공식
[Build skills 문서](https://learn.chatgpt.com/docs/build-skills)를 참고한다.

### README 번역 동기화

`README.md`와 `README-ko.md`는 의미와 강도, 구조, 명령, 경로, 식별자와 제약을 동일하게
유지해야 한다. 어느 언어도 고정 편집 원본은 아니다.

기존 tracked 쌍에서는 의도한 원본을 먼저 수정한다. 대응본을 번역하기 전에 두 파일의 Git
상태와 filesystem mtime을 한 번 snapshot한다. Linux에서는 다음과 같이 실행한다.

```bash
git status --short -- README.md README-ko.md
stat -c '%y %n' -- README.md README-ko.md
```

macOS에서는 BSD `stat`을 사용한다.

```bash
git status --short -- README.md README-ko.md
stat -f '%.9Fm %N' -- README.md README-ko.md
```

Windows PowerShell에서는 다음과 같이 실행한다.

```powershell
git status --short -- README.md README-ko.md
Get-Item README.md, README-ko.md | Select-Object FullName, @{Name='LastWriteTimeUtcTicks'; Expression={$_.LastWriteTimeUtc.Ticks}}
```

정상 원본 후보는 정확히 ` M`, `M ` 또는 `MM` 상태다. 후보가 하나이면 해당 파일을 원본으로
사용하고 둘이면 snapshot한 mtime이 더 최신인 파일을 사용한다. clean 쌍은 동기화 대상이
아니다. mtime이 같거나 어느 파일에 `A`, `D`, `R`, `U`, untracked 또는 다른 non-`M`
변경이 있으면 중단하고 사용자의 명시적 선택을 받는다.

동기화가 끝날 때까지 원본 선정을 고정하고, 전체 대응본을 번역하고, 두 문서를 대조한 뒤
`tests/test-readme-sync.sh`를 실행한다. 테스트는 구조와 핵심 계약의 동등성을 검사하지만 의미
검토를 대신하지 않는다.

### 스킬 번역 편집과 동기화

tracked `SKILL.md` 중 하나를 편집하기 전에 두 파일의 Git 상태와 filesystem mtime을 한 번
확인한다. `HEAD` 대비 modified인 기존 파일만 후보로 삼는다. 후보가 하나이면 해당 파일,
둘이면 더 최신인 파일을 선택한다. 두 파일이 clean이면 요청에 자연스러운 언어로 시작한다.
파일 누락, 후보 mtime 동률, 삭제, rename, unmerged 또는 다른 안전하지 않은 상태에서는
중단한다.

작업 중 선정한 원본을 고정한다. 규칙, 조건, 우선순위와 목록 순서를 동일하게 유지하고 명령,
경로, 환경 변수와 코드 keyword를 보존해 다른 `SKILL.md`를 번역한다.
`$HOME/.agents/skills/dockerize`를 직접 편집하지 않는다.

의미를 대조한 뒤 동기화 상태를 기록·검사하고 전체 suite를 실행한다.

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

Windows PowerShell에서는 다음 명령으로 동기화 상태를 기록하고 검사한다.

```powershell
.\scripts\record-sync.ps1
.\scripts\check-sync.ps1
```

manifest는 마지막 의미 검토 후 어느 스킬 파일도 바뀌지 않았다는 점만 증명하며 번역 품질을
증명하지 않는다. manifest가 없거나 손상됐거나 stale이면 검사와 설치가 차단된다. references,
assets, `agents/openai.yaml`, 설치 도구 또는 저장소 문서만 바꾸는 작업에는 스킬 번역 동기화를
적용하지 않는다. 스킬 범위나 기본 프롬프트가 바뀌면
`skills/dockerize/agents/openai.yaml`을 별도로 검토한다.

현재 Linux 개발 환경에서는 PowerShell 스크립트를 실행하지 않고 정적으로 검토한다.

### 안전한 스킬 개선

다른 프로젝트에서 문제를 발견했을 때 전역 설치본을 직접 편집하지 않는다. consumer
프로젝트의 작업을 보존하고, 스킬 이름과 저장소 commit, invocation, 예상·실제 동작, 최소
재현, 관련 output과 diff 및 작업 차단 여부를 보고한다. 이 저장소에서 수정하고 검증하며,
후보 변경에는 feature worktree를 사용하고, 검증한 결과를 `main`에 통합한 다음 설치기로
설치본을 갱신한다.

이 프로젝트는 [MIT License](LICENSE)로 배포한다.
