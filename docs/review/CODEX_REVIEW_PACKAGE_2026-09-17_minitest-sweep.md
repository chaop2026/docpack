# Codex 교차검증 패키지 — minitest 6 × railties 전수 점검 (2026-09-17)

## ① 리뷰어용 프롬프트

당신은 Ruby/Rails 빌드·테스트 인프라를 검증하는 독립 검토자다.
아래는 한 에이전트가 `~/Projects` 의 Rails 프로젝트 전체를 훑어
"minitest 6 과 railties 조합 때문에 테스트 스위트가 죽어 있는가" 를 조사한 결과다.
**코드 변경은 없었고, 결론은 "docpack 외에는 조치 불필요" 였다.**

당신이 판정할 것은 **그 결론과 그 근거가 옳은가** 다.

**분류는 이 4가지로 고정한다**: `정책 위반` / `보안` / `데이터 손실 위험` / `논리 오류`.
이 작업의 성격상 대부분은 `논리 오류`(= 근거가 결론을 지탱하지 못함)로 떨어질 것이다.

- 지적마다 **근거를 파일:줄 또는 아래 인용 블록의 위치로** 달아라. 근거 없는 지적은 적지 마라.
- 지적마다 **확신도(높음/보통/낮음)** 를 밝혀라. 낮아도 적되 낮다고 밝혀라.
- ⛔**여기 없는 파일은 추측하지 마라.** 필요하면 "이 경로의 파일을 달라" 고 요청하라.
- ⛔**스타일 지적·"테스트를 더 늘려라" 같은 일반론은 쓰지 마라.**
- ⛔**정본 문서를 고치자는 제안은 쓰지 마라.**

이 저장소들이 반복해 당한 실패 유형이라 특히 의심해야 할 것:
**조용한 실패**(죽었는데 통과처럼 보임) · **공허한 검사**(단언이 아무것도 안 봄) ·
**숫자 갈라짐**(같은 값이 두 곳에서 다르게 계산됨).

**가장 중요한 질문**: 아래 §5 의 주장 C1~C8 중 **근거가 결론을 지탱하지 못하는 것**이 있는가?
특히 **"0 runs 는 죽은 게 아니라 진짜 빈 것"** 이라는 판정이 위음성일 수 있는 경로가 있는가?

---

## ② 무엇을 했는가 (변경 요약)

- **코드 변경 0건.** Gemfile / Gemfile.lock 단 한 줄도 바꾸지 않았다.
- 8개 Rails 프로젝트의 `CLAUDE.md` 에 점검 결과를 문서로만 추가하고 커밋했다.
- 조사 과정에서 임시로 만든 것은 전부 삭제했다(canary 테스트 5개, docpack 프로브 Gemfile 2개).

---

## ③ 근거 자료 (전문)

### 3-1. railties 8.0.4 — `lib/rails/test_unit/line_filtering.rb` **전문**

```ruby
# frozen_string_literal: true

require "rails/test_unit/runner"

module Rails
  module LineFiltering # :nodoc:
    def run(reporter, options = {})
      options = options.merge(filter: Rails::TestUnit::Runner.compose_filter(self, options[:filter]))

      super
    end
  end
end
```

### 3-2. railties 8.0.5.1 — 같은 파일 **전문**

```ruby
# frozen_string_literal: true

require "rails/test_unit/runner"

module Rails
  module LineFiltering # :nodoc:
    def self.extended(obj)
      require "minitest"

      case Minitest::VERSION
      when /^5/ then
        obj.extend MT5
      when /^6/ then
        obj.extend MT6
      end
    end

    module MT5
      def run(reporter, options = {})
        options = options.merge(filter: Rails::TestUnit::Runner.compose_filter(self, options[:filter]))

        super
      end
    end

    module MT6
      def run_suite(reporter, options = {})
        options = options.merge(include: Rails::TestUnit::Runner.compose_filter(self, options[:include]))

        super
      end
    end
  end
end
```

