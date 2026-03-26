# Multi-Developer Merge Conflict Prevention — Research Report

> Date: 2026-03-26 | task_id: conflict-prevention
> Scope: 다수 개발자/에이전트가 동일 레포에서 병렬 작업 시 develop 브랜치 머지 충돌 방지

---

## 1. 문제 정의

Worktree 격리는 **작업 중** 파일시스템 충돌만 방지합니다. **머지 시점**의 텍스트 충돌과 의미적 충돌은 별도의 방어가 필요합니다.

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
| `web/src/lib/redis.ts` | 높음 | 거의 모든 기능이 수정하는 공유 파일 |
| `web/src/lib/constants.ts` | 높음 | 상수 추가가 같은 위치에 삽입됨 |
| `docs/progress.md` | 중간 | 동시 칸반 갱신 시 테이블 행 충돌 |
| `skill/references/api-spec.md` | 중간 | 크로스레포 동기화 시 동시 수정 |
| develop 동시 머지 | 높음 | stale CI — 선착순 머지 후 후속 PR base 변경 |

---

## 2. 프론티어 도구별 현황 (2026-03 기준)

### 2.1 AI 코딩 도구

| 도구 | 격리 | 충돌 감지 | 충돌 해결 | 성숙도 |
|------|------|----------|----------|--------|
| **Claude Code** | worktree + `.owner` | Clash CLI (PreToolUse 훅, 42★, 최종 커밋 2026-02-03) | `/resolve-conflicts` 커뮤니티 스킬 + Agent Teams (2026-02) | 격리=Production, 감지=Experimental |
| **Cursor 2.0** | worktree (최대 20개) | 없음 | "Resolve in Chat" AI 해결 | Production |
| **Codex CLI** | sandbox | 없음 | 시도했으나 실패 사례 다수 | Broken |
| **Zed v0.228** | agent merge | 있음 | AI contextual diff (2026-03-23 출시) | Production |
| **GitHub Agent HQ** | PR 기반 | Merge Queue | 없음 (수동 해결) | Public Preview |

### 2.2 머지 인프라

| 도구 | 방식 | 효과 | 성숙도 |
|------|------|------|--------|
| **GitHub Merge Queue** | PR 직렬 검증 (latest base + queue 앞 PR) | semantic conflict 방지 | GA (public repo 무료, private은 Enterprise Cloud만) |
| **Graphite** | stack-aware merge queue + auto-rebase | 순서 보장 + 캐스케이딩 rebase | Production (Shopify, Asana) |
| **Mergify** | 배치 merge + auto-rebase + bisect | 자동화 | Production |
| **Mergiraf** | AST 기반 머지 (tree-sitter, 23개 언어 + 10개 포맷, **TS/TSX/JSX 지원 확인**) | 거짓 충돌 제거 | Production |

### 2.3 멀티에이전트 오케스트레이터 (2026-03 신규)

| 도구 | 방식 | 충돌 방어 | 규모 |
|------|------|----------|------|
| **Overstory** (1.1K★) | tmux + worktree + SQLite mail + FIFO merge queue | 4-tier 충돌 해결, 11개 에이전트 런타임 지원 | Production |
| **ComposioHQ Agent Orchestrator** (5.4K★) | worktree + CI 재시도(2회) + 플러그인 8슬롯 | PR 상태 추적, 3,288 테스트 | Production |
| **NTM** (2026-03-18) | Named tmux + broadcast + TUI | 충돌 감지 (해결은 수동) | Early |
| **Reconcile AI** | LLM 기반 headless 충돌 해결 + git hook | 파일타입별 설정 가능 | Experimental |

### 2.4 즉시 사용 가능한 도구

| 도구 | 비용 | 적용 시간 | 효과 |
|------|:----:|:---------:|------|
| `git rerere` | 무료 | 1분 | 반복 충돌 자동 해결 |
| GitHub Merge Queue | 무료 (public repo) | 5분 | PR 직렬 검증 |
| GitHub Auto-Merge | 무료 | 5분 | CI 통과 시 자동 머지 |
| VS Code + Copilot 머지 해결 | 구독 | 즉시 | AI 충돌 해결 UI (2025-09 GA) |
| Mergiraf | 무료 | 30분 | AST 기반 거짓 충돌 제거 (TS/TSX 지원) |
| Clash CLI | 무료 | 30분 | worktree 간 실시간 충돌 감지 |

---

## 3. 브랜치 전략 비교

### 3.1 Gitflow (현재 badboss)

```
feature/* → develop → main
```

- develop이 장기 통합 브랜치로 작동하며 충돌이 누적됩니다.
- 머지 홉이 2단계이므로 충돌 표면이 2배입니다.
- 업계 조사에 따르면 Gitflow 채택률은 지속적으로 하락하고 있으며, trunk-based 및 GitHub Flow가 대체하는 추세입니다.
- Microsoft Research에 따르면 대규모 프로젝트에서 전체 머지의 10-20%가 "bad merge"에 해당합니다 (Safe Program Merges at Scale, Microsoft Research Blog).

