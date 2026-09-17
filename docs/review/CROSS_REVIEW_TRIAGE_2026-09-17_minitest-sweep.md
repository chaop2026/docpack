# 교차검증 대조(triage) — minitest 6 × railties 전수 점검 (2026-09-17)

- 패키지: `docs/review/CODEX_REVIEW_PACKAGE_2026-09-17_minitest-sweep.md`
- 원문 결과: `docs/review/CODEX_RESULT_2026-09-17_minitest-sweep.md` (gpt-5.5, read-only, 88초)
- 🔴 **이 세션에서는 (a) 를 고치지 않았다.** 이 문서는 다음 수정 런의 입력이다.

Codex 가 낸 지적은 4건. 전부 아래에 분류했다. 빠진 것 없음.

---

## (a) 진짜 문제 — 1건

### a-1. 판정 기준 `minitest >= 6` 이 근거보다 넓다 (Codex 지적 1, 확신도 높음)

**Codex 의 말**: railties 8.0.5.1 은 `case Minitest::VERSION when /^5/ … when /^6/` 만 처리한다.
따라서 근거가 지탱하는 것은 "minitest **6.x** 는 8.0.5+ 에서 대응된다" 이지 `>= 6` 전체가 아니다.

**대조 결과 — 맞다.** 코드에 `else` 가 없다:

```ruby
# railties-8.0.5.1/lib/rails/test_unit/line_filtering.rb:8-15
case Minitest::VERSION
when /^5/ then obj.extend MT5
when /^6/ then obj.extend MT6
end                          # ← else 없음
```

minitest 7 이 나오면 **어느 분기에도 안 걸려 `LineFiltering` 이 아예 안 붙는다.**
그러면 `bin/rails test path/to/file.rb:42` 의 **줄 번호 필터링이 조용히 무력화**된다
(ArgumentError 로 죽지는 않는다 — 지정한 한 줄 대신 파일 전체가 도는 쪽으로 샌다).
이건 이 저장소들이 반복해 당한 **"조용한 실패"** 유형 그 자체다.

덧붙여 확인한 함정 하나: **`Minitest::VERSION` 은 믿을 수 없다.**
minitest 5.27.0 은 `minitest.rb:13` 에서 `VERSION = "5.26.2"` 로 상수를 잘못 박아 배포했다.
지금은 `/^5/` 에 걸려 결과가 같지만, railties 의 분기가 **이 오기된 상수에 의존**한다는 사실은
기록해 둘 값어치가 있다.

| 항목 | 내용 |
|---|---|
| 위험도 | **GREEN** — minitest 7 은 아직 없다. 현재 8개 프로젝트에 미치는 영향 0. |
| 수정 범위 | 8개 `CLAUDE.md` 의 판정 기준 문장 1줄을 `minitest 6.x` 로 좁히고, minitest 7 공백을 각주로 남긴다. 코드 변경 없음. |
| 언제 | 다음 문서 런. minitest 7 이 실제로 나오면 그때 재점검. |

---

## (b) 의견 차이 — 2건

### b-1. "새 핀이 필요 없다"는 결론이 drift 까지 고려하면 과하다 (Codex 지적 2, 확신도 보통)

**Codex 의 말**: `rails "~> 8.0.4"` 는 8.0.4 자체를 허용한다. railties 가 8.0.4 로 재해결되고
minitest 6 이 함께 오면 즉사 조건으로 돌아간다. "지금 안 죽었다" 와 "가드가 불필요하다" 는 별개다.

**대조 결과 — 기술적으로 맞다. 그런데 이번 런의 범위가 아니다.**
이번 작업의 지시는 *"minitest 비호환이 **확인된** 프로젝트만 핀하라"* 였다.
확인된 프로젝트는 0건이었으므로 핀도 0건이 맞다. 예방적 핀은 **다른 결정**이고,
8개 저장소의 의존성을 한꺼번에 바꾸는 일이라 Justin 의 GO 없이 할 일이 아니다.

- 결정 근거: 이번 런의 지시문 항목 (5) — "minitest 비호환이 **확인된** 프로젝트만"
- 실측 보강: `currencyrate` 의 `rails "~> 8.0.4"` 는 현재 railties **8.0.5** 로 해결돼 있다
  (`bundle list` 확인). `~>` 는 하한이라 `bundle install` 이 8.0.4 로 **내려가지는 않는다** —
  내려가려면 누가 명시적으로 lock 을 되돌리거나 제약을 바꿔야 한다. 즉 자연 발생 확률은 낮다.

| 항목 | 내용 |
|---|---|
| 잔여 위험 | **AMBER** — 확률은 낮지만 터지면 스위트 전체가 죽는다. |
| 다음 런 후보 | ① 핀을 넣는 대신 **`rails` 하한을 `>= 8.0.5` 로 올리는** 쪽이 더 정확한 가드다(원인을 막는다). ② 또는 CI 에 "요약 줄 부재 + exit≠0" 탐지를 넣는다. **어느 쪽이든 Justin 결정 사항.** |

### b-2. C6(pg segfault 는 minitest 무관)의 근거가 패키지에 없었다 (Codex 지적 4, 확신도 높음)

**Codex 의 말**: `PARALLEL_WORKERS=1` 통과 결과만 있고 segfault 원문 로그·스택이 없어
"별건" 이라는 결론을 확정할 수 없다.

**대조 결과 — 지적은 정당하다(패키지 결함). 결론 자체는 유지된다.**
로그를 안 넣은 것은 내 잘못이므로 여기에 원문을 붙인다:

```
Running 2965 tests in parallel using 8 processes
pg-1.6.3-arm64-darwin/lib/pg/connection.rb:944: [BUG] Segmentation fault at 0x0000000122d208f7
ruby 3.3.9 (2025-07-24 revision f5c772fc7c) +YJIT [arm64-darwin25]
-- Control frame information ---
c:0064 p:---- s:0340 e:000339 CFUNC  :connect_start
c:0063 ... pg-1.6.3-arm64-darwin/lib/pg/connection.rb:944
c:0062 ... pg-1.6.3-arm64-darwin/lib/pg/connection.rb:871
c:0061 ... pg-1.6.3-arm64-darwin/lib/pg.rb:88
c:0060 ... activerecord-8.1.3.1/.../postgresql_adapter.rb
```

minitest 무관이라고 보는 근거 셋:
1. 크래시 지점이 `PG::Connection#connect_start` 의 **C 확장**이다. minitest 프레임이 스택에 없다.
2. teachermatch 는 minitest **5.27.0** 이고 railties **8.1.3.1** 이다 — 비호환 조합 자체가 아니다.
3. 같은 코드가 `PARALLEL_WORKERS=1` 로는 **2965개를 전부 돌린다**. minitest 가 깨졌다면
   프로세스 수와 무관하게 죽어야 한다(§3-8 에서 강제 재현했을 때 단일/병렬 모두 죽었다).

⇒ 병렬 fork 후 DB 커넥션을 여는 경로의 문제다. **이번 범위 밖이라 고치지 않았다.**
teachermatch `CLAUDE.md` 에 회피책(`PARALLEL_WORKERS=1`)과 함께 기록해 뒀다.

---

## (c) 오탐 — 1건

### c-1. "lock 값과 실제 로드 값이 어긋난다" (Codex 지적 3, 확신도 보통)

**Codex 의 말**: docpack 은 lock 이 `5.27.0` 인데 로드는 `5.26.2` 다. 그런 환경이라면
lock 만으로 판정한 나머지 프로젝트의 런타임 판정은 지탱되지 않는다.

**반증 — 어긋나지 않았다. 내가 제시한 증거가 잘못이었다.**

괴리처럼 보인 것은 **minitest 5.27.0 이 자기 버전 상수를 잘못 박았기 때문**이다:

```
$ grep -n VERSION ~/.rbenv/versions/3.3.9/.../gems/minitest-5.27.0/lib/minitest.rb
13:  VERSION = "5.26.2" # :nodoc:
```

실제로 로드된 **파일 경로**를 찍어보면 lock 과 정확히 일치한다:

```
$ cd docpack && bundle exec ruby -e 'require "minitest"; puts Minitest::VERSION; puts $LOADED_FEATURES.grep(/minitest\.rb/).first'
5.26.2
/Users/sunghoon/.rbenv/versions/3.3.9/lib/ruby/gems/3.3.0/gems/minitest-5.27.0/lib/minitest.rb
                                                              ^^^^^^^^^^^^^^^^ lock 과 동일
```

**그리고 이 지적 덕분에 방법론 구멍을 실제로 닫았다.** 나머지 6개도 lock 이 아니라
bundler 가 해석한 값으로 전수 재확인했다(`bundle list`):

| 프로젝트 | bundler 가 쓰는 minitest | railties | 비호환? |
|---|---|---|---|
| currencyrate | 6.0.2 | 8.0.5 | 아니오 |
| docpack | 5.27.0 | 8.0.4 | 아니오(핀으로 막힘) |
| hellokorean-rails | 6.0.6 | 8.0.5.1 | 아니오 |
| naeilalbum | 6.0.3 | 8.0.5 | 아니오 |
| schoolkit | 6.0.6 | 8.0.5.1 | 아니오 |
| slotbook | 6.0.5 | 8.0.5 | 아니오 |
| teachermatch | 5.27.0 | 8.1.3.1 | 아니오 |
| tripbudget | 6.0.6 | 8.0.5 | 아니오 |

8개 전부 lock 과 일치. **"조치 0건" 결론은 그대로 선다.**

---

## Codex 가 지탱해 준 것

- **C3 / C4** — canary 가 `ActiveSupport::TestCase` 를 상속했고 railties 가 `LineFiltering` 을
  붙이는 대상이 바로 그 클래스이므로, 충돌 경로를 실제로 탄다. `0 runs` 5건이
  "러너가 죽었는데 빈 것처럼 보인 것" 일 가능성은 낮다. ← **이 작업의 핵심 판정이 살아남았다.**
- **C5** — §3-1 과 §3-2 의 `MT5#run` 본문이 같아 강제 재현이 8.0.4 와 동등하다.
- **C7** — 고장의 실제 신호는 `exit 1` + `요약 줄 부재` 라는 정정이 재현으로 지탱된다.

## 남은 숙제 (다음 런 입력)

| # | 항목 | 분류 | 위험도 |
|---|---|---|---|
| 1 | 판정 기준을 `minitest 6.x` 로 좁히고 minitest 7 공백을 각주로 | (a) | GREEN |
| 2 | 예방 가드를 넣을지 — `rails` 하한 `>= 8.0.5` vs minitest 핀 vs CI 탐지 | (b) | AMBER · **Justin 결정** |
| 3 | teachermatch 병렬 pg segfault 근본 원인 | (b) | AMBER · 범위 밖 |
