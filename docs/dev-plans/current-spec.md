# 현재 개발 의도

## 적용 범위

이 문서는 새 개발 계획 시스템에서 결정한 아래 의도에 대해서만 기준이 된다. 이 문서에
없다는 이유로 기존 `dockerize` 스킬의 동작이나 적용 범위 밖의 제약이 취소되지는 않는다.
source code와 tests는 실제 동작의 source of truth이다.

## 공개 배포 준비

- 이 저장소는 public 독자가 설치하고 이해할 수 있는 사용자 문서, 작업 지침과
  재사용 라이선스를 제공한다.
- canonical GitHub 위치는 public `GuruJung/dockerize-skill`이며 기본 브랜치는 `main`이다.
  현재 feature branch와 worktree는 배포 대상이 아니다.
- 개인 이메일이 포함된 기존 GitHub 저장소는 private archive인
  `GuruJung/dockerize-skill-private-archive`로 보관한다. 새 저장소는 이력과 비밀정보 검사를
  통과한 `main`만 게시한 후 public으로 전환한다.
- 소유자의 Git 작성자·커미터 이메일은 `41893530+GuruJung@users.noreply.github.com`을
  사용한다. 공개 이력에는 개인 이메일과 실제 개인 환경 경로를 포함하지 않는다.
- 이력 정리 전 백업과 이전·이후 커밋 대응표는 로컬 Git 메타데이터에만 보관한다.
  기존 이력을 새 저장소에 다시 push하거나 merge하지 않는다.
- 소프트웨어와 문서는 `Copyright (c) 2026 GuruJung`의 MIT License로 제공한다.
- 사용하지 않는 `docs/superpowers/` 계획 문서는 현재 tree에 유지하지 않고 Git 이력으로만
  보존한다.

## 사용자 문서

- `README.md`는 영문 기본 문서이고 `README-ko.md`는 의미와 강도가 같은 한글 대응본이다.
  두 문서는 서로 연결되며 구조, 명령, 경로, 식별자와 제약을 동일하게 유지한다.
- 설치와 설치 확인, `$dockerize` 빠른 시작 및 주요 안전 경계를 유지보수 상세보다 먼저
  설명해 스킬을 설치하고 사용하는 독자를 우선한다.
- 고정 언어 원본은 두지 않는다. 기존 tracked README 쌍 중 안전하게 원본을 정할 수 있는
  수정본을 기준으로 대응본을 번역하며, 원본 선정이 모호하거나 의미가 일치하지 않으면
  임의로 통합하지 않는다.
- 자동 검사는 README의 구조, 언어 경계와 핵심 계약을 보호하지만 필수 의미 검토를
  대신하지 않는다.

## 저장소 작업 지침

- `AGENTS.md`는 다양한 GitHub 독자를 위해 영어로 제공하되 Dockerize 스킬의 한영 정본
  선택, 의미 동등성 검토, 검증 순서와 전역 설치본 보호 규칙을 보존한다.
- `locales/ko/dockerize/SKILL.md`와 `skills/dockerize/SKILL.md`의 동기화 계약, 설치 인터페이스,
  스킬 동작과 `skills/dockerize/agents/openai.yaml`의 범위는 이 변경으로 바뀌지 않는다.

이 결정의 근거는
[`20260904-public-ready-dockerize-skill`](specs/20260904-public-ready-dockerize-skill/spec.md)이다.
