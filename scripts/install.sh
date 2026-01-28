#!/bin/bash

# git-bigfile-hooks 설치 스크립트
# 이 스크립트는 프로젝트에 git-bigfile-hooks를 설치합니다.

# 색상 코드
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# 프로젝트 루트 찾기
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$PROJECT_ROOT" ]; then
    echo -e "${RED}오류: Git repository가 아닙니다.${NC}"
    exit 1
fi

# 스크립트 디렉토리 찾기
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBMODULE_ROOT="$(dirname "$SCRIPT_DIR")"

# 설정 파일 로드
if [ -f "$SUBMODULE_ROOT/config.sh" ]; then
    source "$SUBMODULE_ROOT/config.sh"
else
    BIGFILE_DIR="BigFile"
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}git-bigfile-hooks 설치${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "프로젝트 루트: ${YELLOW}${PROJECT_ROOT}${NC}"
echo -e "Submodule 경로: ${YELLOW}${SUBMODULE_ROOT}${NC}"
echo ""

cd "$PROJECT_ROOT" || exit 1

# 1. Git hooks 경로 설정
echo -e "${BLUE}[1/4]${NC} Git hooks 경로 설정..."

# submodule 상대 경로 계산
SUBMODULE_REL_PATH=$(python3 -c "import os.path; print(os.path.relpath('$SUBMODULE_ROOT', '$PROJECT_ROOT'))")

git config core.hooksPath "$SUBMODULE_REL_PATH/hooks"
echo -e "  ${GREEN}✓${NC} core.hooksPath = $SUBMODULE_REL_PATH/hooks"

# 2. BigFile 디렉토리 생성
echo -e "${BLUE}[2/4]${NC} $BIGFILE_DIR 디렉토리 생성..."

if [ ! -d "$BIGFILE_DIR" ]; then
    mkdir -p "$BIGFILE_DIR"
    echo -e "  ${GREEN}✓${NC} $BIGFILE_DIR/ 디렉토리 생성됨"
else
    echo -e "  ${YELLOW}→${NC} $BIGFILE_DIR/ 디렉토리가 이미 존재합니다"
fi

# 3. .gitignore에 BigFile 추가
echo -e "${BLUE}[3/4]${NC} .gitignore 설정..."

GITIGNORE_FILE="$PROJECT_ROOT/.gitignore"
BIGFILE_PATTERN="$BIGFILE_DIR/*"

if [ -f "$GITIGNORE_FILE" ]; then
    if grep -q "^$BIGFILE_PATTERN$" "$GITIGNORE_FILE"; then
        echo -e "  ${YELLOW}→${NC} $BIGFILE_PATTERN 이미 .gitignore에 등록됨"
    else
        echo "" >> "$GITIGNORE_FILE"
        echo "# git-bigfile-hooks: 큰 파일 저장소" >> "$GITIGNORE_FILE"
        echo "$BIGFILE_PATTERN" >> "$GITIGNORE_FILE"
        echo -e "  ${GREEN}✓${NC} $BIGFILE_PATTERN 추가됨"
    fi
else
    echo "# git-bigfile-hooks: 큰 파일 저장소" > "$GITIGNORE_FILE"
    echo "$BIGFILE_PATTERN" >> "$GITIGNORE_FILE"
    echo -e "  ${GREEN}✓${NC} .gitignore 생성 및 $BIGFILE_PATTERN 추가됨"
fi

# 4. 실행 권한 부여
echo -e "${BLUE}[4/4]${NC} 실행 권한 설정..."

chmod +x "$SUBMODULE_ROOT/hooks/"* 2>/dev/null
chmod +x "$SUBMODULE_ROOT/scripts/"* 2>/dev/null
echo -e "  ${GREEN}✓${NC} 스크립트 실행 권한 설정됨"

# 완료 메시지
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}설치 완료!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "사용 가능한 명령어:"
echo -e "  ${YELLOW}$SUBMODULE_REL_PATH/scripts/move_large_files.sh${NC}"
echo -e "    → 프로젝트 전체에서 큰 파일을 찾아 $BIGFILE_DIR/로 이동"
echo ""
echo -e "  ${YELLOW}$SUBMODULE_REL_PATH/scripts/create_symlinks.sh${NC}"
echo -e "    → $BIGFILE_DIR/의 파일들을 원래 위치에 symlink로 연결"
echo ""
echo -e "자동 동작:"
echo -e "  - 커밋 시 ${MAX_SIZE_MB:-10}MB 이상 파일 자동 이동"
echo -e "  - 이동된 파일 위치에 symlink 자동 생성"
echo ""
echo -e "설정 커스터마이징:"
echo -e "  ${YELLOW}cp $SUBMODULE_REL_PATH/config.sh bigfile-config.sh${NC}"
echo -e "  그리고 bigfile-config.sh 파일을 수정하세요."
echo ""