### 3.2 GitHub Flow (권장)

```
feature/* → main
```

- 머지 홉이 1단계로 줄어들며, 브랜치 수명이 짧아집니다.
- 소규모 팀에 가장 적합한 전략입니다.

### 3.3 Trunk-Based Development (최종 목표)

```
main (직접 커밋 또는 1일 이하 브랜치)
```

- Google이 100K+ 엔지니어 규모에서 운영하는 방식입니다.
- Feature flag로 미완성 기능을 숨기며, 장기 브랜치가 근본적으로 존재하지 않습니다.
- Google의 단일 trunk에는 하루 약 45,000건의 커밋이 발생하며, 브랜치 수준의 머지 충돌은 설계적으로 제거됩니다 (Potvin & Levenberg, CACM 2016).

---

## 4. 대기업 사례

### 4.1 Google (Piper / CitC)

- **전략**: Trunk-based + feature flag + 낙관적 동시성
- **메커니즘**: 장기 브랜치를 사용하지 않습니다. 모든 개발자가 trunk에서 작업하며, CitC(Clients in the Cloud)가 가상 워크스페이스를 제공합니다.
- **핵심**: "충돌을 해결하는 것이 아니라, 충돌 자체를 만들지 않는 것"
- **적용 범위**: 전략(trunk-based)만 차용할 수 있으며, 도구(Piper)는 비공개입니다.
- **출처**: Potvin & Levenberg, "Why Google Stores Billions of Lines of Code in a Single Repository", CACM 2016

### 4.2 Microsoft (LLMinus)

- **대상**: Linux 커널 머지 충돌
- **방식**: 시맨틱 임베딩으로 유사한 과거 충돌을 검색하고, LLM이 해결을 제안합니다.
- **상태**: RFC v2 단계이며, 아직 실험적입니다.
- **출처**: Phoronix, "LLMinus RFC v2", 2026

### 4.3 Shopify + Asana (Graphite)

- **Shopify 성과**: 개발자당 **33% 더 많은 PR** 머지. 전체 PR의 22%가 stacked PR로 구성됩니다.
- **Asana 성과**: 주 **7시간** 절약, 21% 더 많은 코드 배포, 17% 더 많은 PR 머지 (도입 30일 이내).
- **방식**: Stacked PR + stack-aware merge queue.
- **출처**: Graphite Customer Stories (graphite.com/customer/shopify, graphite.com/customer/asana)

---

## 5. 학술 연구

### 5.1 CAID (CMU, 2026-03-23, arXiv:2603.21489)

"Effective Strategies for Asynchronous Software Engineering Agents" — 가장 엄밀한 멀티에이전트 머지 연구입니다.

- **핵심 발견**: 위임 품질(delegation quality)이 에이전트 수보다 결과를 결정합니다.
- **성능 수치**:
  - Claude Sonnet 4.5: PaperBench +6.1pp (2 에이전트), Commit0-Lite +6.0pp (4 에이전트)
  - MiniMax 2.5: PaperBench +26.3pp, Commit0-Lite +14.7pp
- **최적 병렬**: 2-4 에이전트에서 정점입니다. 8개 이상에서는 통합 오버헤드로 성능이 저하됩니다.
- **격리 권고**: "소프트 격리(지시 수준)는 불충분하며, 하드 격리(worktree)가 필수입니다."
- **충돌 방지 3원칙**: (1) 에이전트별 독립 worktree, (2) git merge로 충돌을 명시적으로 표면화, (3) 통합 전 자체 검증(실행 가능한 테스트)

### 5.2 Crystal (University of Washington)

- **방식**: 투기적 머지(speculative merge)로 충돌을 **사전 예측**합니다.
- **검증**: 9개 OSS 프로젝트, 3.4M LOC, 550K 개발 버전에서 검증되었습니다.
- **상태**: 학술 프로토타입이며, 상용화되지 않았습니다.
- **출처**: Brun et al., ESEC/FSE 2011

### 5.3 Harmony (Source.dev, 2026)

- **성과**: 파인튜닝 SLM(Llama-3.1-8B, Qwen3-4B)으로 **88-90%** 자동 해결을 달성했습니다.
- **한계**: Android/AOSP에 특화되어 있으며, 범용이 아닙니다.
- **출처**: Source.dev, "Harmony Preview", 2026

### 5.4 Bird et al. (Microsoft, 2011)

