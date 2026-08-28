---
name: dockerize
description: 전역 패키지, 가상환경, node_modules, 생성 파일, 포트, 데이터베이스, 큐, 캐시, ML 모델 및 GPU 워크로드로 호스트를 오염시키지 않는 Docker Compose 기반 프로젝트 환경을 구축한다. 사용자가 dockerize, 컨테이너화, Docker 격리 또는 Dockerfile/compose.yaml 워크플로 생성을 명시적으로 요청할 때 사용한다. 그 외에는 기존 Compose 구성이 없는 프로젝트에 컨테이너화가 필요할 때만 사용한다. Docker 또는 Compose 자체가 요청 주제가 아니라면 이미 Compose로 관리되는 프로젝트의 일반적인 변경에는 사용하지 않는다.
---

# Dockerize

## 핵심 워크플로

1. Docker 파일을 작성하기 전에 프로젝트의 기존 `compose.yaml`, `docker-compose.yaml`, 래퍼 스크립트, `.env.example`, 의존성 manifest, entrypoint, 기본 command, 스크립트, 예상 출력, 대용량 데이터/모델 폴더, 보조 서비스, 포트, GPU 필요 여부 및 Hugging Face 사용 여부를 확인한다. 각 process가 요청이나 작업을 기다리며 계속 실행되는지, 작업 후 종료되는지도 판정한다.
2. 소스를 이미지에 복사하는 `Dockerfile`과 `compose.yaml`을 우선한다. 컨테이너가 생성한 파일이 호스트 checkout을 오염시키거나 root 소유가 될 수 있으므로 기본적으로 전체 저장소를 bind mount하지 않는다.
3. `.dockerignore`를 일찍 추가한다. 이미지에 반드시 복사해야 하는 경우가 아니라면 생성된 의존성, 빌드 출력, 캐시, secret/로컬 전용 설정, VCS 파일, 루트의 `/dev/` 및 `/dev_*/` 디렉터리, 대용량 모델/데이터/출력 폴더를 제외한다.
4. 데이터베이스, 큐, object store, 캐시 및 유사한 보조 서비스는 Compose 내부 네트워크에 유지한다. 사용자가 호스트에서 직접 접근해야 하는 경우가 아니면 호스트 포트를 publish하지 않는다.
5. 컨테이너 제거 후에도 유지해야 하는 영속 출력, 결과, 모델 캐시, 데이터베이스 데이터 및 기타 파일에는 named volume을 사용한다. Compose가 자동으로 결정한 `COMPOSE_PROJECT_NAME`을 기본 volume 이름에 사용하고, worktree가 stack을 격리하면서 선택한 대용량 volume을 공유할 수 있도록 volume별 환경 변수 override를 제공한다. 단, Hugging Face cache는 아래 공용 external volume 정책을 우선한다.
6. 프로젝트 루트에 필요한 Compose 래퍼 스크립트를 추가한다. 사용자가 `docker compose up`으로 운영할 long-lived process가 하나 이상 있을 때만 `compose-up.sh`, `compose-down.sh`, `compose-logs.sh`를 추가한다. 종료형 작업은 Compose service여도 `docker compose build <service>`와 `docker compose run --rm <service> <command>`를 사용한다. 대표적인 일회성 실행 파일이나 명령이 있으면 `compose-run.sh`를 추가하고, `compose-test.sh`는 항상 추가하며, 호스트로 반출할 출력 named volume이 있으면 `compose-export.sh`를 추가한다.
7. 호스트 로컬 package manager가 아니라 Compose를 통해 검증한다. 최소한 `docker compose config`를 실행하고 test profile 서비스가 있으면 사용한다.

## 결정할 사항

