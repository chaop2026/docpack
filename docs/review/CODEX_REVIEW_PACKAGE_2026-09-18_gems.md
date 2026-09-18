# Codex 교차검증 패키지 — 젬 업그레이드 · 2026-09-18 (라운드 5)

> 대상 브랜치 `chore/gem-upgrades` (`main` 에서 분기, 커밋 `3285e8d`→`8b5…`, **미배포·미머지**)
> 비밀값 스캔 결과는 문서 말미.

## ① 리뷰어용 프롬프트

당신은 이 저장소를 처음 보는 **독립 코드 리뷰어**다. 아래 패키지만 근거로 판단하라.

**맥락**: Rails 앱 `slimfile.net` (Kamal 으로 단일 서버 배포, Puma 안에서 Solid Queue 를 함께
돌린다). 이번 브랜치는 **기능 변경이 아니라 의존성 업그레이드**다. 세 갈래다:

1. **`minitest "~> 5.25"` 핀을 원인 제거로 풀었다.** 핀은 2026-09-17 에 넣은 증상 억제였다.
   railties 8.0.4 가 `line_filtering.rb` 에서 2-arity `run` 을 **무조건** prepend 하는데
   minitest 6 은 3인자로 부른다 → 전 테스트가 단언 하나 못 돌고 죽는다. railties **8.0.5** 가
   `Minitest::VERSION` 분기를 들고 오면서 원인이 사라져, 핀 대신 **`rails` 하한을 `~> 8.0.5`**
   로 올렸다. minitest 는 `< 7` **상한만** 남겼다(이유는 Q2).
   부수로 Ruby 를 `.ruby-version`(3.3.9)과 맞췄다 — 두 Dockerfile 이 3.3.0 이었다.
2. **dependabot 12건을 분류해 7 젬 + Actions 2건을 올리고 3건을 보류했다.**
   보류: `image_processing 2.x` · `puma 8` · `kamal 2.12`.
3. **검증 스크립트 2개를 커밋했다** (`script/middleware_probe.sh`, `script/canonical_sweep.rb`).

**지적 분류 고정**: `정책 위반` / `보안` / `데이터 손실 위험` / `논리 오류` / `배포 위험`

**규칙**:
- 모든 지적에 **파일:줄 근거**를 달아라. 근거 없는 지적은 적지 마라.
- **확신도(높음/보통/낮음)** 표기. 낮아도 적되 낮다고 밝혀라.
- **여기 없는 파일은 추측하지 마라.** 필요하면 "경로 요청: <파일>" 이라고 적어라.
- 하지 말 것: 스타일 지적(rubocop-rails-omakase 고정, **신규 위반 0 확인됨**),
  일반론적 "테스트를 늘려라", 정본 문서(DECISIONS.md)를 고치자는 제안,
  "젬을 더 올려라"(분류 기준은 ②에 명시했다 — 기준 자체를 공격하는 건 환영).

**이 저장소가 반복해 당한 실패 유형** (이 관점으로 파고들어라):
1. **조용한 실패** — 실패했는데 성공처럼 보인다. 실사례: ① 라우트가 정적 핸들러에 가려 한 번도
   실행 안 됨 ② minitest 비호환으로 전 테스트가 죽었는데 요약 줄 없이 끊겨 통과처럼 보임
   ③ 컨트롤러발 `page_meta` 가 조용히 무시됨 ④ **이니셜라이저·`lib/` 가 dev 에서 리로드되지
   않아 "수정 후" 측정이 실은 수정 전 값** ⑤ 가드 때문에 미들웨어가 스택에서 0개인데 에러 없음
   ⑥ `ApplicationJob` 에 `retry_on` 을 달면 메일이 커버된다고 착각 ⑦ 프로브 마커를 대상이 쓰는
   값과 같게 잡아 거짓 통과.
2. **암묵적 상류 의존** — 안전의 근거가 우리 코드 밖에 있다.
3. **공허한 검사** — 아무것도 검증하지 않는 테스트/단언.
4. **하나를 고치며 다른 하나를 깨뜨림.**
5. **이번 라운드 고유**: *"로컬에서 무해했으니 프로덕션에서도 무해하다"* 로 미끄러지는 것.

**특히 답을 원하는 질문**:

- **Q1. `rails "~> 8.0.5"` 라는 제약이 의도를 정확히 표현하는가?**
  의도는 "railties 8.0.5 미만이 이 번들에 절대 해석되지 않게 한다". `~> 8.0.5` 는
  `>= 8.0.5, < 8.1` 이다. 8.1 을 막는 부작용은 알고 있고 받아들인다(전 `~> 8.0.4` 와 같은 천장).
  **하지만**: `rails` 메타젬만 제약하는데, `railties` 는 다른 젬이 끌어올 수 있는가?
  이 번들에서 `railties` 가 8.0.5 미만으로 내려갈 경로가 실제로 존재하는가?
  (lock DEPENDENCIES 전문과 `railties` 를 요구하는 모든 항목을 ⑤에 넣었다)
- **Q2. `minitest "< 7"` 상한이 옳은 도구인가?**
  근거: railties 8.0.5.1 의 `case Minitest::VERSION when /^5/ … when /^6/ … end` 에 `else` 가
  없다(소스 ②에 인용). 프로브로 확인했다 — VERSION="7.0.0" 이면 LineFiltering 이 **0개** 붙는다.
  그런데 **상한이 진짜 답인가?** 반론 후보: ⓐ 상한은 minitest 7 이 나오면 조용히 낡은 버전에
  고착시킨다(핀과 같은 병) ⓑ 차라리 **부팅/CI 시점에 분기 존재를 단언**하는 게 낫지 않은가
  ⓒ `Minitest::VERSION` 자체를 못 믿는다(5.27.0 이 `VERSION = "5.26.2"` 로 오기해 배포된 전례가
  있다 — 이 저장소가 직전 라운드에 기록함). 그 오기가 이 상한을 무력화할 수 있는가?
- **Q3. `gem "minitest-mock"` 추가가 옳은가, 아니면 테스트에서 `stub` 을 걷어내야 하는가?**
  `minitest-mock` 의 최신이자 유일한 버전이 **5.27.0** 이다(minitest 6 과 번호가 어긋난다).
  gemspec 에 minitest 런타임 의존이 **없다**(확인함). 유지보수가 끊긴 젬에 테스트를 묶는 위험이
  `Object#stub` 을 직접 구현하는 위험보다 큰가?
- **Q4. puma 8 보류 판단의 근거가 충분한가?**
  핵심 사실: 8.0.0 의 유일한 breaking change 가 기본 바인드 `0.0.0.0` → `::`(non-loopback IPv6
  인터페이스가 있을 때)이고, `config/puma.rb:31` 은 `port ENV.fetch("PORT", 3001)` 로 **호스트를
  명시하지 않는다**. 프로덕션 이미지 안에서 puma 8 의 판정식을 돌리면 `false` 가 나왔지만
  그건 로컬 docker 브리지다. **반대 방향도 답해달라**: 보류가 과한가? 즉 이 구성에서 puma 8 이
  실제로 바인드를 바꿀 경로가 있는가? (`deploy.yml` 의 `proxy.app_port: 3000` 과
  Dockerfile 의 `CMD ["./bin/thrust", "./bin/rails", "server"]` 조합을 보고 판단하라)
  그리고 내가 **배제한 것들이 정말 배제되는가**: solid_queue 의 puma 플러그인이 쓰는
  `after_booted`/`after_stopped`/`before_restart` 가 puma 8.0.2 에 존재(확인함),
  `before_thread_start` 미사용, `http_content_length_limit` 기본값 7·8 모두 `nil`.