- **제목**: "Don't Touch My Code! Examining the Effects of Ownership on Software Quality"
- **발표**: ESEC/FSE 2011
- **대상**: Windows Vista 및 Windows 7 코드베이스
- **핵심 발견**: 소수의 주요 기여자가 높은 소유 비율을 가진 컴포넌트에서 결함이 현저히 적었습니다. 분산된 소유권(minor contributor 비율 높음)은 사전/사후 릴리스 결함과 강하게 상관했습니다. 소유권 메트릭이 코드 복잡도 메트릭보다 더 강력한 결함 예측 인자입니다.
- **출처**: [microsoft.com/en-us/research/publication/dont-touch-my-code](https://www.microsoft.com/en-us/research/publication/dont-touch-my-code-examining-the-effects-of-ownership-on-software-quality/)

---

## 6. 해결된 것 vs 미해결

| 해결됨 (2026-03 기준) | 미해결 |
|---|---|
| 파일시스템 격리 (worktree = 업계 표준) | 선제적 충돌 방지 — 겹치지 않는 작업 배분은 여전히 사람의 기술에 의존 |
| CI 직렬화 (Merge Queue = 업계 표준) | 의미적 충돌 — 다른 파일을 수정했으나 서로의 가정을 깨는 경우를 감지할 수 없음 |
| 거짓 충돌 제거 (Mergiraf, AST 기반 머지) | 에이전트 작업 낭비 — 머지 시점에 감지되면 이미 토큰이 소진된 상태 |
| 단순 충돌 AI 해결 (lock 파일, import 순서 등) | 실시간 교차 인식 — 에이전트가 다른 에이전트의 작업을 알지 못함 |

---

## 7. 합의 수렴 방향

업계 표준은 아직 부재하나, 프론티어 5종(Google, Claude Code, Cursor, Codex, CAID 논문)에서 다음 3가지에 대한 합의가 수렴하고 있습니다.

1. **Trunk-based / short-lived branch** — 5/5 합의
2. **Worktree 격리** — 4/5 합의 (Google은 CitC로 대체)
3. **파일 소유권 분리** — 3/5 합의

> "develop 브랜치 자체가 문제입니다." — 2026년 업계 컨센서스

---

## Sources

### 학술 논문
- Geng & Neubig, "Effective Strategies for Asynchronous Software Engineering Agents", [arXiv:2603.21489](https://arxiv.org/html/2603.21489), March 23, 2026
- Bird et al., "Don't Touch My Code! Examining the Effects of Ownership on Software Quality", ESEC/FSE 2011, [Microsoft Research](https://www.microsoft.com/en-us/research/publication/dont-touch-my-code-examining-the-effects-of-ownership-on-software-quality/)
- Brun et al., "Crystal: Proactive Detection of Collaboration Conflicts", ESEC/FSE 2011, [UW](https://cs.uwaterloo.ca/~rtholmes/papers/fse_2011_brun.pdf)
- Potvin & Levenberg, "Why Google Stores Billions of Lines of Code in a Single Repository", [CACM 2016](https://cacm.acm.org/research/why-google-stores-billions-of-lines-of-code-in-a-single-repository/)

### 도구 및 플랫폼
- [Clash CLI](https://github.com/clash-sh/clash) — March 2026 (42★, last commit 2026-02-03)
- [Mergiraf](https://codeberg.org/mergiraf/mergiraf) — Active 2026 (TS/TSX/JSX 지원 확인)
- [Overstory](https://github.com/jayminwest/overstory) — March 2026 (1.1K★)
- [ComposioHQ Agent Orchestrator](https://github.com/ComposioHQ/agent-orchestrator) — March 2026 (5.4K★)
- [GitHub Merge Queue Docs](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue)
- [GitHub Agent HQ Blog](https://github.blog/news-insights/company-news/welcome-home-agents/) — March 2026

### 사례 연구
- [Graphite Customer Story: Shopify](https://graphite.com/customer/shopify) — 33% more PRs per dev
- [Graphite Customer Story: Asana](https://graphite.com/customer/asana) — 7 hrs/week saved, 21% more code shipped
- [Haacked: Resolve Merge Conflicts](https://haacked.com/archive/2026/03/25/resolve-merge-conflicts/) — March 25, 2026
- [Harmony Preview (Source.dev)](https://www.source.dev/journal/harmony-preview) — 88-90% auto-resolution
- [LLMinus RFC v2 (Phoronix)](https://www.phoronix.com/news/LLMinus-RFC-v2) — 2026
- [Microsoft Research: Safe Program Merges at Scale](https://www.microsoft.com/en-us/research/blog/safe-program-merges-at-scale-a-grand-challenge-for-program-repair-research/)

### 가이드 및 블로그
- [Zed v0.228 Agent Merge Resolution](https://leadai.dev/insider/zed-v0-228-0-agent-powered-merge-resolution-and-contextual-diffs) — March 23, 2026
- [Claude Code Worktrees Guide](https://claudefa.st/blog/guide/development/worktree-guide) — 2026
- [Cursor Parallel Agents Docs](https://cursor.com/docs/configuration/worktrees) — 2026
- [Trunk-Based Development](https://trunkbaseddevelopment.com/)
- [Agentmaxxing Guide](https://vibecoding.app/blog/agentmaxxing) — 2026