- **소스 처리**: live editing 또는 호스트에서 출력 확인이 명시적으로 필요하지 않으면 소스를 이미지에 복사한다.
- **Secret 및 설정**: `.env`, credential, private key, token, 추적되지 않는 머신 로컬 설정 같은 secret이나 로컬 전용 설정을 이미지에 절대 `COPY`하지 않는다. 환경 변수 주입에는 `env_file`을 사용하고, 애플리케이션이 런타임에 secret 파일을 요구하면 대상이 제한된 read-only bind mount를 사용한다. 버전 관리되며 애플리케이션 소스의 일부인 비밀이 아닌 프로젝트 설정은 정상적으로 복사할 수 있다.
- **대용량 asset**: `assets/`, `examples/`, `samples/`, `dataset_dir/`, 모델 weight, dataset 및 cache 같은 매우 큰 폴더에는 대상이 제한된 read-only bind 또는 named volume을 우선한다. 대용량 폴더를 이미지에 복사할지, 호스트에서 bind mount할지, named volume에 저장할지 불분명하면 사용자에게 질문한다.
- **사용자 identity**: non-root 컨테이너를 강제하지 않는다. base image나 프로젝트가 이미 깔끔하게 지원할 때는 문서화된 non-root 사용자를 사용하고, 그 외에는 base image의 기본 사용자를 유지한다.
- **출력**: `results:` 또는 `artifacts:` 같은 named volume을 기본으로 사용한다. 격리보다 즉시 호스트 접근이 더 중요할 때만 host bind mount를 사용한다. 호스트로 반출할 출력 named volume이 있으면 `compose-export.sh`를 제공한다.
- **프로젝트 및 volume 이름**: `.env.example`에 `COMPOSE_PROJECT_NAME`을 추가하거나 최상위 Compose `name:`으로 프로젝트 이름을 강제하지 않는다. Compose가 자동으로 결정한 `COMPOSE_PROJECT_NAME`을 사용하고, 공유할 수 있는 volume 이름은 `${RESULTS_VOLUME_NAME:-${COMPOSE_PROJECT_NAME}_results}`와 같이 volume별 override가 가능하도록 정의한다. Hugging Face cache는 다음 전용 정책의 예외로 처리한다.
- **Hugging Face cache 및 인증**: Hugging Face를 사용하면 `HF_HOME` 전체를 main worktree의 Compose 기본 project 이름에서 계산한 `${HF_CACHE_VOLUME_NAME:-<main-project-name>_hf-cache}` 공용 external named volume에 저장한다. 현재 worktree의 `COMPOSE_PROJECT_NAME`, 일시적인 `-p` 또는 shell의 `COMPOSE_PROJECT_NAME`을 이 기본 이름에 사용하지 않는다. `refs/heads/main` worktree를 찾을 수 없거나 main root basename이 Compose project 이름 규칙에 맞지 않으면 stable 이름을 사용자에게 질문한다. container를 생성하는 각 wrapper에 volume 존재 확인 및 생성 로직을 직접 넣고, 별도 helper를 생성하지 않는다. 기존 host cache 재사용, host 도구와의 공유, 직접 파일 관리 또는 host 계정 소유권이 필요할 때만 `${HF_CACHE_DIR:-${HOME}/.cache/huggingface}` read-write bind를 사용하며 native Linux에서는 `HOST_UID`/`HOST_GID`로 실행한다. `HF_TOKEN`은 optional environment 또는 `.env` 값으로만 전달하고 이미지, 저장소 또는 검증 로그에 기록하지 않는다. `HF_HOME` 전체를 공유하면 저장된 token도 지속되거나 노출될 수 있고, 설정된 `HF_TOKEN`은 저장 token보다 우선함을 알린다. 상세 pattern은 `references/ml.md`를 따른다.
- **GPU**: training, finetuning, inference, CUDA, PyTorch, TensorFlow 또는 유사 도구가 감지되거나 요청되면 ML 프로젝트에 GPU 지원을 추가한다.
- **Training과 inference**: 의존성 또는 런타임 요구사항이 다르면 별도 서비스나 Dockerfile target을 사용한다.
- **유틸리티 스크립트**: 호스트 로컬에서 스크립트를 실행하는 대신 `docker compose run --rm <service> <command>` 또는 전용 `tools` 서비스를 우선한다. 대표적인 일회성 실행 파일이나 명령이 있으면 발견한 service와 기본 명령을 고정하고 사용자 인자를 전달하는 `compose-run.sh`를 생성한다.
- **Compose 래퍼**: Compose의 `services:` 항목 자체가 아니라 서버, worker, daemon, 영속 side service처럼 계속 대기하는 long-lived process를 기준으로 판단한다. long-lived process와 종료형 작업이 함께 있으면 lifecycle wrapper는 long-lived stack에만 사용하고 종료형 작업은 `run --rm`으로 실행한다. wrapper를 만들기 위해 `sleep infinity`, `tail -f /dev/null` 같은 idle command를 추가하지 않는다. 단, 사용자가 interactive workspace를 명시적으로 요구한 경우는 예외다. `compose-test.sh`는 항상 생성하되 실행 가능한 test service가 없으면 안내 후 성공 종료하게 하고, 호스트로 반출할 출력 named volume이 있으면 `compose-export.sh`를 생성한다.

## References

작업에 필요한 파일만 읽는다.

- `references/policy.md`: 기본 Dockerization 규칙 및 tradeoff.
- `references/ml.md`: GPU, 모델 weight, train/finetune 및 inference pattern.
- `references/utilities.md`: 일회성 명령, 스크립트 및 export workflow.

## Templates

다음 template을 시작점으로 사용한 뒤 발견한 stack에 맞게 조정한다. lifecycle wrapper template은 위 생성 조건을 만족할 때만 사용한다.

- `assets/Dockerfile.template`
- `assets/compose.yaml.template`
- `assets/.dockerignore.template`
- `assets/compose-up.sh.template`
- `assets/compose-down.sh.template`
- `assets/compose-logs.sh.template`
- `assets/compose-run.sh.template`
- `assets/compose-test.sh.template`
- `assets/compose-export.sh.template`
- `assets/compose-hf-volume-preamble.sh.template`
- `assets/compose-hf-bind-linux-preamble.sh.template`
