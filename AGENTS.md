# Dockerize skill authoring rules

이 저장소에서 `dockerize` 스킬의 동작이나 `SKILL.md`를 수정할 때 다음 순서를 반드시 따른다.

1. 두 `SKILL.md` 중 어느 하나라도 편집하기 전에 `locales/ko/dockerize/SKILL.md`와 `skills/dockerize/SKILL.md`의 Git 상태와 filesystem mtime을 한 번 확인한다. HEAD에 비해 index 또는 working tree에서 modified인 기존 파일만 정본 후보로 삼는다.
2. 후보가 하나면 그 파일을, 둘이면 mtime이 더 최신인 파일을 해당 작업에서 사용자의 의도가 담긴 정본으로 선택한다. 후보가 없으면 요청에 자연스러운 언어로 시작한다. 후보들의 mtime이 정확히 같거나 파일이 누락되었거나 modified 이외의 삭제·rename·unmerged 등 안전하지 않은 Git 상태이면 편집하지 말고 사용자에게 정본 또는 복구 방법을 묻는다.
3. 선택한 정본을 기준으로 다른 언어의 `SKILL.md`를 의미가 동등한 명령문으로 맞춘다. 에이전트가 편집하며 바꾼 mtime으로 작업 도중 정본을 다시 선택하지 않는다.
4. 규칙, 조건, 우선순위와 목록 순서를 보존한다. 경로, 명령, 환경 변수, 코드 키워드는 번역하지 않는다. `$HOME/.agents/skills/dockerize`의 전역 설치본을 직접 수정하지 않는다.
5. 의미 동등성을 검토한 뒤 `scripts/record-sync.sh` 또는 `scripts/record-sync.ps1`을 실행한다.
6. `scripts/check-sync.sh` 또는 `scripts/check-sync.ps1`, 양쪽 `SKILL.md`의 `quick_validate.py`, 전체 회귀 테스트를 실행한다.
7. 스킬 범위나 기본 프롬프트가 달라지는 변경이면 영어 단일본인 `skills/dockerize/agents/openai.yaml`도 별도로 검토한다.

References, assets, `agents/openai.yaml`, 설치 도구만 변경하는 작업에는 한영 동기화를 적용하지 않는다. 동기화 manifest는 두 파일이 마지막 의미 검토 이후 바뀌지 않았는지만 증명하며 번역 품질을 증명하지 않는다.
