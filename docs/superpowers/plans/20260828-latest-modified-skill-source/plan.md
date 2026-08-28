---
feature_id: 20260828-latest-modified-skill-source
title: Git 상태와 mtime 기반 SKILL 정본 선택
feature_type: standard
base_branch: main
plan_path: docs/superpowers/plans/20260828-latest-modified-skill-source/plan.md
smoke_threshold_seconds: 60
execution_handoff:
  skill: save-dev-plan
  authorization: explicit-user-selection
  automatic_trigger: implement-this-plan
  continuation: save-only
---

# Git 상태와 mtime 기반 SKILL 정본 선택

## Summary

한국어본을 영구적인 유일 정본으로 삼던 정책을 폐지한다. 작업 시작 시 Git에서 modified인 한·영 `SKILL.md` 중 mtime이 가장 최신인 파일을 해당 작업의 의도 정본으로 선택하고, 다른 파일을 의미 동등하게 맞춘다. 별도 판정 도구는 추가하지 않는다.

## Implementation Changes

- `AGENTS.md`의 작업 계약을 다음과 같이 변경한다.
  - 두 `SKILL.md`를 편집하기 전에 staged·unstaged modified 상태와 filesystem mtime을 한 번 스냅샷으로 확인한다.
  - 후보가 하나면 해당 파일, 둘이면 더 최신인 파일을 작업별 정본으로 선택한다.
  - 후보가 없으면 요청에 자연스러운 언어로 시작하고, exact mtime 동률이면 사용자에게 정본을 묻는다.
  - 삭제·rename·unmerged·파일 누락처럼 안전하게 판정할 수 없는 상태에서는 작업을 중단하고 사용자 확인을 받는다.
  - 정본 선택 후 상대 언어 파일에 규칙, 조건, 우선순위, 목록 순서와 비번역 식별자를 보존해 반영한다. 작업 중 에이전트가 바꾼 mtime으로 정본을 재판정하지 않는다.
- `README.md`에서 한국어 유일 정본 표현과 한국어 우선 절차를 제거하고 같은 양방향 작업 흐름을 사용자 문서로 설명한다. 영어본은 계속 설치·배포 대상임을 구분한다.
- `check-sync.sh`와 `check-sync.ps1`의 한국어 우선 방향성을 가진 오류 문구를 양방향 동기화 문구로 바꾼다. manifest 형식, 해시 판정, 설치 동작 및 `record-sync` 인터페이스는 유지한다.
- 기존 회귀 테스트에서 한국어 또는 영어 어느 한쪽이 stale이어도 중립적인 동기화 안내와 함께 실패하는지 검증한다.
- 두 `SKILL.md`, `sync/dockerize.sha256`, 전역 설치본 및 `skills/dockerize/agents/openai.yaml`은 변경하지 않는다.

## Interfaces and Acceptance

- 공개 코드 API 추가는 없다. 변경되는 인터페이스는 저장소 기여자가 따르는 authoring contract와 sync-check 오류 메시지뿐이다.
- 독립 검토자는 한국어 선작성 의무와 영어 단독 수정 금지가 제거되었는지, 양방향 선택·동률·clean·비정상 Git 상태 처리가 모순 없이 문서화되었는지 확인한다.
- 기존 의미 동등성 검토, `record-sync`, `check-sync`, 양쪽 `quick_validate.py`, 전체 회귀 테스트 순서는 유지되어야 한다.
- 현재 무관한 `.ipynb_checkpoints/`는 건드리거나 커밋하지 않는다.

## Test Plan

다음 명령이 모두 exit code 0이어야 한다. 현재 전체 묶음은 60초 smoke threshold 이내 실행 가능함을 확인했다.

```bash
git diff --check
./scripts/check-sync.sh
python "$HOME/.codex/skills/.system/skill-creator/scripts/quick_validate.py" locales/ko/dockerize
python "$HOME/.codex/skills/.system/skill-creator/scripts/quick_validate.py" skills/dockerize
bash -n scripts/*.sh tests/*.sh
bash tests/test-install.sh
bash tests/test-huggingface-policy.sh
```

회귀 테스트는 한국어-only stale와 영어-only stale를 각각 만들고, 두 경우 모두 방향 중립적인 오류를 반환하며 설치가 진행되지 않는지 확인한다.

## User Decisions

| 주제 | 선택 | 이유·트레이드오프 | 적용 범위 |
|---|---|---|---|
| 작업별 정본 | modified 후보 중 mtime이 가장 최신인 파일 | 최신 수정본에 사용자의 의도가 담겨 있다는 판단 | 한·영 `SKILL.md` 동기화 작업 |
| 구현 수준 | 작업 지침과 문서 중심, helper 미추가 | 별도 이유 미제시 | `AGENTS.md`, `README.md`, 기존 검사 문구와 테스트 |
| 후보가 없는 경우 | 요청에 자연스러운 언어로 자유롭게 시작 | 별도 이유 미제시 | 작업 시작 시 두 파일이 모두 clean인 경우 |
| mtime 동률 | 사용자에게 정본 질문 | 별도 이유 미제시 | 둘 이상의 modified 후보가 exact 동률인 경우 |
| modified 범위 | staged와 unstaged 변경 모두 포함 | 별도 이유 미제시 | HEAD 대비 기존 파일의 Git 변경 상태 |
| 일반 AI 지시 | 별도 작업 방식으로 문서화하지 않음 | 별도 지침 없이도 이미 가능함 | authoring workflow 문서 |

## Assumptions

- mtime은 각 파일시스템이 제공하는 최고 정밀도의 modification timestamp를 의미한다.
- modified가 아닌 파일의 더 최신 mtime은 정본 선택에 영향을 주지 않는다.
- 이 변경은 authoring workflow 전환이며 설치 형식, 배포 대상 및 런타임 스킬 동작의 migration이나 rollout을 요구하지 않는다.

> 호스트의 “Implement this plan”을 선택하면 Default 모드로 전환되고 `$save-dev-plan`에 `<git-common-dir>/dev-plan-workflow/` 아래 임시 저장만 위임됩니다. 이는 구현, branch/worktree 생성 또는 `$implement-dev-plan` 실행을 허가하지 않습니다. 계획은 사용자가 `$implement-dev-plan 20260828-latest-modified-skill-source`를 명시적으로 호출한 뒤에만 feature worktree의 `docs/superpowers/plans/20260828-latest-modified-skill-source/plan.md`로 승격·커밋됩니다. 자동 handoff가 시작되지 않거나 호스트에 native implementation action이 없다면 Default 모드로 전환해 `$save-dev-plan`을 명시적으로 호출해야 합니다. Plan 모드를 유지하면 아무것도 저장하지 않습니다.
