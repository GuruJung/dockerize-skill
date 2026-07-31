# Dockerize skill authoring rules

이 저장소에서 `dockerize` 스킬의 동작이나 `SKILL.md`를 수정할 때 다음 순서를 반드시 따른다.

1. `locales/ko/dockerize/SKILL.md`를 유일한 콘텐츠 정본으로 취급하고 먼저 수정한다.
2. 변경된 한국어 원본을 `skills/dockerize/SKILL.md`에 의미가 동등한 영어 명령문으로 번역한다.
3. 규칙, 조건, 우선순위와 목록 순서를 보존한다. 경로, 명령, 환경 변수, 코드 키워드는 번역하지 않는다.
4. 영어본만 단독으로 수정하거나 `$HOME/.agents/skills/dockerize`의 전역 설치본을 직접 수정하지 않는다.
5. 의미 동등성을 검토한 뒤 `scripts/record-sync.sh` 또는 `scripts/record-sync.ps1`을 실행한다.
6. `scripts/check-sync.sh` 또는 `scripts/check-sync.ps1`, 양쪽 `SKILL.md`의 `quick_validate.py`, 전체 회귀 테스트를 실행한다.
7. 스킬 범위나 기본 프롬프트가 달라지는 변경이면 영어 단일본인 `skills/dockerize/agents/openai.yaml`도 별도로 검토한다.

References, assets, `agents/openai.yaml`, 설치 도구만 변경하는 작업에는 한영 동기화를 적용하지 않는다. 동기화 manifest는 두 파일이 마지막 의미 검토 이후 바뀌지 않았는지만 증명하며 번역 품질을 증명하지 않는다.
