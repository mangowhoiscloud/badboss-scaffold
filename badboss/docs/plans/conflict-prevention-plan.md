# Merge Conflict Prevention Plan — Socratic Gate

> Date: 2026-03-26 | task_id: conflict-prevention
> Research: [merge-conflict-prevention.md](../research/merge-conflict-prevention.md)
> Scope: badboss-scaffold의 멀티 개발자 머지 충돌 방지 개선

---

## Socratic 5-Gate

### Q1. 코드에 이미 있는가?

| 항목 | 현재 상태 | 업계 표준 대비 |
|------|:---------:|:-------------:|
| CI 래칫 (web 5-job, skill 4-job) | **있음** | 동등 |
| PR 필수 + HEREDOC body | **있음** | 동등 |
| Stop 훅 (격차 감지) | **있음** | GEODE 동등 |
| Worktree 격리 + `.owner` | **없음** | L1 부재 |
| `git rerere` | **없음** | 0원 방어 누락 |
| Merge Queue / Auto-Merge | **없음** | CI 직렬화 부재 |
| Trunk-based (develop 제거) | **없음** | 머지 홉 2배 과잉 |
| 공유파일 분리 | **없음** | 충돌 핫스팟 방치 |
| CODEOWNERS | **없음** | 소유권 미지정 |
| Branch age 경고 | **없음** | 장기 분기 감지 부재 |

### Q2. 안 하면 무엇이 깨지는가?

| 시나리오 | 확률 | 비용 |
|----------|:----:|------|
| `constants.ts` 동시 수정 → 텍스트 충돌 | 높음 | 수동 해결 30분+ |
| develop 동시 머지 → stale CI 통과 후 main 깨짐 | 중간 | 롤백 + 핫픽스 |
| 에이전트 2개가 같은 `redis.ts` 수정 → 토큰 낭비 | 높음 | 작업 폐기 |
| 48시간+ 분기 → 충돌 해결 시간 12배 증가 (MS 연구) | 중간 | 생산성 저하 |

### Q3. 효과를 어떻게 측정하는가?

| 개선 | 측정 방법 |
|------|----------|
| develop 제거 | `git log --merges` 충돌 해결 커밋 수 before/after |
| git rerere | `git rerere status` — 자동 해결 건수 추적 |
| Merge Queue | queue에서 reject된 PR 수 (충돌 사전 차단) |
| Branch age 경고 | Stop 훅 로그에서 48h 초과 경고 건수 |
| 공유파일 분리 | `constants.ts` 관련 충돌 해결 커밋 수 → 0 목표 |

### Q4. 가장 단순한 구현은?

4-Phase 점진적 적용.

### Q5. 프론티어 3종 이상에서 동일 패턴인가?

| 패턴 | Google | Claude Code | Cursor | Codex | CAID 논문 | 합의 |
|------|:------:|:-----------:|:------:|:-----:|:---------:|:----:|
| Trunk-based / short-lived branch | O | O | O | O | O | **5/5** |
| Worktree 격리 | O (CitC) | O | O | O | O | **5/5** |
| 파일 소유권 분리 | O | O (Agent Teams) | — | — | O | **3/5** |
| Merge Queue | O (Piper) | — | — | — | — | 1/5 |
| git rerere | — | — | — | — | — | 0/5 |

**Trunk-based + Worktree + 파일 소유권 분리** = 3종 이상 합의. 채택.

---

## Implementation Plan

### Phase 0: 즉시 적용 (5분)

**git rerere 활성화**

```bash
git config --global rerere.enabled true
```

- 비용: 0
- 효과: 반복 충돌 자동 해결
- 리스크: 없음

### Phase 1: GitHub Flow 전환 (1시간)

**develop 브랜치 제거 → main + short-lived feature branches**

#### 변경 사항

1. **CLAUDE.md 갱신**
   - Workflow: `feature/* → develop → main` → `feature/* → main`
   - CANNOT: "develop에 직접 push 금지" → "main에 직접 push 금지"
   - 48시간 규칙 추가: 브랜치 수명 48시간 초과 금지

