# Multi-Developer Merge Conflict Prevention — Research Report

> Date: 2026-03-26 | task_id: conflict-prevention
> Scope: 다수 개발자/에이전트가 동일 레포에서 병렬 작업 시 develop 브랜치 머지 충돌 방지

---

## 1. 문제 정의

Worktree 격리는 **작업 중** 파일시스템 충돌만 방지한다. **머지 시점** 텍스트 충돌, 의미적 충돌은 별도 방어가 필요하다.

```
개발자 A (worktree A)              개발자 B (worktree B)
  feature/feed-api                   feature/level-system
  redis.ts +캐시키                    redis.ts +TTL 변경
  constants.ts +FEED_LIMIT           constants.ts +LEVEL_THRESHOLD
       │                                  │
       ├─ PR → main ✅                    │
       │                                  ├─ PR → main ❌ CONFLICT
```

### 충돌 핫스팟 (badboss 실측)

| 파일 | 위험도 | 원인 |
|------|:------:|------|
| `web/src/lib/redis.ts` | 높음 | 거의 모든 기능이 건드리는 공유 파일 |
| `web/src/lib/constants.ts` | 높음 | 상수 추가가 같은 위치에 삽입 |
| `docs/progress.md` | 중간 | 동시 칸반 갱신 시 테이블 행 충돌 |
| `skill/references/api-spec.md` | 중간 | 크로스레포 동기화 시 동시 수정 |
| develop 동시 머지 | 높음 | stale CI — 선착순 머지 후 후속 PR base 변경 |

---

## 2. 프론티어 도구별 현황 (2026-03 기준)

### 2.1 AI 코딩 도구

| 도구 | 격리 | 충돌 감지 | 충돌 해결 | 성숙도 |
|------|------|----------|----------|--------|
| **Claude Code** | worktree + `.owner` | Clash CLI (PreToolUse 훅) | `/resolve-conflicts` 커뮤니티 스킬 | 격리=Production, 감지=Experimental |
| **Cursor 2.0** | worktree (최대 20개) | 없음 | "Resolve in Chat" AI | Production |
| **Codex CLI** | sandbox | 없음 | 시도했으나 실패 다수 | Broken |
| **Zed v0.228** | agent merge | 있음 | AI contextual diff | Production (2026-03-23) |
| **GitHub Agent HQ** | PR 기반 | Merge Queue | 없음 | Public Preview |

### 2.2 머지 인프라

| 도구 | 방식 | 효과 | 성숙도 |
|------|------|------|--------|
| **GitHub Merge Queue** | PR 직렬 검증 (latest base + queue 앞 PR) | semantic conflict 방지 | GA (public + Enterprise) |
| **Graphite** | stack-aware merge queue + auto-rebase | 순서 보장 + 캐스케이딩 rebase | Production (Shopify, Asana) |
| **Mergify** | 배치 merge + auto-rebase + bisect | 자동화 | Production |
| **Mergiraf** | AST 기반 머지 (tree-sitter, 33개 언어) | 거짓 충돌 제거 | Production |

### 2.3 즉시 사용 가능한 도구

| 도구 | 비용 | 적용 시간 | 효과 |
|------|:----:|:---------:|------|
| `git rerere` | 무료 | 1분 | 반복 충돌 자동 해결 |
| GitHub Merge Queue | 무료 | 5분 | PR 직렬 검증 |
| GitHub Auto-Merge | 무료 | 5분 | CI 통과 시 자동 머지 |
| VS Code + Copilot 머지 해결 | 구독 | 즉시 | AI 충돌 해결 UI |
| Mergiraf | 무료 | 30분 | AST 기반 거짓 충돌 제거 |
| Clash CLI | 무료 | 30분 | worktree 간 실시간 충돌 감지 |

---

## 3. 브랜치 전략 비교

### 3.1 Gitflow (현재 badboss)

```
feature/* → develop → main
```

- **문제**: develop이 장기 통합 브랜치로 충돌 누적. 머지 홉 2단계.
- JetBrains 조사: 채택률 22%로 하락세.
- Microsoft 연구: 3일+ 분기 시 충돌 해결 시간 **12배** 증가.

### 3.2 GitHub Flow (권장)

```
feature/* → main
```

- **이점**: 머지 홉 1단계. 짧은 브랜치 수명.
- 소규모 팀에 가장 적합.

### 3.3 Trunk-Based Development (최종 목표)

```
main (직접 커밋 또는 1일 이하 브랜치)
```

- Google이 100K+ 엔지니어로 운영하는 방식.
- Feature flag로 미완성 기능을 숨김.
- 충돌 해결 시간 70-80% 감소 (업계 데이터).

---

## 4. 대기업 사례

### 4.1 Google (Piper / CitC)

- **전략**: Trunk-based + feature flag + 낙관적 동시성
- **메커니즘**: 브랜치를 아예 안 씀. 모든 개발자가 trunk에 작업. CitC(Clients in the Cloud)로 가상 워크스페이스 제공.
- **핵심**: "충돌 해결이 아니라 충돌 자체를 안 만드는 것"
- **적용**: 전략(trunk-based)만 차용 가능. 도구(Piper)는 비공개.