- **Q5. image_processing 2.x 보류 근거 중 놓친 것이 있는가?**
  세 가지를 들었다(`ruby-vips` soft dependency 화 · unfuzzed 로더 기본 차단 · resize 후 샤프닝
  기본 해제). **2.0.1 의 "Prevent remote shell execution when passing loader/saver options from
  user input" 과 2.0.0 의 "Avoid remote shell execution vulnerability in `#apply`" 가 보안
  수정인데, 보류가 곧 "알려진 보안 수정을 미룬다" 는 뜻 아닌가?** 이 앱의 코드가 그 취약 경로에
  실제로 닿는지 판단해달라 — 관련 호출부 3개 파일을 ⑤에 넣었다.
- **Q6. `script/canonical_sweep.rb` 에 공허한 검사가 있는가?**
  미들웨어를 실제로 빼고 돌려 **64건 실패**(중복 200 이 20→84)를 확인했다. 그래도
  **개별 검사 중 아무것도 검증하지 않는 것**이 있는지 봐달라. 특히 `[5/6]` 의 JSON-LD 비교는
  `u.include?("/blog/")` 로 필터링하는데, **그 조건이 거짓이면 단언이 0개 실행된다** — 그 경우
  조용히 통과한다. 그리고 `[1/6]` 의 `allowed_200` 이 **너무 넓어** 진짜 중복을 덮지 않는가?
- **Q7. `script/middleware_probe.sh` 의 세 번째 구성이 실제로 그 상태를 만드는가?**
  임시 이니셜라이저 `config/initializers/aaa_static_probe.rb` 로
  `public_file_server.enabled = false` 를 세운다. 전제: ⓐ 이니셜라이저는 알파벳순으로 로드되고
  `aaa_…` 가 `canonical_path_redirect` 보다 앞선다 ⓑ 미들웨어 스택은 이니셜라이저 **이후**에
  만들어지므로 그때 세운 값이 반영된다. **이 전제가 맞는가?** 그리고 `trap EXIT` 로 지우는데,
  스크립트가 SIGKILL 되면 파일이 남아 **이후 모든 부팅에서 정적 서빙이 꺼진다**. 위험한가?
- **Q8. Actions v7 판단.** checkout v7 의 breaking change("fork PR 체크아웃 차단")가
  `pull_request_target`·`workflow_run` 한정이라는 전제로 안전하다고 봤다. 이 워크플로(⑤ 전문)가
  그 트리거를 쓰지 않는 것이 맞는가? 다른 breaking change 를 놓쳤는가?
- **Q9. 자신 없는 지점 (아래 ⑥) 중 (a)등급이 있는가?**

---

## ② 분류 기준 — 판정보다 **먼저** 정했다

**올린다**: 아래를 **전부** 충족할 때만
- (a) 릴리스 노트 또는 소스 diff 에 **이 앱이 실행하는 경로**로 오는 breaking change 가 없다.
  버전 번호가 아니라 **읽어서** 확인한다.
- (b) 이 앱의 사용처를 **grep 으로 확인**했다(추정 금지).
- (c) 로컬 검증 배터리가 전부 통과한다.
- (d) 잘못된 판단이 **로컬에서 드러난다**. 프로덕션에서만 드러나면 (d) 불충족.

**보류한다**: 아래 중 **하나라도** 해당하면
- (x) 문서화된 breaking change 가 실행 경로에 닿는다.
- (y) 확인하려면 **배포해야 한다** (에이전트 권한 밖 — 배포는 사람이 한다).
- (z) 배포 경로 위에 있는데 **이 앱에 필요한 것이 없다** (이득 없는 위험).

---

## ③ 근거 — 젬 소스·changelog 에서 직접 인용한 사실

### ③-1 railties 8.0.5.1 의 분기에 `else` 가 없다

```ruby
# /usr/local/bundle/gems/railties-8.0.5.1/lib/rails/test_unit/line_filtering.rb
module Rails
  module LineFiltering # :nodoc:
    def self.extended(obj)
      require "minitest"

      case Minitest::VERSION
      when /^5/ then
        obj.extend MT5
      when /^6/ then
        obj.extend MT6
      end                       # ← else 없음
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

**읽고 판정하지 않고 프로브를 돌렸다** (컨테이너 안, `bundle exec`):

```ruby
require "minitest"; require "rails/test_unit/line_filtering"
def probe(v)
  Minitest.send(:remove_const, :VERSION); Minitest.const_set(:VERSION, v)
  k = Class.new(Minitest::Runnable); k.extend Rails::LineFiltering
  puts k.singleton_class.ancestors.map(&:to_s).grep(/LineFiltering::MT/).inspect
end
```

```
Minitest::VERSION=6.0.6    -> ["Rails::LineFiltering::MT6"]
Minitest::VERSION=7.0.0    -> []            ← 줄 필터링이 조용히 무력화
Minitest::VERSION=5.27.0   -> ["Rails::LineFiltering::MT5"]
```

그리고 **줄 필터링이 실제로 동작하는지**도 쟀다(minitest 6.0.6 에서):

```
bin/rails test test/models/post_test.rb:13   ->  1 runs,  3 assertions
bin/rails test test/models/post_test.rb      -> 19 runs, 71 assertions
```

### ③-2 minitest 6.0.0 이 `minitest/mock` 을 떼어냈다

```
# minitest-6.0.6/History.rdoc, "=== 6.0.0 / 2025-12-17", "8 deaths in the family(!!)"
* Dropped minitest/mock.rb. This has been extracted to the minitest-mock gem.
* assert_equal(nil, value) no longer allowed. Use assert_nil to be explicit.
* Removed assert_send. Use assert_predicate or assert_operator.
* Deleted all minitest/spec expectations from Object. Use _/value/expect.
...
* Renamed +options[:filter]+ to +options[:include]+
* Assertions reuse themselves a lot more. Bumps assertion count in some places.
```

이 저장소의 해당 사용처 (grep, 전수):

```
test/integration/stuck_posts_visibility_test.rb:4:require "minitest/mock"
test/jobs/publish_scheduled_posts_job_test.rb:4:require "minitest/mock"
```

`assert_send` · `assert_equal nil` · `Minitest::Mock` 직접 사용은 **0건**(같은 grep).
`minitest-mock` gemspec 의 런타임 의존은 **없다**(`hoe`·`rdoc`·`hoe-git2` 는 development).

**단언 수가 1179 → 1218 로 늘어난 것은 위 마지막 줄 때문**이다. 런 수는 159 로 동일하고
코드는 바뀌지 않았다.

### ③-3 image_processing 2.0.x changelog 원문

```
## 2.0.2 (2026-06-03)
* Raise `LoadError` instead of `ImageProcessing::Error` when soft dependencies are missing
## 2.0.1 (2026-05-22)
* [minimagick] Prevent remote shell execution when passing loader/saver options from user input
## 2.0.0 (2026-05-20)
* `mini_magick`/`ruby-vips` are now soft dependencies and need to be manually added to the Gemfile
* Avoid remote shell execution vulnerability in `#apply` when arguments are coming from user input
* [vips] Unfuzzed loaders are now blocked by default
* [vips] Sharpening after resize has been disabled by default
* [minimagick] Remove deprecated `:compose` and `:geometry` keyword arguments for `#composite`
* Ruby 3.0+ is now required
```

현재 `ruby-vips` 는 **image_processing 이 끌고 오는 전이 의존**이다:

```
# Gemfile.lock (현재)
    image_processing (1.14.0)
      mini_magick (>= 4.9.5, < 6)
      ruby-vips (>= 2.0.17, < 3)
    ruby-vips (2.3.0)