2. **Stop 훅 개선** (`check-sync.sh`)
   - branch age 48h 경고 추가
   - develop→main 격차 체크 → 제거 (develop 없으므로)
   - feature→main rebase 필요 여부 체크 추가

3. **web/skill 서브레포**
   - 각 레포의 develop 브랜치를 main에 머지 후 삭제
   - CI trigger: `[main, develop]` → `[main]`
   - PR base: develop → main

4. **GitHub 설정**
   - Merge Queue 활성화 (repo settings → Branch protection → Require merge queue)
   - Auto-Merge 활성화

#### 근거

- Google, Claude Code, Cursor, Codex, CAID 논문 — **5/5 합의**
- develop 브랜치 = 장기 통합 분기점 = 충돌의 근원
- 머지 홉 2단계 → 1단계로 축소

### Phase 2: 공유파일 핫스팟 해소 (반나절)

**constants.ts 분리 + CODEOWNERS**

#### 변경 사항

1. **`web/src/lib/constants.ts` 분리**

   ```
   constants.ts (현재 — 모든 상수 단일 파일)
     → levels.ts      (레벨 시스템 상수)
     → reactions.ts   (리액션 타입 상수)
     → limits.ts      (Rate limit, 시간 제한 상수)
     → feed.ts        (피드 관련 상수)
   ```

   - 효과: 각 기능 작업 시 해당 파일만 수정. 교차 수정 확률 대폭 감소.

2. **CODEOWNERS 추가** (`web/.github/CODEOWNERS`)

   ```
   # API routes
   src/app/api/          @backend-owner

   # UI components
   src/components/       @frontend-owner

   # Shared libs (충돌 핫스팟)
   src/lib/redis.ts      @backend-owner
   src/lib/levels.ts     @backend-owner
   src/lib/limits.ts     @backend-owner
   ```

#### 근거

- Google 데이터: 충돌의 80%가 명확한 소유자 없는 12% 파일에서 발생
- Bird et al. (Microsoft, 2011): 높은 코드 소유권 = 적은 버그
- 파일 분리: Micro-frontend 연구에서 15-25% 머지 충돌 감소 실증

### Phase 3: 고급 도구 (필요 시)

**팀 확장 또는 에이전트 병렬 작업 시**

| 도구 | 조건 | 효과 |
|------|------|------|
| **Mergiraf** | JS/TS 충돌이 잦아질 때 | AST 기반 거짓 충돌 자동 해결 |
| **Clash CLI** | Claude Code worktree 병렬 사용 시 | PreToolUse 훅으로 실시간 충돌 감지 |
| **Graphite** | 대형 feature를 stacked PR로 분할 시 | stack-aware merge queue |
| **Feature Flags** | 미완성 기능을 main에 머지해야 할 때 | `next.config.ts` 환경변수 기반 |

---

## Risk Assessment

| 리스크 | 완화 |
|--------|------|
| develop 제거 시 staging 환경 부재 | Vercel preview deployment으로 PR별 staging 자동 생성 |
| 48시간 규칙이 대형 feature에 맞지 않음 | feature flag + 부분 머지로 대응 |
| CODEOWNERS가 리뷰 병목 | 2인 팀에서는 구두 합의로 대체 가능 |
| git rerere가 잘못된 해결을 기억 | `git rerere forget <pathspec>`으로 리셋 |

---

## Checklist

- [ ] Phase 0: `git config --global rerere.enabled true`
- [ ] Phase 1: CLAUDE.md 워크플로우 갱신 (GitHub Flow)
- [ ] Phase 1: check-sync.sh에 branch age 경고 추가
- [ ] Phase 1: web/skill develop → main 머지 후 develop 삭제
- [ ] Phase 1: GitHub Merge Queue 활성화
- [ ] Phase 2: constants.ts 도메인별 분리
- [ ] Phase 2: CODEOWNERS 추가
- [ ] Phase 3: (팀 확장 시) Mergiraf / Clash / Graphite 도입 검토