### 3-3. 이 모듈이 붙는 지점 — `lib/rails/test_unit/railtie.rb` (양 버전 동일)

```ruby
    initializer "test_unit.line_filtering" do
      ActiveSupport.on_load(:active_support_test_case) {
        ActiveSupport::TestCase.extend Rails::LineFiltering
      }
    end
```

### 3-4. 설치된 railties 전수 확인 (실행 출력 원문)

```
$ for d in ~/.rbenv/versions/*/lib/ruby/gems/3.3.0/gems/railties-*/lib/rails/test_unit/line_filtering.rb; do ... grep -c "def run_suite" ...; done
railties 8.0.0 : run_suite=0
railties 8.0.2 : run_suite=0
railties 8.0.4 : run_suite=0
railties 8.0.5 : run_suite=1
railties 8.0.5.1 : run_suite=1
railties 8.1.3.1 : run_suite=1
```

### 3-5. 프로젝트 전수 목록 — 탐색 방법과 결과

```
$ find ~/Projects -name Gemfile -not -path "*/vendor/*" -not -path "*/node_modules/*" -not -path "*/.git/*" \
    | xargs grep -l '^\s*gem\s*["'\'']rails["'\'']'
~/Projects/docpack/Gemfile
~/Projects/schoolkit/Gemfile
~/Projects/naeilalbum/Gemfile
~/Projects/slotbook/Gemfile
~/Projects/teachermatch/Gemfile
~/Projects/hellokorean-rails/Gemfile
~/Projects/tripbudget/Gemfile
~/Projects/currencyrate/Gemfile
~/Projects/_archive/worktree/phase-3-peak-season/teachermatch/Gemfile   ← 아카이브

$ find ~/Projects -name application.rb -path "*/config/*"   # 같은 9개. 교차확인용
```

### 3-6. 프로젝트별 Gemfile.lock 실측 + 실행 결과

| 프로젝트 | railties(lock) | minitest(lock) | Gemfile 핀 | minitest `*_test.rb` | `bin/rails test` | 실제 스위트 |
|---|---|---|---|---|---|---|
| docpack | **8.0.4** | 5.27.0 | `~> 5.25` 있음 | 3~4개 | 25 runs / 87 assertions / 0 fail | minitest |
| schoolkit | 8.0.5.1 | **6.0.6** | 없음 | 66개 | **314 runs / 2157 assertions / 0 fail** | minitest |
| teachermatch | 8.1.3.1 | 5.27.0 | `~> 5.25` 있음 | 242개 | 2965 runs / 10541 assertions / 0 fail / 8 skip (`PARALLEL_WORKERS=1`) | minitest |
| currencyrate | 8.0.5 | 6.0.2 | 없음 | **0개** (`test/` 없음) | 0 runs | RSpec 150 examples / 0 fail |
| naeilalbum | 8.0.5 | 6.0.3 | 없음 | **0개** (`test/` 는 `.keep` 골격만) | 0 runs | RSpec 45 examples / 0 fail |
| slotbook | 8.0.5 | 6.0.5 | 없음 | **0개** (`test/` 없음) | 0 runs | RSpec 80 examples / 0 fail |
| tripbudget | 8.0.5 | 6.0.6 | 없음 | **0개** (`test/` 없음) | 0 runs | RSpec 16 examples / 0 fail |
| hellokorean-rails | 8.0.5.1 | 6.0.6 | 없음 | **0개** (`test/` 없음) | 0 runs | RSpec 8103 examples 수집(dry-run) |
| _archive/…/teachermatch | 8.0.4 | 5.27.0 | `~> 5.25` 있음 | 27개 | 미실행(아카이브) | minitest |

lock 값이 아니라 **실제 로드되는 버전**도 확인했다:

