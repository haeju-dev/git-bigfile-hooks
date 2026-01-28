#!/bin/bash

# git-bigfile-hooks: 큰 파일 이동 스크립트
# 프로젝트 전체에서 큰 파일을 찾아 BigFile/ 디렉토리로 이동

# 프로젝트 루트 찾기
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# 설정 파일 로드
if [ -f "$PROJECT_ROOT/bigfile-config.sh" ]; then
    source "$PROJECT_ROOT/bigfile-config.sh"
elif [ -f "$PROJECT_ROOT/git-bigfile-hooks/config.sh" ]; then
    source "$PROJECT_ROOT/git-bigfile-hooks/config.sh"
else
    # 기본값
    MAX_SIZE_MB=10
    BIGFILE_DIR="BigFile"
    CREATE_SYMLINKS=true
    EXCLUDE_DIRS=(".git" ".obsidian" "node_modules" "venv")
fi

MIN_SIZE_BYTES=$((MAX_SIZE_MB * 1024 * 1024))
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGETS_FILE="$PROJECT_ROOT/$BIGFILE_DIR/targets.txt"

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 사용법 출력
usage() {
    echo "사용법: $0 [옵션]"
    echo ""
    echo "옵션:"
    echo "  -d, --dry-run    실제로 이동하지 않고 미리보기만 표시"
    echo "  -s, --size MB    최소 파일 크기 지정 (기본값: ${MAX_SIZE_MB}MB)"
    echo "  -h, --help       이 도움말 표시"
    echo ""
    echo "예시:"
    echo "  $0                   # ${MAX_SIZE_MB}MB 이상 파일 이동"
    echo "  $0 --dry-run         # 미리보기만 표시"
    echo "  $0 --size 50         # 50MB 이상 파일 이동"
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
        -s|--size)
            MAX_SIZE_MB="$2"
            MIN_SIZE_BYTES=$((MAX_SIZE_MB * 1024 * 1024))
            shift 2
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

# 제외 디렉토리에 BIGFILE_DIR 추가
EXCLUDE_DIRS+=("$BIGFILE_DIR")

# find 명령어에 사용할 제외 조건 생성
EXCLUDE_ARGS=()
for dir in "${EXCLUDE_DIRS[@]}"; do
    EXCLUDE_ARGS+=(-path "*/$dir" -prune -o -path "*/$dir/*" -prune -o)
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}큰 파일 이동 스크립트${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "최소 파일 크기: ${YELLOW}${MAX_SIZE_MB}MB${NC}"
echo -e "대상 디렉토리: ${YELLOW}${BIGFILE_DIR}${NC}"
echo -e "프로젝트 루트: ${YELLOW}${PROJECT_ROOT}${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "모드: ${YELLOW}미리보기 (Dry Run)${NC}"
fi
echo ""

# 프로젝트 루트로 이동
cd "$PROJECT_ROOT" || exit 1

# BigFile 디렉토리 생성
mkdir -p "$BIGFILE_DIR"

# targets.txt 파일 초기화
{
    echo "========================================"
    echo "큰 파일 이동 대상 목록"
    echo "========================================"
    echo "생성 시간: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "최소 파일 크기: ${MAX_SIZE_MB}MB"
    echo "대상 디렉토리: ${BIGFILE_DIR}"
    echo ""
    echo "형식: [원본 경로] → [목적지 경로] (파일 크기)"
    echo "========================================"
    echo ""
} > "$TARGETS_FILE"

# 큰 파일 찾기
echo -e "${BLUE}큰 파일 검색 중...${NC}"
echo ""

moved_count=0
total_size=0

# find를 사용하여 큰 파일 찾기
while IFS= read -r -d '' file; do
    # symlink 제외
    if [ -L "$file" ]; then
        continue
    fi

    # 파일 크기 확인
    file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)

    if [ "$file_size" -ge "$MIN_SIZE_BYTES" ]; then
        # 파일 크기를 MB로 변환
        file_size_mb=$(echo "scale=2; $file_size / 1048576" | bc)

        # 원본 파일의 상대 경로
        relative_path="$file"

        # 목적지 경로 생성
        dest_file="${BIGFILE_DIR}/${relative_path}"
        dest_dir=$(dirname "$dest_file")

        echo -e "${GREEN}발견:${NC} $relative_path (${file_size_mb}MB)"

        # targets.txt에 기록
        echo "$relative_path → $dest_file (${file_size_mb}MB)" >> "$TARGETS_FILE"

        if [ "$DRY_RUN" = false ]; then
            # 목적지 디렉토리 생성
            mkdir -p "$dest_dir"

            # 파일 이동
            if mv "$file" "$dest_file"; then
                echo -e "  ${BLUE}→${NC} $dest_file"
                moved_count=$((moved_count + 1))
                total_size=$((total_size + file_size))

                # symlink 생성 (설정에 따라)
                if [ "$CREATE_SYMLINKS" = true ]; then
                    original_dir=$(dirname "$file")
                    mkdir -p "$original_dir"

                    rel_to_bigfile=$(python3 -c "import os.path; print(os.path.relpath('$dest_file', '$original_dir'))")

                    if ln -s "$rel_to_bigfile" "$file"; then
                        echo -e "  ${GREEN}🔗${NC} Symlink: $file → $rel_to_bigfile"
                    fi
                fi
            else
                echo -e "  ${RED}✗ 이동 실패${NC}"
            fi
        else
            echo -e "  ${YELLOW}→${NC} $dest_file (미리보기)"
            moved_count=$((moved_count + 1))
            total_size=$((total_size + file_size))
        fi
        echo ""
    fi
done < <(find . "${EXCLUDE_ARGS[@]}" -type f -print0)

# targets.txt에 요약 정보 추가
{
    echo ""
    echo "========================================"
    echo "요약"
    echo "========================================"
    echo "처리된 파일 수: ${moved_count}"
    if [ $total_size -gt 0 ]; then
        total_size_mb=$(echo "scale=2; $total_size / 1048576" | bc)
        total_size_gb=$(echo "scale=2; $total_size / 1073741824" | bc)
        echo "총 파일 크기: ${total_size_mb}MB (${total_size_gb}GB)"
    fi
    echo "========================================"
} >> "$TARGETS_FILE"

# 결과 요약
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}결과 요약${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "처리된 파일 수: ${GREEN}${moved_count}${NC}"

if [ $total_size -gt 0 ]; then
    total_size_mb=$(echo "scale=2; $total_size / 1048576" | bc)
    total_size_gb=$(echo "scale=2; $total_size / 1073741824" | bc)
    echo -e "총 파일 크기: ${GREEN}${total_size_mb}MB${NC} (${total_size_gb}GB)"
fi

echo -e "대상 파일 목록: ${GREEN}${TARGETS_FILE}${NC}"

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo -e "${YELLOW}미리보기 모드입니다. 실제로 파일을 이동하려면 --dry-run 옵션 없이 실행하세요.${NC}"
fi

echo ""