### 4.2 Microsoft (LLMinus)

- **대상**: Linux 커널 머지 충돌
- **방식**: 시맨틱 임베딩으로 유사 과거 충돌 검색 → LLM 해결 제안
- **상태**: RFC v2. 아직 실험 단계.

### 4.3 Shopify (Graphite)

- **성과**: 개발자당 33% 더 많은 PR 머지. 주 7시간 절약.
- **방식**: Stacked PR + stack-aware merge queue.

---

## 5. 학술 연구

### 5.1 CAID (CMU, 2026-03-23, arXiv:2603.21489)

가장 엄밀한 멀티에이전트 머지 연구.

- **핵심 발견**: 위임 품질(delegation quality) > 에이전트 수
- **최적 병렬**: 3-5 에이전트에서 정점. 그 이상은 수확 체감.
- **격리 필수**: "소프트 격리(지시 수준)는 불충분. 하드 격리(worktree)가 필수."
- **충돌 해결**: 표준 git merge 사용. 충돌은 재작업으로 해결.

### 5.2 Crystal (University of Washington)

- **방식**: 투기적 머지로 충돌 **사전 예측**
- **검증**: 9개 OSS 프로젝트, 3.4M LOC, 550K 개발 버전
- **상태**: 학술 프로토타입. 상용화 안 됨.

### 5.3 Harmony (Source.dev, 2026)

- **성과**: 파인튜닝 SLM(Llama-3.1-8B, Qwen3-4B)으로 **88-90%** 자동 해결
- **한계**: Android/AOSP 특화. 범용 아님.

---

## 6. 해결된 것 vs 미해결

| 해결됨 | 미해결 |
|--------|--------|
| 파일시스템 격리 (worktree = 업계 표준) | 선제적 충돌 방지 (겹치지 않는 작업 배분 = 사람의 기술) |
| CI 직렬화 (Merge Queue = 업계 표준) | 의미적 충돌 (다른 파일이지만 서로의 가정을 깨는 경우) |
| 거짓 충돌 제거 (Mergiraf, AST 기반) | 에이전트 작업 낭비 (머지 시점 감지 = 이미 토큰 소진) |
| 단순 충돌 AI 해결 (lock 파일, import 순서) | 실시간 교차 인식 (에이전트가 다른 에이전트 작업을 모름) |

---

## 7. 합의 수렴 방향

업계 표준은 아직 없으나, 프론티어 5종(Google, Claude Code, Cursor, Codex, CAID 논문)에서 다음 3가지가 합의:

1. **Trunk-based / short-lived branch** — 5/5 합의
2. **Worktree 격리** — 4/5 합의 (Google은 CitC로 대체)
3. **파일 소유권 분리** — 3/5 합의

> "develop 브랜치 자체가 문제다." — 2026년 업계 컨센서스

---

## Sources

- [CAID Paper (CMU, arXiv:2603.21489)](https://arxiv.org/html/2603.21489) — March 23, 2026
- [Clash CLI (GitHub)](https://github.com/clash-sh/clash) — March 2026
- [Mergiraf (Codeberg)](https://codeberg.org/mergiraf/mergiraf) — Active 2026
- [Haacked: Resolve Merge Conflicts (March 25, 2026)](https://haacked.com/archive/2026/03/25/resolve-merge-conflicts/)
- [Zed v0.228 Agent Merge Resolution](https://leadai.dev/insider/zed-v0-228-0-agent-powered-merge-resolution-and-contextual-diffs) — March 23, 2026
- [GitHub Agent HQ Blog](https://github.blog/news-insights/company-news/welcome-home-agents/) — March 2026
- [Graphite Stack-Aware Merge Queue](https://graphite.com/blog/the-first-stack-aware-merge-queue) — 2026
- [Harmony 88-90% Auto-Resolution (Source.dev)](https://www.source.dev/journal/harmony-preview) — 2026
- [LLMinus RFC v2 (Phoronix)](https://www.phoronix.com/news/LLMinus-RFC-v2) — 2026
- [Crystal: Proactive Conflict Detection (UW)](https://cs.uwaterloo.ca/~rtholmes/papers/fse_2011_brun.pdf)
- [Claude Code Worktrees Guide](https://claudefa.st/blog/guide/development/worktree-guide) — 2026
- [Cursor Parallel Agents Docs](https://cursor.com/docs/configuration/worktrees) — 2026
- [Trunk-Based Development (Official)](https://trunkbaseddevelopment.com/)
- [Google Monorepo Paper (ACM)](https://cacm.acm.org/research/why-google-stores-billions-of-lines-of-code-in-a-single-repository/)
- [Agentmaxxing Guide](https://vibecoding.app/blog/agentmaxxing) — 2026
- [ComposioHQ Agent Orchestrator (GitHub)](https://github.com/ComposioHQ/agent-orchestrator) — 2026
