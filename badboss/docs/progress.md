# BadBoss Progress Board

> web + skill 통합 칸반 보드. 크로스레포 작업 추적.
> 마지막 갱신: 2026-03-26 (conflict-prevention Done)
> **규칙**: 이 파일은 루트에서만 수정. web/skill 레포에서 수정 금지.

---

## Kanban

### Backlog

| task_id | 설명 | 레포 | 우선순위 | 비고 |
|---------|------|------|---------|------|
| | | | | |

### In Progress

| task_id | 설명 | 레포 | 담당 | 브랜치 | 시작일 |
|---------|------|------|------|--------|--------|
| | | | | | |

### In Review

| task_id | 설명 | 레포 | PR | CI |
|---------|------|------|-----|-----|
| | | | | |

### Done

| task_id | 설명 | 레포 | PR | 완료일 |
|---------|------|------|-----|--------|
| conflict-prevention | 멀티 개발자 머지 충돌 방지 리서치 + 플랜 | root | [#1](https://github.com/mangowhoiscloud/badboss-scaffold/pull/1) | 2026-03-26 |
| scaffold-init | 통합 하네스 스캐폴딩 초기 구성 | root | — | 2026-03-26 |

---

## Rules

- Backlog → Done 직접 이동 금지 (반드시 In Progress 경유)
- task_id는 kebab-case, 생성 후 변경 금지
- 레포 컬럼: `web`, `skill`, `both`, `root`
- Done 항목은 30일 후 아카이브
- 크로스레포 작업(`both`)은 양쪽 PR 링크 모두 기재
