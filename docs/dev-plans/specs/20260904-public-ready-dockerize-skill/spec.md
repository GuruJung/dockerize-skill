---
feature_id: 20260904-public-ready-dockerize-skill
title: Dockerize 스킬 공개 저장소 준비
feature_type: standard
current_spec_path: docs/dev-plans/current-spec.md
---

# Dockerize 스킬 공개 저장소 준비

## 요약

`dockerize` 스킬 저장소를 향후 공개 배포에 적합한 형태로 정비한다. 영문 사용자 문서를 기본 진입점으로 만들고 동등한 한글 문서를 제공하며, 기여 지침·라이선스·검증을 공개 독자 기준으로 정리한다. 검증된 `main`은 `GuruJung/dockerize-skill` private GitHub 저장소에 최초 push하되 이번 작업에서 public으로 전환하지 않는다.

## 요구사항과 제외 사항

- `README.md`를 영문 기본 문서로 재작성하고 의미와 강도가 같은 `README-ko.md`를 추가한다. 두 문서 상단에서 상대 언어 문서로 연결한다.
- README는 다음 순서로 동일한 정보를 제공한다.
  1. 프로젝트 목적과 Dockerize 스킬의 주요 기능
  2. Linux/macOS 및 Windows 설치와 설치 확인
  3. `$dockerize` 빠른 시작과 예시 프롬프트
  4. 호스트 오염 방지, secret, volume, GPU/Hugging Face 등 주요 동작 경계
  5. 업데이트·제거·백업 복원
  6. 스킬 번역 동기화와 검증을 포함한 유지보수자 안내
- clone 명령은 `https://github.com/GuruJung/dockerize-skill.git`을 사용하고 `/home/example` 같은 사용자별 절대 경로를 공개 문서에서 제거한다.
- 기존 README의 실질적인 설치·동기화·복구 정보는 삭제하지 않고 사용자용 내용을 앞에, 유지보수자용 내용을 뒤에 재배치한다.
- 향후 기존 tracked README 쌍을 수정할 때 Git 상태와 mtime으로 작업별 원본을 안전하게 고르고, 상대 문서를 의미 동등하게 번역하는 규칙을 `AGENTS.md`에 추가한다. 고정 언어 원본은 두지 않는다.
- `AGENTS.md` 전체를 자연스러운 영어로 제공한다. 현재 Dockerize 스킬 정본 선택, 번역, 검증, 설치본 보호 규칙의 의미·강도·순서를 보존하며 `AGENTS-ko.md`는 만들지 않는다.
- `docs/superpowers/`와 남은 계획 문서를 제거한다. 해당 과거 기록은 Git 이력으로만 보존한다.
- `Copyright (c) 2026 GuruJung`의 MIT `LICENSE`를 추가한다.
- `tests/test-readme-sync.sh`를 추가하고 관련 기존 테스트를 영문 `AGENTS.md`와 양언어 README 계약에 맞춘다.
- `README.md`, `README-ko.md`, `AGENTS.md`, 라이선스 및 GitHub 저장소 구성이 새 공개 인터페이스다. `$dockerize`, `scripts/install.sh`, `scripts/uninstall.sh`, sync manifest 형식과 스킬 동작은 변경하지 않는다.
- 두 `SKILL.md`, `sync/dockerize.sha256`, templates, references, `skills/dockerize/agents/openai.yaml` 및 전역 설치본은 변경하지 않는다.
- 과거 feature branch와 worktree는 삭제하거나 push하지 않으며, GitHub 저장소를 이번 작업에서 public으로 전환하지 않는다.

## Current Spec Impact

현재 `docs/dev-plans/current-spec.md`가 없으므로 한글 초기 문서를 만든다. 새 문서의 coverage는 새 계획 시스템에서 결정한 다음 현재 의도로 제한한다.

- 저장소는 향후 공개 독자를 고려한 사용자용 문서와 재사용 가능한 라이선스를 제공한다.
- `README.md`는 영문 기본 문서, `README-ko.md`는 의미와 강도가 같은 한글 대응본이다.
- 설치·확인·빠른 시작·동작 경계를 유지보수 상세보다 먼저 안내한다.
- README 쌍은 고정 원본 없이 안전하게 선택한 수정본을 기준으로 동기화하고 자동 검사와 의미 검토를 모두 거친다.
- `AGENTS.md`는 영어로 제공하되 기존 Dockerize 스킬 authoring 안전 규칙을 보존한다.
- 현재 canonical GitHub 위치는 private `GuruJung/dockerize-skill`이며 public 전환은 별도 결정이다.

이 기능 명세를 결정 근거로 연결하며, 문서에 포함되지 않은 기존 스킬 동작이나 제약이 취소되지 않음을 명시한다.

## 사용자 결정 사항

| 주제 | 사용자 결정 | 이유·tradeoff | 적용 범위 |
|---|---|---|---|
| 공개 준비 | private 단계부터 향후 public 독자를 고려해 정비한다. | 향후 공개 저장소로 제공하기 위해서다. | 전체 저장소 |
| 기존 계획 문서 | `docs/superpowers/`를 제거한다. | 더 이상 필요하지 않기 때문이다. | tracked 문서 |
| GitHub 저장소 | `GuruJung/dockerize-skill`을 private으로 만든다. | 공개 친화적인 이름을 선택했다. | 원격 저장소 |
| 최초 push | 검증·통합된 `main`과 그 이력만 push한다. | 오래된 feature branch는 원격에 노출하지 않는다. | GitHub 초기화 |
| 라이선스 | MIT 라이선스를 도입한다. | 향후 공개 재사용 조건을 명확히 한다. | 배포·재사용 계약 |
| 사용자 문서 | 영문 `README.md`와 동등한 `README-ko.md`를 제공한다. | 다양한 GitHub 독자를 고려하기 위해서다. | README |
| 작업 지침 | `AGENTS.md`를 영문화한다. | 공개 독자가 저장소 규칙을 이해할 수 있게 하기 위해서다. | 기여·에이전트 지침 |

## 승인 기준

- 영문 README만 읽어도 설치, 설치 확인, `$dockerize` 첫 호출과 주요 안전 경계를 이해할 수 있다.
- 한글 README가 같은 구조, 명령, 경로, 식별자, 제약과 의미 강도를 제공한다.
- 영문 README와 `AGENTS.md`에 한글 또는 개인 환경 절대 경로가 남지 않는다.
- `AGENTS.md` 영문화 전후 규칙을 대조했을 때 누락, 순서 변경이나 강도 약화가 없다.
- `docs/superpowers/`가 현재 tree에서 사라지고 표준 MIT `LICENSE`가 존재한다.
- 스킬 동작과 설치·동기화 인터페이스에는 변경이 없다.
- `GuruJung/dockerize-skill`은 private이고 `origin`으로 연결되며, 원격 `main` SHA가 검증된 로컬 `main` SHA와 같다. 다른 로컬 branch는 push되지 않는다.
- 모든 eval이 통과하고 독립 리뷰에서 P0–P2 finding이 없다.