```

### ③-4 puma 8.0.0 의 "Breaking changes" 는 **한 줄**이다

```
## 8.0.0 / 2026-03-27
* Breaking changes
  * Default production bind address changed from `0.0.0.0` to `::` (IPv6) when a
    non-loopback IPv6 interface is available; falls back to `0.0.0.0` if IPv6 is
    unavailable ([#3847])
```

업그레이드 가이드(`puma-8.0.2/docs/8.0-Upgrade.md`) 해당 항목:

> Puma will now listen on `::` (IPv6) by default. … You can overwrite this default behavior by
> setting `bind 'tcp://0.0.0.0:9292'`, `port ENV.fetch('PORT', 9292), '0.0.0.0'`, or
> `set_default_host '0.0.0.0'` explicitly to remain IPv4 only. Review any firewall rules, health
> checks, deploy scripts, or host-string parsing code that assumed `0.0.0.0` …

구현 (`puma-8.0.2/lib/puma/configuration.rb`):

```ruby
370:      ipv6_interface_available? ? Const::UNSPECIFIED_IPV6 : Const::UNSPECIFIED_IPV4
377:    def self.ipv6_interface_available?
380:        addr&.ipv6? && !addr&.ipv6_loopback?
```

**프로덕션 이미지 안에서** 같은 식을 돌린 결과:

```
127.0.0.1   v6=false loopback=true
172.17.0.4  v6=false loopback=false
::1         v6=true  loopback=true
ipv6_interface_available? => false
```

⚠️ 이건 로컬 docker 기본 브리지다. **Kamal 이 만드는 프로덕션 네트워크가 아니다.**

배제 확인한 항목들:
- solid_queue 의 puma 플러그인은 `Gem::Version.new(Puma::Const::VERSION) < Gem::Version.new("7")`
  로 분기하고 puma 8 은 `else` 경로(`after_booted`/`after_stopped`/`before_restart`)를 탄다.
  **그 셋이 puma 8.0.2 `lib/puma/events.rb:33,37,41` 에 그대로 있다**(7.2.0 과 같은 줄 번호).
- `before_thread_start` 는 이 저장소 `config/` 전체에 **0건**.
- `http_content_length_limit` 기본값은 puma 7.2.0 `configuration.rb:176` 과
  puma 8.0.2 `configuration.rb:146` **양쪽 다 `nil`**.
- `fork_worker` 미사용 → phased restart 순서 변경 무관.

### ③-5 solid_cable 4.0.x — **전체 소스 diff** (요약이 아니라 diff)

`diff -rq 3.0.12 4.0.2` 결과 바뀐 파일은 넷뿐이다: `README.md`, `Rakefile`,
`lib/action_cable/subscription_adapter/solid_cable.rb`, `lib/solid_cable.rb`, `version.rb`.
**삭제된 파일은 `lib/solid_cable/railtie.rb` 하나**이고 그 내용 전부는 이것이다:

```ruby
module SolidCable
  class Railtie < ::Rails::Railtie
  end
end
```

3.0.12 의 `lib/solid_cable.rb` 도 그 파일을 require 하지 않았다(grep "railtie" → 양쪽 lib/ 에서 0건).
나머지는 `Listener` 재연결 백오프 추가 + Rails 8.1 executor 실드(`respond_to?(:executor, true)`).
README diff 는 `reconnect_attempts` 옵션 한 줄 추가뿐.

gemspec (파싱해서 type 까지 확인):

```
ruby: >= 3.3.0
runtime    activerecord   >= 7.2
runtime    activejob      >= 7.2
runtime    actioncable    >= 7.2
runtime    railties       >= 7.2
development minitest      ~> 5.0      ← development. 이 번들에 오지 않는다(일부러 확인)
```

이 앱에는 `app/channels` 디렉터리가 **없다**. `config/cable.yml` 은 production 에서만
`adapter: solid_cable` 이다(dev=async, test=test).

### ③-6 rubyzip 은 **메이저가 아니다** (3.2.2 → 3.6.0 = minor)

```
# 3.4.0 (2026-06-14)
- Prevent entries from being extracted outside specified directory.   ← 추출 경로
- Use `SecureRandom` in place of insecure `Random`.
- Stop reading the central directory on first error.
- Add lib/rubyzip.rb for Bundler auto-require.
# 3.6.0 (2026-09-01)
- Forward options from OutputStream.open without a block.             ← 블록 없는 호출만
- Clamp DOS date and time to the range the fields can hold.
```

이 앱의 유일한 사용처 (grep `Zip::` 전수):

```
app/controllers/conversions_controller.rb:173:    Zip::OutputStream.open(zip_tempfile.path) do |zos|
```

**블록을 넘겨 쓰기만 한다.** 3.6.0 의 변경은 "블록 **없이** 호출할 때"에 관한 것이다.

### ③-7 GitHub Actions — 올린 동기가 실측으로 있다

main 의 최신 CI 런(`35295783921`) 주석:

```
! Node.js 20 is deprecated. The following actions target Node.js 20 but are being
  forced to run on Node.js 24: actions/checkout@v4.
```

`actions/checkout` CHANGELOG (v5.0.0 → v7.0.1):

```
v7.0.0  - Block checking out fork PR for pull_request_target and workflow_run
v6.0.0  - Persist creds to a separate file / README: Node.js 24 support details
v5.0.0  - Update actions checkout to use node 24
```

`upload-artifact`: v5 = Node 24 지원, v6 = `runs.using: node24` + **러너 >= 2.327.1**,
v7 = ESM + `archive:` 입력 추가(기본값 불변).

---

## ④ 검증 — 전부 Ruby 3.3.9 / Rails 8.0.5.1 / minitest 6.0.6 에서 재측정

⚠️ **모든 측정은 `docker compose restart web` 이후에 했다.** 이니셜라이저와 `lib/` 는 dev 에서
리로드되지 않아, 재시작 전 값은 전부 "수정 전" 이다(이 저장소가 두 세션 연속 당한 함정).

| 검증 | 결과 |
|---|---|
| `bin/rails test` | **159 runs / 1218 assertions / 0 failures / 0 errors / 0 skips** (전: 159/1179) |
| `bin/rails test:system` | 0 runs, **exit 0** (`test/system` 디렉터리 없음. CI 가 함께 돌린다) |
| 줄 필터링 (MT6 경로) | `post_test.rb:13` → **1 run** vs 파일 전체 **19 runs** |
| 프로덕션 미들웨어 스택 3형태 | ③-8 표 |
| 스택 27줄 전체 diff (8.0.4 vs 8.0.5.1) | **완전 동일** (옛 Gemfile 을 `BUNDLE_GEMFILE` 로 물려 재측정) |
| **실제 프로덕션 이미지** | `docker build` 성공 → 부팅 → `CanonicalPathRedirect` 가 Static 앞 |
| `script/canonical_sweep.rb` | 88 철자 / **중복 200 = 0** / 홉 `{1=>66, 2=>2}` / 6개 검사 통과 |
| **그 스윕이 공허하지 않은가** | 미들웨어를 실제로 빼면 **64건 실패**, 중복 200 이 20→84 |
| SW 네트워크 실패 주입 | **9/9** |
| rubocop | 86건 — **main 트리에 같은 rubocop 1.86.0 을 돌린 값과 동일**(신규 0) |
| brakeman | 경고 6 / **exit 3** — main 과 나란히 돌려 **동일** |
| `bin/importmap audit` | no vulnerable packages |
| 이미지 파이프라인 | `ImageProcessing::Vips` resize+convert 정상 (1.14.0 유지) |
| ZIP 쓰기 경로 | rubyzip 3.6.0 으로 2엔트리 아카이브 쓰기·재읽기 정상 |
| `rake blog:stuck` / `jobs:failed` | 정상 (막힌 글 0) |
| 프로덕션 DB | **미접촉** |

### ③-8 미들웨어 위치 (Rails 업그레이드 전/후)

| 구성 | 8.0.4 (전) | 8.0.5.1 (후) |
|---|---|---|
| `RAILS_SERVE_STATIC_FILES=true` (실제 배포 형태) | Static 바로 앞 | **동일** |
| 변수 미설정 | Static 바로 앞 | **동일** |
| `public_file_server.enabled = false` | 스택 최상단 | **동일** |

### ④-1 CI 베이스라인 정정 — **손대기 전부터 빨간색이었다**

| 잡 | main 상태 | 이 브랜치 |
|---|---|---|
| `test` | ✅ | 변화 없음 |
| `scan_js` | ✅ | 변화 없음 |
| `lint` | ❌ rubocop 86건(전부 기존) | **같은 86건** |
| `scan_ruby` | ❌ brakeman exit 3 / 경고 6 | **같은 6건 / exit 3** |

기존 86·6 을 어떻게 할지는 이 작업 범위가 아니다(사람 결정). 이 표를 넣는 이유는
**push 후 CI 가 빨갛다고 이 브랜치 탓으로 오해하지 않게** 하기 위해서다.

---

## ⑤ 확신 없는 지점 — 여기를 파라

1. **`rails "~> 8.0.5"` 로 `railties` 하한을 간접 강제하는 것.** 메타젬만 제약하면 충분한가?
   (Q1)
2. **`minitest "< 7"` 이 핀과 같은 병에 걸리는가.** "다음에 railties 가 `else` 를 달면 풀어라"
   를 코드 주석에만 적었다 — 아무도 안 읽으면 상한이 영원히 남는다. 부팅/CI 단언이 더 나은가? (Q2)
3. **`minitest-mock` 5.27.0 에 테스트를 묶는 것.** 버전 번호가 minitest 6 과 어긋나고, 이 젬이
   방치되면 `Object#stub` 이 조용히 깨질 수 있다. (Q3)
4. **puma 8 보류가 과한가 / 부족한가.** 로컬 판정식은 `false` 였다. 그걸 근거로 올렸다면
   실패 유형 5번("로컬에서 무해했으니")에 정확히 걸린다고 봤는데, 반대로 **과한 보류**일 수도
   있다. (Q4)
5. **image_processing 보류가 보안 수정을 미루는 것 아닌가.** (Q5)
6. **`script/canonical_sweep.rb` 의 `[5/6]` JSON-LD 검사가 조건부라 0건 실행될 수 있다.** (Q6)
7. **`script/middleware_probe.sh` 의 임시 이니셜라이저가 남을 수 있다.** (Q7)
8. **`public/privacy/index.html` 의 절대 링크 수정**(`/blog/` → `/blog`)이 젬 업그레이드와 같은
   브랜치에 섞였다. 분리했어야 하는가?
9. **Ruby 3.3.0 → 3.3.9 를 이 브랜치에 섞은 것.** 인터프리터 변경은 별도 배포가 맞지 않은가?
   (같은 3.3 계열이고 CI 는 이미 3.3.9 를 쓰고 있었다는 점을 감안해 판단해달라)

---

## ⑥ 비밀값 스캔

패키지에 포함한 파일 전문에서 확인한 것:
- `config/deploy.yml` 은 **넣지 않았다**(서버 IP·레지스트리 계정 포함). 대신 판단에 필요한
  두 줄만 인용: `proxy.app_port: 3000`, `env.clear.SOLID_QUEUE_IN_PUMA: true`,
  `env.clear.RAILS_SERVE_STATIC_FILES: true`, `env.clear.WEB_CONCURRENCY: 2`.
- `.kamal/secrets`·`.env*`·`config/master.key` **미포함**.
- `Gemfile`·`Gemfile.lock`·`Dockerfile`·`Dockerfile.dev`·`config/puma.rb`·
  `.github/workflows/ci.yml`·`script/*`·`config/initializers/canonical_path_redirect.rb` —
  **비밀값 0건**.

---

## ⑦ 핵심 파일 전문

#### `Gemfile`

```ruby
source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
#
# Floor raised to 8.0.5 on 2026-09-18. railties 8.0.5 is the first release whose
# rails/test_unit/line_filtering.rb branches on Minitest::VERSION and ships a
# 3-arity `run` for minitest 6; 8.0.4 and earlier only prepend a 2-arity `run`,
# so resolving minitest 6 alongside them kills the whole test suite before a
# single assertion runs. This is a floor, not a pin — the cause is gone, so the
# minitest pin that used to suppress the symptom is gone too (see :test group).
gem "rails", "~> 8.0.5"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

# PDF generation
gem "combine_pdf"

# ZIP file creation
gem "rubyzip", require: "zip"

# Environment variables
gem "dotenv-rails", groups: [:development, :test]


group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"

  # The 5.x pin is gone (2026-09-18): railties >= 8.0.5 handles minitest 6, and
  # the Gemfile now floors rails there, so the incompatibility that pin existed
  # to suppress cannot be resolved into this bundle any more.
  #
  # The `< 7` ceiling is a DIFFERENT constraint and stays. railties 8.0.5.1's
  # rails/test_unit/line_filtering.rb dispatches on Minitest::VERSION with
  # `case … when /^5/ … when /^6/ … end` and NO `else` branch, so minitest 7
  # would get no LineFiltering at all. That does not raise — it makes
  # `bin/rails test path/to/file.rb:42` silently run the whole file instead of
  # the one line. A quiet wrong answer is worse than a loud crash, so the
  # ceiling holds until a railties release grows an `else` (or a /^7/ branch).
  gem "minitest", "< 7"

  # minitest 6.0.0 dropped lib/minitest/mock.rb ("Dropped minitest/mock.rb. This
  # has been extracted to the minitest-mock gem." — minitest History.rdoc,
  # 6.0.0 / 2025-12-17). Two test files require it for Object#stub, which
  # rails/test_help does not load. The extracted gem has no runtime dependency
  # on minitest at all, so this is purely "the file moved into its own gem".
  gem "minitest-mock"
end
```

#### `Dockerfile`

```dockerfile
# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t docpack .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name docpack docpack

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
#
# It did not (found 2026-09-18): .ruby-version said 3.3.9 and this said 3.3.0,
# so CI — which reads .ruby-version via ruby/setup-ruby — tested on a different
# interpreter than production ran. Every green CI run was evidence about 3.3.9
# and none about 3.3.0. Same 3.3 series, so this is a patch-level alignment.
ARG RUBY_VERSION=3.3.9
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy application code
COPY . .

# Stamp the service-worker cache version with the build time so EVERY image
# (i.e. every deploy) bumps CACHE_VERSION. This forces returning clients to
# install the new SW and lets activate() purge stale caches — the manual-bump
# step that was missed and left an old app shell pinned. No-op if the
# placeholder is absent, so it can never fail the build.
RUN sed -i "s/__SW_BUILD__/$(date -u +%Y%m%d%H%M%S)/g" public/safe/sw.js

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile




# Final stage for app image
FROM base

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
```

#### `Dockerfile.dev`

```dockerfile
# Kept in step with .ruby-version and Dockerfile (production). Development
# drifting to a different interpreter than production is how a 3.3.9-only or
# 3.3.0-only bug gets to be someone else's problem.
FROM ruby:3.3.9-slim

WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential git libpq-dev libyaml-dev pkg-config \
    curl libvips postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
```

#### `config/puma.rb`

```ruby
# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.
#
# Puma starts a configurable number of processes (workers) and each process
# serves each request in a thread from an internal thread pool.
#
# You can control the number of workers using ENV["WEB_CONCURRENCY"]. You
# should only set this value when you want to run 2 or more workers. The
# default is already 1.
#
# The ideal number of threads per worker depends both on how much time the
# application spends waiting for IO operations and on how much you wish to
# prioritize throughput over latency.
#
# As a rule of thumb, increasing the number of threads will increase how much
# traffic a given process can handle (throughput), but due to CRuby's
# Global VM Lock (GVL) it has diminishing returns and will degrade the
# response time (latency) of the application.
#
# The default is set to 3 threads as it's deemed a decent compromise between
# throughput and latency for the average Rails application.
#
# Any libraries that use a connection pool or another resource pool should
# be configured to provide at least as many connections as the number of
# threads. This includes Active Record's `pool` parameter in `database.yml`.
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT", 3001)

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Run the Solid Queue supervisor inside of Puma for single-server deployments
plugin :solid_queue if ENV.fetch("SOLID_QUEUE_IN_PUMA", "false") == "true"

# Specify the PID file. Defaults to tmp/pids/server.pid in development.
# In other environments, only set the PID file if requested.
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
```

#### `.github/workflows/ci.yml`

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [ main ]

jobs:
  scan_ruby:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v7

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: .ruby-version
          bundler-cache: true

      - name: Scan for common Rails security vulnerabilities using static analysis
        run: bin/brakeman --no-pager

  scan_js:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v7

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: .ruby-version
          bundler-cache: true

      - name: Scan for security vulnerabilities in JavaScript dependencies
        run: bin/importmap audit

  lint:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v7

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: .ruby-version
          bundler-cache: true

      - name: Lint code for consistent style
        run: bin/rubocop -f github

  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
        ports:
          - 5432:5432
        options: --health-cmd="pg_isready" --health-interval=10s --health-timeout=5s --health-retries=3

      # redis:
      #   image: redis
      #   ports:
      #     - 6379:6379
      #   options: --health-cmd "redis-cli ping" --health-interval 10s --health-timeout 5s --health-retries 5

    steps:
      - name: Install packages
        run: sudo apt-get update && sudo apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config google-chrome-stable

      - name: Checkout code
        uses: actions/checkout@v7

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: .ruby-version
          bundler-cache: true

      - name: Run tests
        env:
          RAILS_ENV: test
          DATABASE_URL: postgres://postgres:postgres@localhost:5432
          # REDIS_URL: redis://localhost:6379/0
        run: bin/rails db:test:prepare test test:system

      - name: Keep screenshots from failed system tests
        uses: actions/upload-artifact@v7
        if: failure()
        with:
          name: screenshots
          path: ${{ github.workspace }}/tmp/screenshots
          if-no-files-found: ignore
```

#### `config/cable.yml`

```yaml
# Async adapter only works within the same process, so for manually triggering cable updates from a console,
# and seeing results in the browser, you must do so from the web console (running inside the dev process),
# not a terminal started via bin/rails console! Add "console" to any action or any ERB template view
# to make the web console appear.
development:
  adapter: async

test:
  adapter: test

production:
  adapter: solid_cable
  connects_to:
    database:
      writing: cable
  polling_interval: 0.1.seconds
  message_retention: 1.day
```

#### `config/initializers/canonical_path_redirect.rb`

```ruby
# frozen_string_literal: true

# Insert CanonicalPathRedirect so every page has one address: `/safe` and
# `/safe/index.html` collapse onto `/safe/`, every routed page's trailing-slash
# twin collapses onto the bare path, and repeated slashes collapse anywhere they
# appear. See lib/canonical_path_redirect.rb for the full rationale.
#
# ── Why this is inserted unconditionally ────────────────────────────────────
#
# It used to be wrapped in `if config.public_file_server.enabled`, copied from
# the sibling initializer below. That was right when this middleware only fixed
# static directories: with no ActionDispatch::Static there was nothing to get in
# front of. It stopped being right on 2026-09-18, when the middleware took over
# trailing-slash normalisation for *routed* pages (`/about/`, `/blog/:slug/`,
# `/sitemap.xml/`) — those have nothing to do with static file serving.
#
# Measured, not assumed: with the guard in place and `public_file_server.enabled`
# false, `bin/rails middleware` listed CanonicalPathRedirect zero times. Moving
# public/ behind nginx would therefore have deleted canonical-URL normalisation
# for the whole site with no error and no log line — the exact silent-failure
# shape this repo keeps getting bitten by.
#
# So the middleware always goes in. Only its POSITION depends on Static:
#
#   * Static present  — insert directly in front of it. Required: the file
#     handler answers `/safe` from public/safe/index.html before the router ever
#     sees the request, which is why the equivalent route in config/routes.rb
#     was dead code for as long as it existed.
#   * Static absent   — unshift to the top of the stack. There is nothing to
#     insert before, and `insert_before` would raise at boot ("No such
#     middleware to insert before"), turning a deployment change into a crash.
#     This does put it ahead of ActionDispatch::SSL, so a plain-HTTP request
#     would be normalised before being upgraded rather than after. Same two
#     hops either way (scheme, then spelling, in the other order), and what
#     makes that safe is that every Location this middleware emits is
#     path-only — it never reads or echoes the Host header, so SSL still gets
#     its turn and there is nothing to inject a host into. Asserted in the
#     tests rather than argued.
#
#     Measured while checking that ordering: ActionDispatch::HostAuthorization
#     is not in this app's production stack at all (config.hosts is commented
#     out in config/environments/production.rb), so unshifting past it is not
#     a production concern. In development it would come first, but development
#     always serves public/ itself, so that branch is never taken there.
#
# Order vs StaticHtmlNoCache: both target the front of the stack, and
# initializers load alphabetically (canonical_path_redirect →
# static_html_no_cache), so this one ends up the *outer* of the two. Harmless
# either way: the rewriter only touches responses carrying `public, max-age=…`,
# and this 301 sends `no-cache`.
#
# The guard on static_html_no_cache.rb is NOT the same mistake and stays put —
# that middleware exists purely to rewrite the cache headers Static emits, so
# without Static it genuinely has no work to do.
require Rails.root.join("lib", "canonical_path_redirect").to_s

if Rails.application.config.public_file_server.enabled
  Rails.application.config.middleware.insert_before(
    ActionDispatch::Static, CanonicalPathRedirect
  )
else
  Rails.application.config.middleware.unshift(CanonicalPathRedirect)
end
```

#### `script/middleware_probe.sh`

```bash
#!/usr/bin/env bash
# Prints the production middleware stack under three static-file-serving configs,
# to check that CanonicalPathRedirect is present AND in front of ActionDispatch::Static.
#
# Run inside the web container:
#   docker compose exec -T web bash script/middleware_probe.sh
#
# The third config (public_file_server.enabled = false) is produced by a
# temporary initializer named to sort BEFORE canonical_path_redirect.rb, because
# that initializer reads the flag at load time. The file is removed on exit.
set -u

BASE_ENV="RAILS_ENV=production SECRET_KEY_BASE=dummy DB_HOST=db DB_USERNAME=postgres DB_PASSWORD=postgres"
PROBE=config/initializers/aaa_static_probe.rb
cleanup() { rm -f "$PROBE"; }
trap cleanup EXIT

stack() {
  env $BASE_ENV ${2:-} bin/rails middleware 2>/dev/null \
    | grep -nE "CanonicalPathRedirect|ActionDispatch::Static|ActionDispatch::SSL|StaticHtmlNoCache|^run "
}

echo "=== 1. RAILS_SERVE_STATIC_FILES=true (real deploy shape) ==="
stack x RAILS_SERVE_STATIC_FILES=true
echo
echo "=== 2. unset (framework default) ==="
stack x ""
echo
echo "=== 3. public_file_server.enabled = false (public/ behind a proxy) ==="
printf 'Rails.application.config.public_file_server.enabled = false\n' > "$PROBE"
stack x ""
```

#### `script/canonical_sweep.rb`

```ruby
# frozen_string_literal: true

# Canonical-URL regression sweep against a running app.
#
#   ruby script/canonical_sweep.rb [base_url]      # default http://localhost:3001
#
# Every round of SEO work in this repo re-measures the same six things, and until
# now the scripts that did it were ad hoc and thrown away. They are here so the
# next gem bump (or the next router change) can re-run them instead of
# rebuilding them from the CLAUDE.md prose.
#
# Checks, in order:
#   1. Duplicate 200s      — trailing and repeated slashes must not serve content
#   2. Redirect hops       — every 301 chain resolves in <= 2 hops, no loops
#   3. Sitemap             — every <loc> is 200, self-referencing canonical, no noindex
#   4. Internal links      — every href on every sitemap page resolves without a redirect
#   5. Signal consistency  — canonical == JSON-LD url == JSON-LD @id; hreflang sane
#   6. Accept-Language     — canonical and robots are identical for every language
#
# Exits non-zero if any check fails, so it can be dropped into CI unchanged.

require "net/http"
require "uri"
require "set"

BASE = ARGV[0] || "http://localhost:3001"
BASE_URI = URI.parse(BASE)

$failures = []
def fail!(check, detail)
  $failures << "#{check}: #{detail}"
  puts "  FAIL  #{detail}"
end

# URI.join is wrong here: it reads a leading "//" as protocol-relative, so
# "//about" — one of the exact spellings under test — resolves to host "about".
# Paths get concatenated onto the base instead.
def absolutize(path)
  return URI.parse(path) if path.start_with?("http://", "https://")

  URI.parse("#{BASE.chomp('/')}#{path}")
end

# `follow: false` is the point of most of these checks — we need to see the 301
# itself, not the page it lands on.
def get(path, follow: false, headers: {})
  uri = absolutize(path)
  req = Net::HTTP::Get.new(uri)
  headers.each { |k, v| req[k] = v }
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |h| h.request(req) }
  return res unless follow && res.is_a?(Net::HTTPRedirection)

  get(res["location"], follow: true, headers: headers)
end

def hops(path, limit: 6)
  seen = [ path ]
  n = 0
  cur = path
  loop do
    res = get(cur)
    return [ n, res.code, seen ] unless res.is_a?(Net::HTTPRedirection)

    n += 1
    cur = absolutize(res["location"]).request_uri
    return [ :loop, res.code, seen ] if seen.include?(cur)

    seen << cur
    return [ :overflow, res.code, seen ] if n > limit
  end
end

def meta(body, name)
  body[/<meta\s+name=["']#{name}["']\s+content=["']([^"']*)["']/i, 1] ||
    body[/<meta\s+content=["']([^"']*)["']\s+name=["']#{name}["']/i, 1]
end

def canonical(body) = body[/<link\s+rel=["']canonical["']\s+href=["']([^"']*)["']/i, 1]
def hreflangs(body) = body.scan(/<link\s+rel=["']alternate["']\s+hreflang=["']([^"']*)["']\s+href=["']([^"']*)["']/i)
def jsonld_blocks(body) = body.scan(%r{<script type="application/ld\+json">(.*?)</script>}m).flatten

# ── paths under test ────────────────────────────────────────────────────────
SLUGS = begin
  sm = get("/sitemap.xml", follow: true).body
  sm.scan(%r{<loc>([^<]+)</loc>}).flatten.map { |u| URI.parse(u).path }
end

STATIC_DIRS = %w[/safe /privacy]
ROUTED = %w[/ /about /faq /compress /pdf /social /blog /sitemap.xml /robots.txt
            /en/about /en/faq /en/blog /ja/blog /es/blog]

puts "base: #{BASE}"
puts "sitemap entries: #{SLUGS.size}"

# ── 1 + 2. spelling variants: no duplicate 200s, <= 2 hops, no loops ────────
puts "\n[1/6] spelling variants — duplicate 200s and hop counts"
variants = []
STATIC_DIRS.each do |d|
  variants += [ "#{d}/", d, "#{d}//", "#{d}///", "#{d}/index.html", "#{d}//index.html", "#{d}/index.html/" ]
end
variants += %w[/safe/sw.js /safe/sw.js/ /safe//sw.js]
ROUTED.each do |p|
  variants << p
  next if p == "/"

  variants += [ "#{p}/", "#{p}//", "/#{p}", p.sub(%r{\A/(\w+)/}, '/\1//') ].uniq
end
SLUGS.select { |s| s.start_with?("/blog/") }.each do |s|
  variants += [ s, "#{s}/", s.sub("/blog/", "/blog//") ]
end
# Renamed slugs: the middleware fixes the SPELLING and the router resolves the
# MOVE, so these are the repo's one accepted 2-hop case (DECISIONS.md 2026-09-18).
variants += %w[/blog/rrn-masking /blog/rrn-masking/ /blog/contract-checklist /blog/contract-checklist/]
variants = variants.uniq

dupes = []
hop_hist = Hash.new(0)
variants.each do |v|
  res = get(v)
  if res.is_a?(Net::HTTPRedirection)
    n, code, chain = hops(v)
    if n == :loop
      fail!("hops", "redirect loop starting at #{v}: #{chain.inspect}")
    elsif n == :overflow
      fail!("hops", "redirect chain over 6 hops at #{v}")
    else
      hop_hist[n] += 1
      fail!("hops", "#{v} takes #{n} hops (#{chain.inspect})") if n > 2
      # A 301 must land somewhere real.
      fail!("hops", "#{v} -> #{chain.last} ends in #{code}") unless code.start_with?("2")
    end
  elsif res.code == "200"
    dupes << v
  end
end
# The canonical spellings themselves are legitimately 200.
allowed_200 = (STATIC_DIRS.map { |d| "#{d}/" } + ROUTED + SLUGS + %w[/safe/sw.js]).uniq
(dupes - allowed_200).each { |v| fail!("duplicate-200", "#{v} serves content at a non-canonical spelling") }
puts "  variants probed: #{variants.size} | 200s: #{dupes.size} (allowed #{(dupes & allowed_200).size})" \
     " | hop histogram: #{hop_hist.sort.to_h.inspect}"

# ── 3. sitemap ───────────────────────────────────────────────────────────────
puts "\n[3/6] sitemap — 200, self-referencing canonical, no noindex, no redirect"
SLUGS.each do |path|
  res = get(path)
  next fail!("sitemap", "#{path} -> #{res.code} (sitemap must list final URLs only)") unless res.code == "200"

  body = res.body
  c = canonical(body)
  fail!("sitemap", "#{path} canonical is #{c.inspect}") unless c && URI.parse(c).path == path
  r = meta(body, "robots")
  fail!("sitemap", "#{path} carries robots=#{r.inspect}") if r&.include?("noindex")
end
puts "  #{SLUGS.size} entries checked"

# ── 4. internal links ────────────────────────────────────────────────────────
puts "\n[4/6] internal links — resolve without redirect"
links = Set.new
SLUGS.each do |path|
  body = get(path).body
  body.scan(/<a\s[^>]*href=["']([^"'#]+)["']/i).flatten.each do |href|
    next if href.start_with?("mailto:", "tel:", "javascript:")
    next if href.start_with?("http") && !href.start_with?(BASE) && !href.include?("slimfile.net")

    links << URI.parse(href).path if href.start_with?("/") || href.include?("slimfile.net")
  end
end
links.each do |l|
  res = get(l)
  fail!("internal-link", "#{l} -> #{res.code} #{res['location']}") unless res.code == "200"
end
puts "  #{links.size} distinct internal link targets checked"

# ── 5. canonical vs JSON-LD ──────────────────────────────────────────────────
puts "\n[5/6] canonical vs JSON-LD url/@id, hreflang sanity"
(SLUGS + %w[/en/blog /about /en/about]).uniq.each do |path|
  res = get(path)
  next unless res.code == "200"

  body = res.body
  c = canonical(body)
  jsonld_blocks(body).each do |block|
    block.scan(/"url"\s*:\s*"([^"]+)"/).flatten.each do |u|
      next unless u.include?("/blog/")

      fail!("json-ld", "#{path}: JSON-LD url #{u} != canonical #{c}") unless u == c
    end
    block.scan(/"@id"\s*:\s*"([^"]+)"/).flatten.each do |u|
      next unless u.include?("/blog/")

      fail!("json-ld", "#{path}: JSON-LD @id #{u} != canonical #{c}") unless u == c
    end
  end
  alts = hreflangs(body)
  xdef = alts.select { |l, _| l == "x-default" }
  # An x-default with no real alternates would point at a page nobody can index.
  fail!("hreflang", "#{path}: x-default with no alternates") if xdef.any? && alts.size == xdef.size && path.start_with?("/blog/")
  alts.each do |_lang, href|
    r = get(URI.parse(href).path)
    fail!("hreflang", "#{path}: alternate #{href} -> #{r.code}") unless r.code == "200"
    fail!("hreflang", "#{path}: alternate #{href} is noindex") if r.code == "200" && meta(r.body, "robots").to_s.include?("noindex")
  end
end
puts "  #{(SLUGS + %w[/en/blog /about /en/about]).uniq.size} pages checked"

# ── 6. Accept-Language invariance ────────────────────────────────────────────
puts "\n[6/6] Accept-Language invariance on prefix-free URLs"
LANGS = [ nil, "en-US", "ja", "es", "ko" ]
prefix_free = (%w[/ /about /faq /compress /pdf /social /blog] +
               SLUGS.select { |s| s.start_with?("/blog/") }).uniq
prefix_free.each do |path|
  seen = LANGS.map do |lang|
    h = lang ? { "Accept-Language" => lang } : {}
    res = get(path, headers: h)
    [ lang, canonical(res.body), meta(res.body, "robots") ]
  end
  cs = seen.map { |_, c, _| c }.uniq
  rs = seen.map { |_, _, r| r }.uniq
  fail!("accept-language", "#{path} canonical varies by language: #{seen.inspect}") if cs.size > 1
  fail!("accept-language", "#{path} robots varies by language: #{seen.inspect}") if rs.size > 1
end
puts "  #{prefix_free.size} pages x #{LANGS.size} languages"

puts "\n#{'=' * 60}"
if $failures.empty?
  puts "ALL CHECKS PASSED"
  exit 0
else
  puts "#{$failures.size} FAILURE(S):"
  $failures.each { |f| puts "  - #{f}" }
  exit 1
end
```

### Q5 용 — `ImageProcessing::Vips` 호출부 전수 (3개 파일)

#### `app/services/image_compressor.rb`

```ruby
class ImageCompressor
  TARGET_SIZE = 2.megabytes

  def initialize(source, target_percent: nil)
    @source = source
    @target_percent = target_percent&.to_i
  end

  def call
    path = @source.is_a?(String) ? @source : @source.path
    original_size = File.size(path)
    width, height = vips_dimensions(path)

    if @target_percent && @target_percent.between?(1, 100)
      target_bytes = (original_size * @target_percent / 100.0).to_i
      compress_to_target(path, target_bytes, width, height)
    else
      auto_compress(path, original_size, width, height)
    end
  end

  private

  def compress_to_target(path, target_bytes, width, height)
    # Try quality levels from high to low, find the best one that fits target
    best = nil

    scales = [1.0, 0.75, 0.5, 0.35, 0.25]
    qualities = [80, 65, 50, 40, 30, 20, 15, 10]

    # First pass: find the highest quality + largest scale that fits
    scales.each do |scale|
      qualities.each do |quality|
        w = (width * scale).to_i
        h = (height * scale).to_i

        pipeline = ImageProcessing::Vips.source(path)
        pipeline = pipeline.resize_to_limit(w, h) if scale < 1.0
        result = pipeline.convert("jpeg").saver(quality: quality, strip: true, interlace: true).call

        if result.size <= target_bytes
          # This fits — use it (it's the highest quality at this scale)
          best&.close!
          return result
        end

        result.close!
      end
    end

    # Nothing fit — use most aggressive
    ImageProcessing::Vips.source(path)
      .resize_to_limit(width / 5, height / 5)
      .convert("jpeg")
      .saver(quality: 10, strip: true, interlace: true)
      .call
  end

  def auto_compress(path, original_size, width, height)
    [80, 65, 50].each do |q|
      result = compress(path, quality: q)
      return result if good_enough?(result, original_size)
    end

    ImageProcessing::Vips.source(path)
      .resize_to_limit(width / 2, height / 2)
      .convert("jpeg")
      .saver(quality: 50, strip: true, interlace: true)
      .call
  end

  def compress(path, quality:)
    ImageProcessing::Vips.source(path)
      .convert("jpeg")
      .saver(quality: quality, strip: true, interlace: true)
      .call
  end

  def good_enough?(result, original_size)
    result.size <= TARGET_SIZE && result.size < (original_size * 0.9)
  end

  def vips_dimensions(source)
    path = source.is_a?(String) ? source : source.path
    require "ruby-vips" unless defined?(::Vips)
    img = ::Vips::Image.new_from_file(path)
    [img.width, img.height]
  end
end
```

#### `app/services/social_resizer.rb`

```ruby
class SocialResizer
  PRESETS = {
    "instagram_square" => { width: 1080, height: 1080, label: "Instagram 1:1" },
    "instagram_portrait" => { width: 1080, height: 1350, label: "Instagram 4:5" },
    "facebook_feed" => { width: 1200, height: 630, label: "Facebook Feed 1.91:1" },
    "facebook_story" => { width: 1080, height: 1920, label: "Facebook Story 9:16" }
  }.freeze

  TARGET_SIZE = 2.megabytes

  def initialize(source, preset_key)
    @source = source
    @preset = PRESETS.fetch(preset_key)
  end

  def call
    width = @preset[:width]
    height = @preset[:height]

    result = ImageProcessing::Vips
      .source(@source)
      .resize_to_fill(width, height)
      .convert("jpeg")
      .saver(quality: 85, strip: true, interlace: true)
      .call

    return result if result.size <= TARGET_SIZE

    ImageProcessing::Vips
      .source(result.path)
      .convert("jpeg")
      .saver(quality: 60, strip: true, interlace: true)
      .call
  end

  def self.preset_options
    PRESETS.map { |key, val| [val[:label], key] }
  end
end
```

#### `app/services/pdf_builder.rb`

```ruby
class PdfBuilder
  A4_WIDTH = 595
  A4_HEIGHT = 842

  def initialize(source_files)
    @source_files = source_files
  end

  def call
    @cleanup_paths = []

    page_paths = @source_files.map do |file|
      path = file.is_a?(String) ? file : file.path
      build_pdf_page(path)
    end

    combined = CombinePDF.new
    page_paths.each { |p| combined << CombinePDF.load(p) }

    output = Tempfile.new(["docpack", ".pdf"])
    combined.save(output.path)
    output.rewind
    output
  ensure
    @cleanup_paths&.each { |p| File.delete(p) if File.exist?(p) rescue nil }
  end

  private

  def build_pdf_page(image_path)
    resized = ImageProcessing::Vips
      .source(image_path)
      .convert("jpeg")
      .saver(quality: 75)
      .call
    @cleanup_paths << resized.path

    jpeg_data = File.binread(resized.path)
    require "ruby-vips" unless defined?(::Vips)
    img = ::Vips::Image.new_from_file(resized.path)
    img_w = img.width
    img_h = img.height

    scale = [A4_WIDTH.to_f / img_w, A4_HEIGHT.to_f / img_h].min
    fitted_w = (img_w * scale).to_i
    fitted_h = (img_h * scale).to_i
    x_offset = (A4_WIDTH - fitted_w) / 2
    y_offset = (A4_HEIGHT - fitted_h) / 2

    stream = "q #{fitted_w} 0 0 #{fitted_h} #{x_offset} #{y_offset} cm /Img Do Q"

    # Use a fixed path instead of Tempfile (which gets GC'd and unlinked)
    pdf_path = "/tmp/docpack_page_#{SecureRandom.hex(8)}.pdf"
    @cleanup_paths << pdf_path

    File.open(pdf_path, "wb") do |f|
      offsets = []
      f.write("%PDF-1.4\n")

      offsets << f.pos
      f.write("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")

      offsets << f.pos
      f.write("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")

      offsets << f.pos
      f.write("3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 #{A4_WIDTH} #{A4_HEIGHT}] /Contents 4 0 R /Resources << /XObject << /Img 5 0 R >> >> >>\nendobj\n")

      offsets << f.pos
      f.write("4 0 obj\n<< /Length #{stream.length} >>\nstream\n#{stream}\nendstream\nendobj\n")

      offsets << f.pos
      f.write("5 0 obj\n<< /Type /XObject /Subtype /Image /Width #{img_w} /Height #{img_h} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length #{jpeg_data.length} >>\nstream\n")
      f.write(jpeg_data)
      f.write("\nendstream\nendobj\n")

      xref_pos = f.pos
      f.write("xref\n0 6\n0000000000 65535 f \n")
      offsets.each { |o| f.write(format("%010d 00000 n \n", o)) }
      f.write("trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n#{xref_pos}\n%%EOF\n")
    end

    pdf_path
  end
end
```

### Q1 용 — `Gemfile.lock` DEPENDENCIES 전문 + railties 를 요구하는 모든 항목

```
DEPENDENCIES
  bootsnap
  brakeman
  capybara
  combine_pdf
  debug
  dotenv-rails
  image_processing (~> 1.2)
  importmap-rails
  jbuilder
  kamal
  minitest (< 7)
  minitest-mock
  pg (~> 1.1)
  propshaft
  puma (>= 5.0)
  rails (~> 8.0.5)
  rubocop-rails-omakase
  rubyzip
  selenium-webdriver
  solid_cable
  solid_cache
  solid_queue
  stimulus-rails
  thruster
  turbo-rails
  tzinfo-data
  web-console

BUNDLED WITH
   2.6.9
```

```
112:      railties (>= 6.1)
140:      railties (>= 6.0.0)
261:      railties (= 8.0.5.1)
269:    railties (8.0.5.1)
338:      railties (>= 7.2)
342:      railties (>= 7.2)
348:      railties (>= 7.1)
358:      railties (>= 6.0.0)
369:      railties (>= 7.1.0)
380:      railties (>= 8.0.0)
```

### 이 브랜치의 `Gemfile.lock` 젬 버전 변화 전부

```diff
-    actioncable (8.0.4)
-    actionmailbox (8.0.4)
-    actionmailer (8.0.4)
-    actionpack (8.0.4)
-    actiontext (8.0.4)
-    actionview (8.0.4)
-    activejob (8.0.4)
-    activemodel (8.0.4)
-    activerecord (8.0.4)
-    activestorage (8.0.4)
-    activesupport (8.0.4)
-    bigdecimal (4.0.1)
-    bootsnap (1.23.0)
-    brakeman (8.0.4)
-    concurrent-ruby (1.3.6)
-    crass (1.0.6)
-    erb (6.0.2)
-    globalid (1.3.0)
-    i18n (1.14.8)
-    io-console (0.8.2)
-    irb (1.17.0)
-    jbuilder (2.14.1)
-    loofah (2.25.1)
-    mail (2.9.0)
-    marcel (1.1.0)
-    minitest (5.27.0)
-    msgpack (1.8.0)
-    net-imap (0.6.3)
-    net-protocol (0.2.2)
-    nokogiri (1.19.2-aarch64-linux-gnu)
-    nokogiri (1.19.2-aarch64-linux-musl)
-    nokogiri (1.19.2-arm-linux-gnu)
-    nokogiri (1.19.2-arm-linux-musl)
-    nokogiri (1.19.2-arm64-darwin)
-    nokogiri (1.19.2-x86_64-darwin)
-    nokogiri (1.19.2-x86_64-linux-gnu)
-    nokogiri (1.19.2-x86_64-linux-musl)
-    pp (0.6.3)
-    propshaft (1.3.1)
-    psych (5.3.1)
-    rack (3.2.5)
-    rack-session (2.1.1)
-    rails (8.0.4)
-    rails-html-sanitizer (1.7.0)
-    railties (8.0.4)
-    rake (13.3.1)
-    rdoc (7.2.0)
-    reline (0.6.3)
-    rubyzip (3.2.2)
-    selenium-webdriver (4.41.0)
-    solid_cable (3.0.12)
-    stringio (3.2.0)
-    websocket-driver (0.8.0)
-    zeitwerk (2.7.5)
+    actioncable (8.0.5.1)
+    actionmailbox (8.0.5.1)
+    actionmailer (8.0.5.1)
+    actionpack (8.0.5.1)
+    actiontext (8.0.5.1)
+    actionview (8.0.5.1)
+    activejob (8.0.5.1)
+    activemodel (8.0.5.1)
+    activerecord (8.0.5.1)
+    activestorage (8.0.5.1)
+    activesupport (8.0.5.1)
+    bigdecimal (4.1.3)
+    bootsnap (1.26.0)
+    brakeman (8.0.6)
+    concurrent-ruby (1.3.8)
+    crass (1.0.7)
+    erb (6.0.7)
+    globalid (1.4.0)
+    i18n (1.15.2)
+    io-console (0.9.4)
+    irb (1.18.0)
+    jbuilder (2.15.1)
+    loofah (2.25.2)
+    mail (2.9.1)
+    marcel (1.2.1)
+    minitest (6.0.6)
+    minitest-mock (5.27.0)
+    msgpack (1.8.5)
+    net-imap (0.6.7)
+    net-protocol (0.4.0)
+    nokogiri (1.19.4-aarch64-linux-gnu)
+    nokogiri (1.19.4-aarch64-linux-musl)
+    nokogiri (1.19.4-arm-linux-gnu)
+    nokogiri (1.19.4-arm-linux-musl)
+    nokogiri (1.19.4-arm64-darwin)
+    nokogiri (1.19.4-x86_64-darwin)
+    nokogiri (1.19.4-x86_64-linux-gnu)
+    nokogiri (1.19.4-x86_64-linux-musl)
+    pp (0.6.4)
+    propshaft (1.3.2)
+    rack (3.2.7)
+    rack-session (2.1.2)
+    rails (8.0.5.1)
+    rails-html-sanitizer (1.7.1)
+    railties (8.0.5.1)
+    rake (13.4.2)
+    rbs (4.2.0)
+    rdoc (8.0.0)
+    reline (0.7.0)
+    rubyzip (3.6.0)
+    selenium-webdriver (4.49.0)
+    solid_cable (4.0.2)
+    websocket-driver (0.8.2)
+    zeitwerk (2.8.3)
```
