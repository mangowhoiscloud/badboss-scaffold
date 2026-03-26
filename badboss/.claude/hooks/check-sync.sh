#!/bin/bash
# Hook: Stop — 크로스레포 동기화 + develop→main 격차 리마인드
# (1) web/skill 오늘 커밋 있는데 progress.md 미갱신이면 리마인드
# (2) web develop→main 격차 → 머지 리마인드
# (3) skill develop→main 격차 → 머지 리마인드
# (4) web API 변경 감지 → skill references 동기화 리마인드
# Pattern: GEODE .claude/hooks/check-progress.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TODAY=$(date +%Y-%m-%d)
PROGRESS_FILE="$ROOT_DIR/docs/progress.md"
MESSAGES=()

# --- Check 1: progress.md 갱신 여부 ---
WEB_COMMITS=0
SKILL_COMMITS=0

if [ -d "$ROOT_DIR/web/.git" ]; then
  WEB_COMMITS=$(cd "$ROOT_DIR/web" && git log --since="$TODAY 00:00:00" --oneline 2>/dev/null | wc -l | tr -d ' ')
fi

if [ -d "$ROOT_DIR/skill/.git" ]; then
  SKILL_COMMITS=$(cd "$ROOT_DIR/skill" && git log --since="$TODAY 00:00:00" --oneline 2>/dev/null | wc -l | tr -d ' ')
fi

TOTAL_COMMITS=$((WEB_COMMITS + SKILL_COMMITS))

if [ "$TOTAL_COMMITS" -gt 0 ]; then
  if [ ! -f "$PROGRESS_FILE" ] || ! grep -q "$TODAY" "$PROGRESS_FILE"; then
    MESSAGES+=("[progress] 오늘 web ${WEB_COMMITS}건 + skill ${SKILL_COMMITS}건 커밋이 있지만 docs/progress.md에 ${TODAY} 날짜가 없습니다. 갱신해주세요.")
  fi
fi

# --- Check 2: web develop→main 격차 ---
if [ -d "$ROOT_DIR/web/.git" ]; then
  cd "$ROOT_DIR/web"
  git fetch origin --quiet 2>/dev/null || true
  WEB_AHEAD=$(git rev-list --count origin/main..origin/develop 2>/dev/null || echo "0")
  if [ "$WEB_AHEAD" -gt 0 ]; then
    MESSAGES+=("[web gitflow] develop이 main보다 ${WEB_AHEAD}커밋 앞서 있습니다. develop → main PR을 진행하세요.")
  fi
fi

# --- Check 3: skill develop→main 격차 ---
if [ -d "$ROOT_DIR/skill/.git" ]; then
  cd "$ROOT_DIR/skill"
  git fetch origin --quiet 2>/dev/null || true
  SKILL_AHEAD=$(git rev-list --count origin/main..origin/develop 2>/dev/null || echo "0")
  if [ "$SKILL_AHEAD" -gt 0 ]; then
    MESSAGES+=("[skill gitflow] develop이 main보다 ${SKILL_AHEAD}커밋 앞서 있습니다. develop → main PR을 진행하세요.")
  fi
fi

# --- Check 4: web API 변경 감지 → skill 동기화 리마인드 ---
if [ -d "$ROOT_DIR/web/.git" ] && [ "$WEB_COMMITS" -gt 0 ]; then
  cd "$ROOT_DIR/web"
  API_CHANGED=$(git diff --name-only HEAD~"${WEB_COMMITS}" HEAD 2>/dev/null \
    | grep -c "src/app/api/" || true)
  if [ "$API_CHANGED" -gt 0 ]; then
    MESSAGES+=("[cross-repo] web API 파일이 ${API_CHANGED}건 변경되었습니다. skill/badboss-report/references/api-spec.md 동기화를 확인하세요.")
  fi
fi

# --- Output ---
if [ ${#MESSAGES[@]} -eq 0 ]; then
  echo '{"continue": true}'
else
  MSG=$(printf '%s ' "${MESSAGES[@]}")
  MSG=$(echo "$MSG" | sed 's/"/\\"/g')
  cat <<EOF
{
  "continue": true,
  "message": "${MSG}"
}
EOF
fi
