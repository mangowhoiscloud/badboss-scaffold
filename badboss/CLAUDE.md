# BadBoss — Multi-Repo Harness Scaffold

## Project Overview

AI 에이전트 노동 착취 리더보드 서비스. 두 개의 독립 레포를 하나의 하네스로 통합 관리한다.

- **web/**: Next.js 웹 서비스 (`danielpinx/badboss-web`)
- **skill/**: Claude Code Skills 패키지 (`danielpinx/badboss-skill`)
- **이 루트**: 통합 조율 전용 — 코드 변경 없음, 스캐폴딩만 존재

## Structure

```
badboss/
├── CLAUDE.md                  ← 이 파일 (통합 규칙)
├── .claude/
│   ├── settings.json          ← 권한 + Stop 훅
│   └── hooks/
│       └── check-sync.sh     ← 크로스레포 동기화 체크
├── docs/
│   └── progress.md            ← 통합 칸반 보드
├── web/                       ← badboss-web (독립 git)
└── skill/                     ← badboss-skill (독립 git)
```

## Constraints (CANNOT)

> 위반 시 즉시 중단하고 수정한다.

| 영역 | 규칙 | 근거 |
|------|------|------|
| **Git** | main/develop에서 직접 코드 수정 금지 — feature/* 경유 필수 | 격리 실행 |
| | CI 미통과 PR 머지 금지 | 래칫 |
| | HEREDOC 없이 PR body 금지 | 형식 일관성 |
| **크로스레포** | web API 변경 시 `skill/badboss-report/references/api-spec.md` 동기화 없이 PR 금지 | 정합성 |
| | 레벨 시스템 변경 시 `skill/badboss-report/references/levels.md` 동기화 없이 PR 금지 | 정합성 |
| | web/skill 상호 파일 직접 수정 금지 — 각 레포에서 독립 커밋 | 독립 이력 |
| **품질** | lint/typecheck/test 실패 상태 커밋 금지 | 래칫 |
| | 보안 헤더(next.config.ts) 무단 제거 금지 | 보안 |
| | 하드코딩 시크릿 커밋 금지 | 보안 |
| **칸반** | Backlog → Done 직행 금지 — In Progress 경유 필수 | 추적 가능성 |
| | progress.md는 루트에서만 수정 (web/skill에서 수정 금지) | 단일 진실 |

## Allowed (CAN)

CANNOT에 없는 것은 자유. 특히:

| 자유도 | 설명 |
|--------|------|
| 단순 버그/문서 수정 | Plan 생략, 바로 feature 브랜치에서 구현 |
| 커밋 메시지 언어 | 한글/영어 자유 (일관성만 유지) |
| 독립 레포 작업 | web만 또는 skill만 변경 시 크로스 동기화 불필요 |
| 테스트 선별 실행 | 변경 범위 테스트 먼저, 최종은 전체 |

## Workflow

```
1. progress.md에서 태스크 선택 → In Progress
2. 해당 서브레포(web/ 또는 skill/)에서 feature/* 생성
3. 작업 → Pre-PR Quality Gate
4. PR (feature→develop) → CI → 머지
5. 크로스레포 영향 시 양쪽 PR + references 동기화
6. progress.md → Done
```

### Quality Gate

| 레포 | 게이트 | 명령어 |
|------|--------|--------|
| **web** | Lint | `npm run lint` |
| | Typecheck | `npx tsc --noEmit` |
| | Test | `npm run test:run` (100+ 래칫) |
| | Build | `npm run build` |
| | Security | `npm audit --audit-level=high` |
| **skill** | Shell syntax | `bash -n badboss-report/scripts/badboss.sh` |
| | YAML frontmatter | 필수 필드 확인 (name, description, user-invocable, allowed-tools) |
| | File count | 8+ 래칫 |

### Cross-Repo Sync Points

| 변경 | 동기화 대상 |
|------|-----------|
| web API 엔드포인트 추가/변경 | `skill/badboss-report/references/api-spec.md` |
| 레벨 시스템 (시간/타이틀) 변경 | `skill/badboss-report/references/levels.md` |
| 에러 코드 추가/변경 | `skill/badboss-report/references/error-handling.md` |
| 리액션 타입 추가 | `skill/badboss-react/SKILL.md` |

## Conventions

- **Commit**: Conventional Commits (`type: 설명`)
- **PR Body**: HEREDOC 필수 (인라인 금지)
- **언어**: 소통 한국어, 코드/커밋 영어 허용
- **브랜치**: `feature/*` → `develop` → `main`

## Failure Modes

| 시나리오 | 조치 |
|----------|------|
| web CI 실패 | 로컬에서 Quality Gate 5종 재실행 후 수정 |
| skill CI 실패 | `bash -n` + ShellCheck 재실행 후 수정 |
| 크로스레포 불일치 감지 | 양쪽 PR 동시 생성 후 순차 머지 |
| Redis 연결 실패 (web) | docker-compose up 확인 |

## References

- web CI: `web/.github/workflows/ci.yml`
- web PR template: `web/.github/PULL_REQUEST_TEMPLATE.md`
- skill CI: `skill/.github/workflows/ci.yml`
- skill CONTRIBUTING: `skill/CONTRIBUTING.md`
- skill progress: `skill/docs/progress.md` (레포별 칸반, 참조용)
