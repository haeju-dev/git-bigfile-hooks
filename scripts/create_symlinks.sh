#!/bin/bash

# git-bigfile-hooks: Symlink 생성 스크립트
# BigFile/ 디렉토리의 파일들을 원래 위치에 symlink로 연결

# 프로젝트 루트 찾기
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# 설정 파일 로드
if [ -f "$PROJECT_ROOT/bigfile-config.sh" ]; then
    source "$PROJECT_ROOT/bigfile-config.sh"
elif [ -f "$PROJECT_ROOT/git-bigfile-hooks/config.sh" ]; then
    source "$PROJECT_ROOT/git-bigfile-hooks/config.sh"
else
    BIGFILE_DIR="BigFile"
fi

BIGFILE_PATH="$PROJECT_ROOT/$BIGFILE_DIR"

# 색상 코드
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# 사용법 출력
usage() {
    echo "사용법: $0 [옵션]"
    echo ""
    echo "옵션:"
    echo "  -d, --dry-run    실제로 생성하지 않고 미리보기만 표시"
    echo "  -h, --help       이 도움말 표시"
    echo ""
    echo "예시:"
    echo "  $0               # symlink 생성"
    echo "  $0 --dry-run     # 미리보기만 표시"
    exit 1
}

# 인수 파싱
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "알 수 없는 옵션: $1"
            usage
            ;;
    esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Symlink 생성 스크립트${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "BigFile 디렉토리: ${YELLOW}${BIGFILE_PATH}${NC}"
echo -e "프로젝트 루트: ${YELLOW}${PROJECT_ROOT}${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "모드: ${YELLOW}미리보기 (Dry Run)${NC}"
fi
echo ""

# BigFile 디렉토리 확인
if [ ! -d "$BIGFILE_PATH" ]; then
    echo -e "${YELLOW}$BIGFILE_DIR 디렉토리가 존재하지 않습니다.${NC}"
    exit 0
fi

cd "$PROJECT_ROOT" || exit 1

# symlink 생성
created_count=0

# BigFile 디렉토리 내의 모든 파일 찾기
while IFS= read -r -d '' file; do
    # BigFile/ 이후의 상대 경로 추출
    relative_path="${file#$BIGFILE_PATH/}"

    # ./로 시작하는 경로 정리
    relative_path="${relative_path#./}"

    # 원래 위치 경로
    original_path="$PROJECT_ROOT/$relative_path"
    original_dir=$(dirname "$original_path")

    # BigFile 내의 실제 파일 경로
    bigfile_path="$BIGFILE_PATH/$relative_path"

    # 이미 symlink가 존재하는지 확인
    if [ -L "$original_path" ]; then
        continue
    fi

    # 원본 파일이 이미 존재하는지 확인 (symlink가 아닌 실제 파일)
    if [ -f "$original_path" ] && [ ! -L "$original_path" ]; then
        echo -e "${YELLOW}건너뜀:${NC} $relative_path (원본 파일이 이미 존재)"
        continue
    fi

    echo -e "${GREEN}생성:${NC} $relative_path"

    if [ "$DRY_RUN" = false ]; then
        # 디렉토리 생성
        mkdir -p "$original_dir"

        # 상대 경로로 symlink 생성
        rel_to_bigfile=$(python3 -c "import os.path; print(os.path.relpath('$bigfile_path', '$original_dir'))")

        if ln -s "$rel_to_bigfile" "$original_path"; then
            echo -e "  ${BLUE}→${NC} $rel_to_bigfile"
            created_count=$((created_count + 1))
        else
            echo -e "  ${RED}✗ 생성 실패${NC}"
        fi
    else
        echo -e "  ${YELLOW}→${NC} $BIGFILE_DIR/$relative_path (미리보기)"
        created_count=$((created_count + 1))
    fi
done < <(find "$BIGFILE_PATH" -type f -print0)

# 결과 요약
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}결과 요약${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "생성된 symlink 수: ${GREEN}${created_count}${NC}"

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo -e "${YELLOW}미리보기 모드입니다. 실제로 생성하려면 --dry-run 옵션 없이 실행하세요.${NC}"
fi

echo ""
