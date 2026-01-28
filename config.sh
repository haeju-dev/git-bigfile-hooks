#!/bin/bash

# git-bigfile-hooks 설정 파일
# 이 파일을 프로젝트 루트에 복사하여 설정을 커스터마이징할 수 있습니다.

# 파일 크기 제한 (MB)
# 이 크기 이상의 파일은 BigFile 디렉토리로 이동됩니다.
MAX_SIZE_MB=10

# 큰 파일 저장 디렉토리
# 프로젝트 루트 기준 상대 경로
BIGFILE_DIR="BigFile"

# 제외할 디렉토리 패턴
# 이 디렉토리들은 큰 파일 검색에서 제외됩니다.
EXCLUDE_DIRS=(
    ".git"
    ".obsidian"
    ".vscode"
    ".idea"
    ".makemd"
    ".space"
    "node_modules"
    "venv"
    "env"
    "ENV"
)

# symlink 자동 생성 여부
# true: 큰 파일 이동 후 원래 위치에 symlink 생성
# false: 파일만 이동
CREATE_SYMLINKS=true
