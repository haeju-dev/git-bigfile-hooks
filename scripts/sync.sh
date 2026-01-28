#!/bin/bash

# git-bigfile-hooks: 동기화 스크립트
# 깨진 symlink를 감지하고 BigFile 경로를 자동으로 동기화

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
    echo "깨진 symlink를 감지하고 BigFile 경로를 자동으로 동기화합니다."
    echo ""
    echo "옵션:"
    echo "  -d, --dry-run    실제로 수정하지 않고 미리보기만 표시"
    echo "  -f, --force      확인 없이 강제 실행"
    echo "  -h, --help       이 도움말 표시"
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
            shift
            ;;
    esac
done

cd "$PROJECT_ROOT" || exit 1

# BigFile 디렉토리 확인
if [ ! -d "$BIGFILE_PATH" ]; then
    echo -e "${YELLOW}$BIGFILE_DIR 디렉토리가 존재하지 않습니다.${NC}"
    exit 0
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}BigFile 동기화${NC}"
echo -e "${BLUE}========================================${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "모드: ${YELLOW}미리보기 (Dry Run)${NC}"
fi
echo ""

# 1단계: 깨진 symlink 찾기 (BigFile을 가리키던 것들)
echo -e "${BLUE}[1/3]${NC} 깨진 symlink 검색 중..."

broken_symlinks=()
while IFS= read -r -d '' symlink; do
    # symlink가 BigFile을 가리키는지 확인
    target=$(readlink "$symlink" 2>/dev/null)
    if [[ "$target" == *"$BIGFILE_DIR"* ]] || [[ "$target" == *"BigFile"* ]]; then
        if [ ! -e "$symlink" ]; then
            broken_symlinks+=("$symlink")
        fi
    fi
done < <(find "$PROJECT_ROOT" -type l -print0 2>/dev/null | grep -zv "^$BIGFILE_PATH" | grep -zv "/.git/")