```
$ cd schoolkit && bundle exec ruby -e 'require "minitest"; puts Minitest::VERSION; require "rails/version"; puts Rails::VERSION::STRING'
6.0.6
8.0.5.1

$ cd docpack && (같은 명령)
5.26.2      ← lock 은 5.27.0 인데 로드는 5.26.2. 핀 "~> 5.25" 범위 안이라 둘 다 5.x
8.0.4
```

### 3-7. canary — "0 runs" 가 죽은 것인지 빈 것인지 가른 방법 (전문)

`test/zz_minitest_canary_test.rb` 로 **임시 투입 후 삭제**했다.
`ActiveSupport::TestCase` 를 상속한 이유는 §3-3 대로 **railties 가 LineFiltering 을
붙이는 대상이 바로 그 클래스**이기 때문이다. 평범한 `Minitest::Test` 였다면
고장 경로를 아예 타지 않아 위양성(살아 있다고 잘못 판정)이 난다.

```ruby
require_relative "../config/environment"
require "active_support/test_case"
require "minitest/autorun"

class ZzMinitestCanaryTest < ActiveSupport::TestCase
  def test_runner_is_alive
    assert_equal 2, 1 + 1
  end
end
```

5개 프로젝트 전부 `1 runs, 1 assertions, 0 failures, 0 errors, 0 skips`.
확인 후 파일 삭제 + `find ~/Projects -name zz_minitest_canary_test.rb` → 0건으로 확인.

### 3-8. 음성 대조 ① — schoolkit 에서 8.0.4 동작을 강제 재현

railties 8.0.5.1 위에서 MT6 분기를 **막고** MT5 경로만 쓰게 하면 8.0.4 와 같아진다:

```ruby
bundle exec ruby -e '
require "rails/test_unit/line_filtering"
module Rails
  module LineFiltering
    def self.extended(obj); obj.extend(MT5); end
  end
end
ARGV.replace(["test", ENV.fetch("TF")])
load "bin/rails"
'
```

결과(단일 파일·단일 프로세스):

```
railties-8.0.5.1/lib/rails/test_unit/line_filtering.rb:19:in `run':
wrong number of arguments (given 3, expected 1..2) (ArgumentError)
	from minitest-6.0.6/lib/minitest.rb:473:in `block (2 levels) in run_suite'
```

같은 파일을 정상 경로로 돌리면 `1 runs, 4 assertions, 0 failures`.
전체 스위트(314개, 4프로세스 병렬)로도 똑같이 `ArgumentError` 로 죽고, **요약 줄이 안 나온다.**

### 3-9. 음성 대조 ② — docpack 에서 원증상을 실제 8.0.4 로 재현

실제 Gemfile 은 **건드리지 않았다.** 사본 `Gemfile.mt6probe` 에서만 핀을 `~> 6.0` 으로 풀고
`BUNDLE_GEMFILE` 로 가리켜 돌린 뒤, 프로브 파일 2개를 삭제했다.

```
$ BUNDLE_GEMFILE=Gemfile.mt6probe bin/rails test
railties-8.0.4/lib/rails/test_unit/line_filtering.rb:7:in `run':
wrong number of arguments (given 3, expected 1..2) (ArgumentError)
(… stderr 스택 트레이스 …)

# stdout 만 보면:
Running 46 tests in a single process (parallelization threshold is 50)
Run options: --seed 51654
# Running:
(여기서 끝. 요약 줄 없음)

