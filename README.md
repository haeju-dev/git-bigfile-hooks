# git-bigfile-hooks

Git 프로젝트에서 큰 파일(기본 10MB 이상)을 자동으로 관리하는 도구입니다.

## 기능

- 커밋 시 큰 파일 자동 감지 및 `BigFile/` 디렉토리로 이동
- 이동된 파일 위치에 symlink 자동 생성
- Git에서 symlink만 추적하여 저장소 용량 절약
- 다른 프로젝트에서 submodule로 쉽게 재사용

## 설치

### 방법 1: Submodule로 추가 (권장)

```bash
# submodule 추가
git submodule add https://github.com/haeju-dev/git-bigfile-hooks

# 설치 스크립트 실행
./git-bigfile-hooks/scripts/install.sh
```

### 방법 2: Clone 후 수동 설치

```bash
git clone https://github.com/haeju-dev/git-bigfile-hooks
cd git-bigfile-hooks
./scripts/install.sh
```

## 다른 기기에서 사용

```bash
# clone 시 submodule 포함
git clone --recursive https://github.com/your/project

# 또는 clone 후 초기화
git submodule update --init --recursive

# 설치 실행 (각 기기에서 한 번만)
./git-bigfile-hooks/scripts/install.sh
```

## 사용법

### 자동 동작 (pre-commit hook)

설치 후 자동으로 동작합니다:

```bash
git add large_video.mp4  # 50MB 파일
git commit -m "파일 추가"

# 출력:
# ⚠️  발견: 1개의 큰 파일(10MB 이상)이 커밋에 포함되어 있습니다.
#   - large_video.mp4 (50.00MB)
#
# 🔄 자동으로 BigFile/ 디렉토리로 이동합니다...
#   ✓ 이동 완료: large_video.mp4 → BigFile/large_video.mp4
#   🔗 Symlink 생성: large_video.mp4 → BigFile/large_video.mp4
#
# ✅ 큰 파일이 BigFile/ 디렉토리로 이동되었습니다.
```

### 수동 실행

```bash
# 프로젝트 전체에서 큰 파일 검색 및 이동
./git-bigfile-hooks/scripts/move_large_files.sh

# 미리보기 (실제 이동 없음)
./git-bigfile-hooks/scripts/move_large_files.sh --dry-run

# 50MB 이상 파일만 이동
./git-bigfile-hooks/scripts/move_large_files.sh --size 50

# BigFile에서 원래 위치로 symlink 생성
./git-bigfile-hooks/scripts/create_symlinks.sh
```

### 롤백 (원래 위치로 복원)

BigFile/에 있는 파일들을 원래 위치로 되돌립니다:

```bash
# 미리보기 (실제 복원 없음)
./git-bigfile-hooks/scripts/rollback.sh --dry-run

# 대화형으로 복원 (확인 후 실행)
./git-bigfile-hooks/scripts/rollback.sh

# 확인 없이 강제 복원
./git-bigfile-hooks/scripts/rollback.sh --force
```

롤백 동작:
1. 원래 위치의 symlink 제거
2. BigFile/의 파일을 원래 위치로 이동
3. 빈 BigFile/ 하위 디렉토리 정리

## 설정 커스터마이징

기본 설정을 변경하려면 `bigfile-config.sh` 파일을 프로젝트 루트에 생성합니다:

```bash
cp git-bigfile-hooks/config.sh bigfile-config.sh
```

설정 가능한 옵션:

```bash
# 파일 크기 제한 (MB)
MAX_SIZE_MB=10

# 큰 파일 저장 디렉토리
BIGFILE_DIR="BigFile"

# 제외할 디렉토리
EXCLUDE_DIRS=(
    ".git"
    ".obsidian"
    "node_modules"
    "venv"
)

# symlink 자동 생성 여부
CREATE_SYMLINKS=true
```

## 디렉토리 구조

```
프로젝트/
├── git-bigfile-hooks/     # submodule
│   ├── hooks/
│   │   └── pre-commit     # Git hook
│   ├── scripts/
│   │   ├── install.sh     # 설치 스크립트
│   │   ├── move_large_files.sh
│   │   ├── create_symlinks.sh
│   │   └── rollback.sh    # 원래 위치로 복원
│   ├── config.sh          # 기본 설정
│   └── README.md
├── BigFile/               # 큰 파일 저장소 (.gitignore)
│   └── path/to/large.mp4  # 실제 파일
├── path/to/large.mp4      # symlink → BigFile/path/to/large.mp4
└── bigfile-config.sh      # (선택) 프로젝트별 설정
```

## Git에 저장되는 것

| 항목 | Git 추적 | 설명 |
|------|---------|------|
| 실제 큰 파일 | ❌ | `BigFile/*` (.gitignore) |
| Symlink | ✅ | 경로 텍스트만 저장 (몇 바이트) |
| 작은 파일 | ✅ | 정상적으로 추적 |

## 라이선스

MIT License