if [ ${#broken_symlinks[@]} -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} 깨진 symlink 없음"
else
    echo -e "  ${YELLOW}발견: ${#broken_symlinks[@]}개의 깨진 symlink${NC}"
    for link in "${broken_symlinks[@]}"; do
        echo -e "    - $link"
    done
fi
echo ""

# 2단계: BigFile에 있지만 symlink가 없는 파일 찾기
echo -e "${BLUE}[2/3]${NC} 고아 파일 검색 중 (BigFile에만 존재)..."

orphan_files=()
while IFS= read -r -d '' file; do
    # BigFile 이후의 상대 경로 추출
    relative_path="${file#$BIGFILE_PATH/}"
    original_path="$PROJECT_ROOT/$relative_path"

    # 원래 위치에 symlink가 있는지 확인
    if [ ! -L "$original_path" ] && [ ! -f "$original_path" ]; then
        orphan_files+=("$file:$relative_path")
    fi
done < <(find "$BIGFILE_PATH" -type f -print0 2>/dev/null)

if [ ${#orphan_files[@]} -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} 고아 파일 없음"
else
    echo -e "  ${YELLOW}발견: ${#orphan_files[@]}개의 고아 파일${NC}"
fi
echo ""

# 3단계: 이동된 symlink 감지 및 BigFile 경로 동기화
echo -e "${BLUE}[3/3]${NC} 이동된 파일 감지 및 동기화..."

# git에서 renamed 파일 찾기 (staged 상태)
sync_count=0

# git status에서 renamed 파일 찾기
while IFS= read -r line; do
    # R  old_path -> new_path 형식 파싱
    if [[ "$line" =~ ^R[[:space:]]+(.+)[[:space:]]+"->"[[:space:]]+(.+)$ ]] || \
       [[ "$line" =~ ^R[[:space:]]+\"(.+)\"[[:space:]]+"->"[[:space:]]+\"(.+)\"$ ]]; then
        old_path="${BASH_REMATCH[1]}"
        new_path="${BASH_REMATCH[2]}"

        # 새 경로가 symlink이고 BigFile을 가리키는지 확인
        if [ -L "$new_path" ]; then
            target=$(readlink "$new_path" 2>/dev/null)
            if [[ "$target" == *"$BIGFILE_DIR"* ]]; then
                # BigFile 내부의 기존 경로
                old_bigfile_path="$BIGFILE_PATH/$old_path"
                new_bigfile_path="$BIGFILE_PATH/$new_path"

                if [ -f "$old_bigfile_path" ]; then
                    echo -e "  ${YELLOW}이동 감지:${NC} $old_path → $new_path"

                    if [ "$DRY_RUN" = false ]; then
                        # BigFile 내부 경로도 이동
                        new_bigfile_dir=$(dirname "$new_bigfile_path")
                        mkdir -p "$new_bigfile_dir"

                        if mv "$old_bigfile_path" "$new_bigfile_path"; then
                            echo -e "    ${GREEN}✓${NC} BigFile 내부 경로 동기화됨"

                            # symlink 재생성 (상대 경로)
                            rm "$new_path"
                            original_dir=$(dirname "$new_path")
                            rel_to_bigfile=$(python3 -c "import os.path; print(os.path.relpath('$new_bigfile_path', '$original_dir'))")
                            ln -s "$rel_to_bigfile" "$new_path"
                            git add "$new_path"

                            echo -e "    ${GREEN}✓${NC} Symlink 재생성됨"
                            sync_count=$((sync_count + 1))
                        fi

                        # 빈 디렉토리 정리
                        old_bigfile_dir=$(dirname "$old_bigfile_path")
                        find "$old_bigfile_dir" -type d -empty -delete 2>/dev/null
                    else
                        echo -e "    ${YELLOW}→${NC} BigFile/$old_path → BigFile/$new_path (미리보기)"
                        sync_count=$((sync_count + 1))
                    fi
                fi
            fi
        fi
    fi
done < <(git status --porcelain 2>/dev/null)

# 깨진 symlink 복구 시도 (파일명 기반 매칭)
for broken_link in "${broken_symlinks[@]}"; do
    filename=$(basename "$broken_link")
    link_dir=$(dirname "$broken_link")

    # BigFile에서 같은 이름의 파일 찾기
    found_file=$(find "$BIGFILE_PATH" -name "$filename" -type f 2>/dev/null | head -1)

    if [ -n "$found_file" ]; then
        echo -e "  ${YELLOW}복구 가능:${NC} $broken_link"
        echo -e "    → BigFile 내 파일: $found_file"

        if [ "$DRY_RUN" = false ]; then
            # 새 BigFile 경로 계산
            relative_from_root="${broken_link#$PROJECT_ROOT/}"
            new_bigfile_path="$BIGFILE_PATH/$relative_from_root"
            new_bigfile_dir=$(dirname "$new_bigfile_path")

            mkdir -p "$new_bigfile_dir"

            if mv "$found_file" "$new_bigfile_path"; then
                # symlink 재생성
                rm "$broken_link"
                rel_to_bigfile=$(python3 -c "import os.path; print(os.path.relpath('$new_bigfile_path', '$link_dir'))")
                ln -s "$rel_to_bigfile" "$broken_link"
                git add "$broken_link"

                echo -e "    ${GREEN}✓${NC} 복구 완료"
                sync_count=$((sync_count + 1))

                # 빈 디렉토리 정리
                old_dir=$(dirname "$found_file")
                find "$old_dir" -type d -empty -delete 2>/dev/null
            fi
        else
            echo -e "    ${YELLOW}→${NC} 복구 예정 (미리보기)"
            sync_count=$((sync_count + 1))
        fi
    fi
done

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}결과 요약${NC}"
echo -e "${BLUE}========================================${NC}"

if [ $sync_count -eq 0 ]; then
    echo -e "${GREEN}모든 파일이 동기화 상태입니다.${NC}"
else
    echo -e "동기화된 파일: ${GREEN}${sync_count}${NC}개"
fi

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo -e "${YELLOW}미리보기 모드입니다. 실제로 동기화하려면 --dry-run 옵션 없이 실행하세요.${NC}"
fi

echo ""