$ echo $?
1            ← 고장(minitest 6)
$ bin/rails test >/dev/null 2>&1; echo $?
0            ← 정상(minitest 5)
```

---

## ④ 정본 대조표

| 규칙 / 주장 | 구현·근거 위치 | 지금 아는 상태 |
|---|---|---|
| 비호환 = `railties < 8.0.5 && minitest >= 6` | §3-1, §3-2, §3-4 | 소스로 확인 |
| docpack 만 railties < 8.0.5 | §3-5, §3-6 | lock 실측 |
| docpack 은 이미 `minitest "~> 5.25"` 핀 | `docpack/Gemfile:80` | 확인 |
| teachermatch 도 이미 핀 | `teachermatch/Gemfile:104` | 확인 (railties 8.1.3.1 이라 이중 안전) |
| "0 runs" 5개는 minitest 테스트 0개 | §3-6, §3-7 | canary 로 러너 생존 증명 |
| 조치 대상 0건 | 위 전부 | **이번 런의 최종 결론** |

---

## ⑤ 검증받고 싶은 주장 (C1~C8) + 우리가 확신 없는 지점

- **C1** 비호환 조건은 `railties < 8.0.5 && minitest >= 6` 이고, 둘 중 하나만으로는 안전하다.
- **C2** `~/Projects` 의 Rails 프로젝트는 활성 8 + 아카이브 1 이 전부다(탐색 방법 §3-5).
- **C3** "0 runs" 를 낸 5개 프로젝트는 **죽은 게 아니라** minitest 테스트가 0개다.
- **C4** canary 가 `ActiveSupport::TestCase` 를 상속했으므로 고장 경로를 실제로 탄다 → 위양성이 아니다.
- **C5** §3-8 의 강제 MT5 재현이 railties 8.0.4 동작과 **동등**하다.
- **C6** teachermatch 의 `pg 1.6.3` segfault(병렬 8프로세스)는 minitest 와 무관한 별건이다.
- **C7** 고장의 실제 신호는 `0 tests 통과`가 아니라 **`exit 1` + `요약 줄 부재`** 다
  (docpack CLAUDE.md 의 기존 기록을 이 내용으로 정정했다).
- **C8** 따라서 **어떤 프로젝트에도 `minitest "~> 5.25"` 를 새로 넣을 필요가 없다.**

**확신 없는 지점 — 여기를 특히 공격해 달라:**

1. **Gemfile.lock 과 실제 설치본의 괴리.** docpack 은 lock 이 `5.27.0` 인데 로드는 `5.26.2` 였다(§3-6).
   그렇다면 **다른 프로젝트도 lock 값으로 판정한 것이 틀렸을 수 있지 않나?**
   (schoolkit 은 로드 버전까지 확인했지만 나머지 6개는 lock 만 봤다.)
2. **드리프트 위험.** minitest 를 핀하지 않은 6개는 `bundle update` 한 번에 minitest 가 더 올라간다.
   railties 가 8.0.5 이상이면 정말 영원히 안전한가? **minitest 7 이 나오면** §3-2 의
   `case Minitest::VERSION when /^5/ … when /^6/` 은 **어느 분기에도 안 걸려 LineFiltering 이
   아예 안 붙는다.** 그러면 조용히 줄 필터링만 깨지나, 아니면 다른 고장이 나나?
3. **`rails "~> 8.0.4"`(currencyrate) 같은 제약.** 지금 lock 은 8.0.5 지만 `~> 8.0.4` 는
   8.0.4 로 되돌아갈 여지가 있는 표기인가? 되돌아가면 minitest 6.0.2 와 만나 즉사한다.
4. **canary 의 한계.** canary 는 `rails/test_help` 를 안 쓰고 DB 픽스처도 안 탄다.
   "러너는 살아 있다" 는 증명이 **실제 테스트가 돌 것** 이라는 증명까지 되는가?
5. **RSpec 프로젝트를 "테스트 있음" 으로 친 판단.** `bin/rails test` 만 보면 0 인 것이 맞는데,
   이걸 "문제 없음" 으로 결론낸 것이 조사 목적(죽은 스위트 찾기)에 비추어 타당한가?
6. **동시 편집.** 점검 중 같은 저장소에서 사용자의 다른 자율 세션 6개가 돌고 있었다.
   docpack 은 점검 도중 브랜치가 바뀌고 커밋이 2개 늘었다(테스트 개수가 25 → 46 으로 변한 이유).
   **이 조건에서 측정한 숫자를 신뢰할 수 있나?** 어떤 숫자가 오염됐을 수 있나?
