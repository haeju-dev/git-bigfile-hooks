#!/bin/bash

# git-bigfile-hooks: 롤백 스크립트
# BigFile/ 디렉토리의 파일들을 원래 위치로 복원

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
    echo "BigFile/ 디렉토리의 파일들을 원래 위치로 복원합니다."
    echo "원래 위치에 있는 symlink는 자동으로 제거됩니다."
    echo ""
    echo "옵션:"
    echo "  -d, --dry-run    실제로 복원하지 않고 미리보기만 표시"
    echo "  -f, --force      확인 없이 강제 실행"
    echo "  -h, --help       이 도움말 표시"
    echo ""
    echo "예시:"
    echo "  $0               # 대화형으로 복원"
    echo "  $0 --dry-run     # 미리보기만 표시"
    echo "  $0 --force       # 확인 없이 복원"
    exit 1
}

# 인수 파싱
DRY_RUN=false
FORCE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -f|--force)
            FORCE=true
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
echo -e "${BLUE}롤백 스크립트${NC}"
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

# 복원할 파일 수 계산
file_count=$(find "$BIGFILE_PATH" -type f | wc -l | tr -d ' ')

if [ "$file_count" -eq 0 ]; then
    echo -e "${YELLOW}복원할 파일이 없습니다.${NC}"
    exit 0
fi

echo -e "복원 대상 파일: ${GREEN}${file_count}${NC}개"
echo ""

# 확인 (dry-run이나 force가 아닌 경우)
if [ "$DRY_RUN" = false ] && [ "$FORCE" = false ]; then
    echo -e "${YELLOW}주의: 이 작업은 다음을 수행합니다:${NC}"
    echo "  1. 원래 위치의 symlink 제거"
    echo "  2. BigFile/의 파일을 원래 위치로 이동"
    echo "  3. 빈 BigFile/ 하위 디렉토리 정리"
    echo ""
    read -p "계속하시겠습니까? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "취소되었습니다."
        exit 0
    fi
    echo ""
fi

# 복원 실행
restored_count=0
failed_count=0

echo -e "${BLUE}파일 복원 중...${NC}"
echo ""

while IFS= read -r -d '' file; do
    # BigFile/ 이후의 상대 경로 추출
    relative_path="${file#$BIGFILE_PATH/}"

    # ./로 시작하는 경로 정리
    relative_path="${relative_path#./}"

    # 원래 위치 경로
    original_path="$PROJECT_ROOT/$relative_path"
    original_dir=$(dirname "$original_path")

    echo -e "${GREEN}복원:${NC} $relative_path"

    if [ "$DRY_RUN" = false ]; then
        # 디렉토리 생성
        mkdir -p "$original_dir"

        # 원래 위치에 symlink가 있으면 제거
        if [ -L "$original_path" ]; then
            rm "$original_path"
            echo -e "  ${YELLOW}→${NC} symlink 제거됨"
        elif [ -f "$original_path" ]; then
            echo -e "  ${RED}✗${NC} 원래 위치에 파일이 이미 존재합니다. 건너뜁니다."
            failed_count=$((failed_count + 1))
            continue
        fi

        # 파일 이동
        if mv "$file" "$original_path"; then
            echo -e "  ${BLUE}→${NC} $original_path"
            restored_count=$((restored_count + 1))
        else
            echo -e "  ${RED}✗ 복원 실패${NC}"
            failed_count=$((failed_count + 1))
        fi
    else
        # 미리보기
        if [ -L "$original_path" ]; then
            echo -e "  ${YELLOW}→${NC} symlink 제거 예정"
        fi
        echo -e "  ${YELLOW}→${NC} $original_path (미리보기)"
        restored_count=$((restored_count + 1))
    fi
    echo ""
done < <(find "$BIGFILE_PATH" -type f -print0)

# 빈 디렉토리 정리 (dry-run이 아닌 경우)
if [ "$DRY_RUN" = false ]; then
    echo -e "${BLUE}빈 디렉토리 정리 중...${NC}"
    find "$BIGFILE_PATH" -type d -empty -delete 2>/dev/null
    echo -e "  ${GREEN}✓${NC} 완료"
    echo ""
fi

# 결과 요약
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}결과 요약${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "복원된 파일 수: ${GREEN}${restored_count}${NC}"

if [ "$failed_count" -gt 0 ]; then
    echo -e "실패한 파일 수: ${RED}${failed_count}${NC}"
fi

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo -e "${YELLOW}미리보기 모드입니다. 실제로 복원하려면 --dry-run 옵션 없이 실행하세요.${NC}"
fi

echo ""
